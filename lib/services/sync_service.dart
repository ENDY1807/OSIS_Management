import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  /// Memeriksa apakah Supabase dapat diakses
  static Future<bool> checkConnection() async {
    final client = _supabase;
    if (client == null) {
      _setStatus(SyncStatus.offline);
      return false;
    }

    try {
      // Coba query sederhana ke database Supabase dengan timeout 4 detik
      await client
          .from('siswa')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 4));

      _setStatus(SyncStatus.online);
      return true;
    } catch (_) {
      try {
        // Fallback probe ke tabel accounts
        await client
            .from('accounts')
            .select('username')
            .limit(1)
            .timeout(const Duration(seconds: 3));

        _setStatus(SyncStatus.online);
        return true;
      } catch (_) {
        _setStatus(SyncStatus.offline);
        return false;
      }
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
      try {
        success = await _executeAction(client, action);
      } catch (e) {
        debugPrint('SyncService error executing action on ${action.table}: $e');
        action.retryCount += 1;
        action.lastError = e.toString();
        success = false;
      }

      if (!success) {
        hasFailures = true;
        // Simpan untuk dicoba lagi jika gagal karena jaringan
        remaining.add(action);
      }
    }

    await _saveQueue(remaining);
    _isFlushing = false;

    if (!hasFailures) {
      statusNotifier.value = SyncStatus.online;
      final now = DateTime.now();
      lastSyncTimeNotifier.value = now;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastSync, now.toIso8601String());
      debugPrint('SyncService: Flush completed successfully. Queue is empty.');
      return true;
    } else {
      statusNotifier.value = SyncStatus.offline;
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
