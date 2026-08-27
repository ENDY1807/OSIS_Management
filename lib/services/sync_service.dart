import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum SyncStatus {
  online,
  offline,
  syncing,
}

enum SyncActionType {
  insert,
  update,
  delete,
  upsert,
}

class SyncAction {
  final String id;
  final SyncActionType actionType;
  final String table;
  final Map<String, dynamic>? data;
  final String? targetId;
  final DateTime createdAt;
  int retryCount;
  String? lastError;

  SyncAction({
    required this.id,
    required this.actionType,
    required this.table,
    this.data,
    this.targetId,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'actionType': actionType.name,
    'table': table,
    'data': data,
    'targetId': targetId,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'lastError': lastError,
  };

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
    id: json['id']?.toString() ?? _uuid.v4(),
    actionType: SyncActionType.values.firstWhere(
      (e) => e.name == json['actionType'],
      orElse: () => SyncActionType.upsert,
    ),
    table: json['table']?.toString() ?? '',
    data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
    targetId: json['targetId']?.toString(),
    createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    lastError: json['lastError']?.toString(),
  );
}

class SyncService {
  static const _keySyncQueue = 'sync_pending_queue_v2';
  static const _keyLastSync = 'sync_last_success_time';

  static final ValueNotifier<SyncStatus> statusNotifier = ValueNotifier<SyncStatus>(SyncStatus.online);
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<DateTime?> lastSyncTimeNotifier = ValueNotifier<DateTime?>(null);

  static bool get isOnline => statusNotifier.value == SyncStatus.online;
  static bool get isSyncing => statusNotifier.value == SyncStatus.syncing;

  static Timer? _healthCheckTimer;
  static bool _initialized = false;
  static bool _isFlushing = false;
  static int _consecutiveFailures = 0;

  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    final lastTimeStr = prefs.getString(_keyLastSync);
    if (lastTimeStr != null) {
      lastSyncTimeNotifier.value = DateTime.tryParse(lastTimeStr);
    }

    await _updatePendingCount();

    // Jalankan pemeriksaan koneksi awal
    await checkConnection();

    // Jalankan periodic health check & auto sync setiap 15 detik
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await checkAndSync();
    });
  }

  static Future<void> dispose() async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  // ── Antrean Sync (SyncQueue) ───────────────────────────────────────────────

  static Future<List<SyncAction>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keySyncQueue) ?? [];
    return raw.map((e) {
      try {
        return SyncAction.fromJson(jsonDecode(e));
      } catch (_) {
        return null;
      }
    }).whereType<SyncAction>().toList();
  }

  static Future<void> _saveQueue(List<SyncAction> list) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keySyncQueue, raw);
    pendingCountNotifier.value = list.length;
  }

  static Future<void> _updatePendingCount() async {
    final list = await getQueue();
    pendingCountNotifier.value = list.length;
  }

  /// Masukkan perubahan ke dalam antrean sinkronisasi
  static Future<void> enqueueAction({
    required SyncActionType actionType,
    required String table,
    Map<String, dynamic>? data,
    String? targetId,
  }) async {
    final action = SyncAction(
      id: _uuid.v4(),
      actionType: actionType,
      table: table,
      data: data,
      targetId: targetId,
      createdAt: DateTime.now(),
    );

    final queue = await getQueue();
    // Jika ada aksi serupa untuk target yang sama, lakukan deduplikasi/update
    if (targetId != null && targetId.isNotEmpty) {
      queue.removeWhere((item) => item.table == table && item.targetId == targetId);
    }
    queue.add(action);
    await _saveQueue(queue);

    debugPrint('SyncService: Enqueued ${action.actionType.name} on ${action.table} (Total: ${queue.length})');

    // Jika online, jadwalkan flush segera
    if (isOnline && !_isFlushing) {
      unawaited(flushQueue());
    }
  }

  // ── Pemeriksaan Konektivitas & Auto Sync ───────────────────────────────────

  /// Memeriksa aksesibilitas internet umum (DNS / HTTP 204)
  static Future<bool> hasInternet() async {
    if (!kIsWeb) {
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {}
    }

    try {
      final res = await http
          .get(Uri.parse('https://www.gstatic.com/generate_204'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 204 || res.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Memeriksa apakah koneksi aktif (multi-tier probe dengan debounce)
  static Future<bool> checkConnection() async {
    final client = _supabase;
    if (client == null) {
      _handleFailure();
      return false;
    }

    bool isNetAvailable = false;
    try {
      // 1. Probe Supabase table secara cepat
      await client
          .from('app_settings')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      isNetAvailable = true;
    } catch (e) {
      // 2. Jika Supabase timeout/RLS, cek apakah internet umum aktif
      final net = await hasInternet();
      if (net) {
        isNetAvailable = true;
      }
    }

    if (isNetAvailable) {
      _consecutiveFailures = 0;
      _setStatus(SyncStatus.online);
      return true;
    } else {
      _handleFailure();
      return false;
    }
  }

  static void _handleFailure() {
    _consecutiveFailures++;
    // Hanya beralih ke offline jika gagal 2x berturut-turut untuk mencegah kedipan status akibat jitter WiFi
    if (_consecutiveFailures >= 2) {
      _setStatus(SyncStatus.offline);
    }
  }

  static void _setStatus(SyncStatus newStatus) {
    if (statusNotifier.value != newStatus && statusNotifier.value != SyncStatus.syncing) {
      statusNotifier.value = newStatus;
    }
  }

  /// Periksa koneksi dan jalankan sinkronisasi jika tersedia antrean
  static Future<void> checkAndSync() async {
    final online = await checkConnection();
    if (online) {
      final queue = await getQueue();
      if (queue.isNotEmpty && !_isFlushing) {
        await flushQueue();
      }
    }
  }

  // ── Eksekusi Flush Queue ───────────────────────────────────────────────────

  /// Memproses seluruh antrean perubahan ke Supabase secara teratur
  static Future<bool> flushQueue() async {
    if (_isFlushing) return false;
    final client = _supabase;
    if (client == null) return false;

    final queue = await getQueue();
    if (queue.isEmpty) {
      _consecutiveFailures = 0;
      _setStatus(SyncStatus.online);
      return true;
    }

    _isFlushing = true;
    statusNotifier.value = SyncStatus.syncing;

    debugPrint('SyncService: Starting flush of ${queue.length} pending actions...');

    final List<SyncAction> remaining = [];
    bool hasFailures = false;

    for (final action in queue) {
      bool success = false;
      bool isPermanentError = false;

      try {
        success = await _executeAction(client, action);
      } on PostgrestException catch (pe) {
        debugPrint('SyncService Postgres error on ${action.table}: ${pe.message}');
        action.retryCount += 1;
        action.lastError = pe.message;
        // Constraint error atau bad request bukan error koneksi internet
        if (pe.code != null && (pe.code!.startsWith('23') || pe.code!.startsWith('42') || action.retryCount >= 4)) {
          isPermanentError = true;
        }
        success = false;
      } catch (e) {
        debugPrint('SyncService error executing action on ${action.table}: $e');
        action.retryCount += 1;
        action.lastError = e.toString();
        if (action.retryCount >= 5) {
          isPermanentError = true;
        }
        success = false;
      }

      if (success) {
        // Berhasil diproses
      } else if (isPermanentError) {
        debugPrint('SyncService: Discarding corrupted action ${action.id} on ${action.table} after ${action.retryCount} retries.');
      } else {
        hasFailures = true;
        remaining.add(action);
      }
    }

    await _saveQueue(remaining);
    _isFlushing = false;

    if (!hasFailures) {
      _consecutiveFailures = 0;
      _setStatus(SyncStatus.online);
      final now = DateTime.now();
      lastSyncTimeNotifier.value = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSync, now.toIso8601String());
      debugPrint('SyncService: Flush completed successfully. Queue is empty.');
      return true;
    } else {
      // Verifikasi konektivitas riil sebelum mengubah status
      final online = await hasInternet();
      if (online) {
        _setStatus(SyncStatus.online);
      } else {
        _handleFailure();
      }
      debugPrint('SyncService: Flush finished with ${remaining.length} items remaining in queue.');
      return false;
    }
  }

  static Future<bool> _executeAction(SupabaseClient client, SyncAction action) async {
    final table = action.table;
    final data = action.data;
    final targetId = action.targetId;

    switch (action.actionType) {
      case SyncActionType.insert:
      case SyncActionType.upsert:
        if (data == null || data.isEmpty) return true;
        if (table == 'accounts') {
          await client.from(table).upsert(data, onConflict: 'username');
        } else if (table == 'file_riwayat') {
          await client.from(table).upsert(data, onConflict: 'id');
        } else {
          await client.from(table).upsert(data, onConflict: 'id');
        }
        return true;

      case SyncActionType.update:
        if (data == null || data.isEmpty) return true;
        if (table == 'accounts') {
          final u = data['username']?.toString() ?? targetId;
          if (u != null) {
            await client.from(table).update(data).eq('username', u);
          }
        } else {
          final id = targetId ?? data['id']?.toString();
          if (id != null) {
            await client.from(table).update(data).eq('id', id);
          }
        }
        return true;

      case SyncActionType.delete:
        if (table == 'accounts') {
          final u = targetId ?? data?['username']?.toString();
          if (u != null) {
            await client.from(table).delete().eq('username', u);
          }
        } else {
          final id = targetId ?? data?['id']?.toString();
          if (id != null) {
            await client.from(table).delete().eq('id', id);
          }
        }
        return true;
    }
  }

  /// Bersihkan antrean (khusus jika user ingin mereset data tertunda)
  static Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySyncQueue);
    pendingCountNotifier.value = 0;
  }
}
