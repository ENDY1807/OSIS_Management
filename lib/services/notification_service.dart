import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'data_service.dart';

const _uuid = Uuid();

class _BufferedRealtimeEvent {
  final String table;
  final PostgresChangeEvent eventType;
  final Map<String, dynamic> record;
  final DateTime receivedAt;

  _BufferedRealtimeEvent({
    required this.table,
    required this.eventType,
    required this.record,
    required this.receivedAt,
  });
}

class NotificationService {
  static const _keyNotifications = 'app_notifications_v1';
  static const targetStakeholders = [
    'ADMIN',
    'KETUA',
    'WAKIL',
    'SEKRETARIS',
    'BENDAHARA',
    'PEMBINA',
    'KESISWAAN',
  ];

  static bool isTargetRole(String? role) {
    if (role == null || role.trim().isEmpty) return false;
    return targetStakeholders.contains(role.trim().toUpperCase());
  }

  static final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static RealtimeChannel? _realtimeChannel;

  // Anti-Spam Buffer & Throttling
  static final List<_BufferedRealtimeEvent> _eventBuffer = [];
  static Timer? _bufferFlushTimer;
  static DateTime? _lastSystemNotificationTime;
  static final Map<String, DateTime> _recentDeduplicationMap = {};

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'osis_updates_channel',
    'Notifikasi OSIS Management',
    description: 'Pemberitahuan real-time untuk penambahan & perubahan data OSIS',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> init() async {
    if (_initialized) return;
    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS ||
                      defaultTargetPlatform == TargetPlatform.macOS)) {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const darwinSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

        const settings = InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        );

        await _localNotifs.initialize(
          settings: settings,
          onDidReceiveNotificationResponse: (response) {
            debugPrint('Notification clicked: ${response.payload}');
          },
        );

        // Create Android Notification Channel with High Importance
        final androidPlugin = _localNotifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(_channel);
          await androidPlugin.requestNotificationsPermission();
        }
      }

      _initialized = true;
      _subscribeRealtime();
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  static void _subscribeRealtime() {
    try {
      if (_realtimeChannel != null) return;
      final client = Supabase.instance.client;
      _realtimeChannel = client.channel('osis_global_channel');

      // 1. Listen to Instant Broadcast Messages (cross-device WebSocket)
      _realtimeChannel?.onBroadcast(
        event: 'update_event',
        callback: (payload) async {
          debugPrint('Realtime broadcast received: $payload');
          await _handleIncomingBroadcast(payload);
        },
      );

      // 2. Listen to Database Postgres Changes across all data tables with anti-spam buffering
      const monitoredTables = [
        'arsip',
        'laporan_kegiatan',
        'proker',
        'pelanggaran',
        'siswa',
        'jenis_pelanggaran',
      ];
      for (final table in monitoredTables) {
        _realtimeChannel?.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) => _queueRealtimeEvent(table: table, payload: payload),
        );
      }

      _realtimeChannel?.subscribe();
    } catch (e) {
      debugPrint('Realtime subscription error: $e');
    }
  }

  static Future<void> _handleIncomingBroadcast(Map<String, dynamic> payload) async {
    try {
      final category = payload['category']?.toString() ?? 'system';
      // Segera beritahu data service untuk memperbarui state UI
      DataService.notifyDataChanged(category);

      final rawUser = await AuthService.getUserName() ?? '';
      final currentUser = rawUser.trim().toUpperCase();

      // HANYA user KETUA, WAKIL, SEKRETARIS, BENDAHARA, PEMBINA, KESISWAAN yang menerima notifikasi
      if (!isTargetRole(currentUser)) return;

      final actor = (payload['actor']?.toString() ?? '').trim().toUpperCase();

      // JANGAN munculkan notifikasi jika device ini adalah actor yang membuat perubahan
      if (currentUser.isNotEmpty && actor.isNotEmpty && currentUser == actor) {
        return;
      }

      final title = payload['title']?.toString() ?? 'Pemberitahuan OSIS';
      final message = payload['message']?.toString() ?? '';

      // Anti-spam deduplikasi dalam jendela 6 detik
      final signature = '$category|$title|$message';
      final now = DateTime.now();
      if (_recentDeduplicationMap.containsKey(signature)) {
        final lastTime = _recentDeduplicationMap[signature]!;
        if (now.difference(lastTime).inSeconds < 6) {
          return; // Skip duplicate / spam
        }
      }
      _recentDeduplicationMap[signature] = now;

      final item = AppNotification(
        id: _uuid.v4(),
        title: title,
        body: message,
        category: category,
        timestamp: DateTime.now(),
        actor: actor.isNotEmpty ? actor : 'Sistem',
        targetRoles: targetStakeholders,
        isRead: false,
      );

      final list = await getNotifications();
      list.insert(0, item);
      final trimmed = list.take(100).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyNotifications, jsonEncode(trimmed.map((e) => e.toJson()).toList()));

      // Tampilkan Notifikasi Sistem Real-time (dengan rate-limiter anti-spam)
      await showSystemNotification(
        id: idFromString(item.id),
        title: title,
        body: message,
        payload: category,
      );
    } catch (e) {
      debugPrint('Error handling incoming broadcast: $e');
    }
  }

  // ── Anti-Spam Queue & Buffer Realtime Event ─────────────────────────────────
  static void _queueRealtimeEvent({
    required String table,
    required PostgresChangePayload payload,
  }) {
    // 1. Segera sinkronkan UI lokal terlepas dari buffer
    DataService.notifyDataChanged(table);

    final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
    _eventBuffer.add(_BufferedRealtimeEvent(
      table: table,
      eventType: payload.eventType,
      record: record,
      receivedAt: DateTime.now(),
    ));

    // 2. Gunakan debounce timer 2.0 detik untuk mengumpulkan semua event beruntun (misal saat offline sync)
    _bufferFlushTimer?.cancel();
    _bufferFlushTimer = Timer(const Duration(milliseconds: 2000), () {
      _flushEventBuffer();
    });
  }

  static Future<void> _flushEventBuffer() async {
    if (_eventBuffer.isEmpty) return;

    final eventsToProcess = List<_BufferedRealtimeEvent>.from(_eventBuffer);
    _eventBuffer.clear();

    final rawUser = await AuthService.getUserName() ?? '';
    final currentUser = rawUser.trim().toUpperCase();
    if (!isTargetRole(currentUser)) return;

    // Kelompokkan event berdasarkan tabel
    final Map<String, List<_BufferedRealtimeEvent>> groupedByTable = {};
    for (final ev in eventsToProcess) {
      groupedByTable.putIfAbsent(ev.table, () => []).add(ev);
    }

    for (final entry in groupedByTable.entries) {
      final table = entry.key;
      final events = entry.value;

      String title = '';
      String message = '';
      String actor = '';

      if (events.length == 1) {
        // Hanya 1 event: tampilkan deskripsi spesifik
        final ev = events.first;
        final record = ev.record;
        final eventType = ev.eventType;

        if (table == 'arsip') {
          final judul = record['judul'] ?? 'File Dokumen';
          final kategori = (record['kategori'] == null || record['kategori'].toString().isEmpty)
              ? 'Root (/)'
              : record['kategori'];
          actor = record['pembuat_id'] ?? '';
          if (eventType == PostgresChangeEvent.insert) {
            title = 'File Arsip Baru';
            message = 'File "$judul" ditambahkan di folder $kategori${actor.isNotEmpty ? " oleh $actor" : ""}';
          } else if (eventType == PostgresChangeEvent.update) {
            title = 'File Arsip Diperbarui';
            message = 'File "$judul" di folder $kategori telah diperbarui';
          } else if (eventType == PostgresChangeEvent.delete) {
            title = 'File Arsip Dihapus';
            message = 'File "$judul" di folder $kategori telah dihapus';
          }
        } else if (table == 'laporan_kegiatan') {
          final judul = record['judul'] ?? 'Laporan';
          final sekbid = record['sekbid'] ?? '';
          actor = record['pembuat_id'] ?? sekbid;
          if (eventType == PostgresChangeEvent.insert) {
            title = 'Laporan Kegiatan Baru';
            message = 'Laporan "$judul" ($sekbid) dibuat${actor.isNotEmpty ? " oleh $actor" : ""}';
          } else if (eventType == PostgresChangeEvent.update) {
            title = 'Laporan Kegiatan Diperbarui';
            message = 'Laporan "$judul" ($sekbid) telah diperbarui';
          } else if (eventType == PostgresChangeEvent.delete) {
            title = 'Laporan Kegiatan Dihapus';
            message = 'Laporan "$judul" ($sekbid) telah dihapus';
          }
        } else if (table == 'proker') {
          final nama = record['nama'] ?? 'Proker';
          final sekbid = record['sekbid'] ?? '';
          actor = record['sekbid'] ?? '';
          if (eventType == PostgresChangeEvent.insert) {
            title = 'Program Kerja Baru';
            message = 'Proker "$nama" dibuat untuk divisi $sekbid';
          } else if (eventType == PostgresChangeEvent.update) {
            title = 'Program Kerja Diperbarui';
            message = 'Proker "$nama" ($sekbid) telah diperbarui';
          } else if (eventType == PostgresChangeEvent.delete) {
            title = 'Program Kerja Dihapus';
            message = 'Proker "$nama" ($sekbid) telah dihapus';
          }
        } else if (table == 'pelanggaran') {
          final namaSiswa = record['nama_siswa'] ?? '';
          final kelasSiswa = record['kelas_siswa'] ?? '';
          actor = record['petugas'] ?? '';
          if (eventType == PostgresChangeEvent.insert) {
            title = 'Catatan Pelanggaran Baru';
            message = namaSiswa.isNotEmpty
                ? 'Catatan pelanggaran ditambahkan untuk $namaSiswa ($kelasSiswa)'
                : 'Catatan pelanggaran siswa baru telah ditambahkan';
          } else if (eventType == PostgresChangeEvent.delete) {
            title = 'Catatan Pelanggaran Dihapus';
            message = 'Catatan pelanggaran siswa telah dihapus';
          }
        } else if (table == 'siswa') {
          final nama = record['nama'] ?? 'Siswa';
          final kelas = record['kelas'] ?? '';
          if (eventType == PostgresChangeEvent.insert) {
            title = 'Data Siswa Ditambahkan';
            message = 'Siswa baru "$nama" ($kelas) telah ditambahkan';
          } else if (eventType == PostgresChangeEvent.update) {
            title = 'Data Siswa Diperbarui';
            message = 'Data siswa "$nama" ($kelas) telah diperbarui';
          } else if (eventType == PostgresChangeEvent.delete) {
            title = 'Data Siswa Dihapus';
            message = 'Data siswa "$nama" telah dihapus';
          }
        } else if (table == 'jenis_pelanggaran') {
          final nama = record['nama'] ?? 'Jenis Pelanggaran';
          if (eventType == PostgresChangeEvent.insert) {
            title = 'Jenis Pelanggaran Ditambahkan';
            message = 'Jenis pelanggaran baru "$nama" telah ditambahkan';
          } else if (eventType == PostgresChangeEvent.update) {
            title = 'Jenis Pelanggaran Diperbarui';
            message = 'Jenis pelanggaran "$nama" telah diperbarui';
          }
        }
      } else {
        // Banyak event dalam waktu berdekatan (misal sinkronisasi offline batch): Konsolidasikan menjadi 1 ringkasan
        final count = events.length;
        if (table == 'pelanggaran') {
          title = 'Sinkronisasi Pelanggaran ($count Data)';
          message = '$count catatan pelanggaran baru telah berhasil disinkronkan ke sistem.';
        } else if (table == 'laporan_kegiatan') {
          title = 'Sinkronisasi Laporan ($count Data)';
          message = '$count data laporan kegiatan telah disinkronkan.';
        } else if (table == 'proker') {
          title = 'Sinkronisasi Program Kerja ($count Data)';
          message = '$count program kerja telah diperbarui/disinkronkan.';
        } else if (table == 'arsip') {
          title = 'Sinkronisasi Berkas Arsip ($count Data)';
          message = '$count berkas arsip telah disinkronkan ke cloud.';
        } else if (table == 'siswa') {
          title = 'Sinkronisasi Data Siswa ($count Data)';
          message = '$count data siswa telah disinkronkan.';
        } else {
          title = 'Pembaruan Data Sistem ($count Data)';
          message = '$count pembaruan pada modul $table telah disinkronkan.';
        }
      }

      if (title.isEmpty) continue;

      if (currentUser.isNotEmpty && actor.isNotEmpty && currentUser == actor.toUpperCase()) {
        continue;
      }

      // Anti-spam deduplikasi
      final signature = '$table|$title|$message';
      final now = DateTime.now();
      if (_recentDeduplicationMap.containsKey(signature)) {
        final lastTime = _recentDeduplicationMap[signature]!;
        if (now.difference(lastTime).inSeconds < 6) {
          continue;
        }
      }
      _recentDeduplicationMap[signature] = now;

      final item = AppNotification(
        id: _uuid.v4(),
        title: title,
        body: message,
        category: table,
        timestamp: DateTime.now(),
        actor: actor.isNotEmpty ? actor : 'Sistem',
        targetRoles: targetStakeholders,
        isRead: false,
      );

      final list = await getNotifications();
      list.insert(0, item);
      final trimmed = list.take(100).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyNotifications, jsonEncode(trimmed.map((e) => e.toJson()).toList()));

      await showSystemNotification(
        id: idFromString(item.id),
        title: title,
        body: message,
        payload: table,
      );
    }
  }

  static Future<void> requestPermission() async {
    try {
      final androidPlugin = _localNotifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
  }

  static int idFromString(String s) => s.hashCode.abs() % 100000;

  static Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
    required String username,
  }) async {
    await showSystemNotification(
      id: id,
      title: title,
      body: body,
    );
  }

  /// Menampilkan notifikasi banner + suara sistem dengan mekanisme rate-limiting
  static Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_initialized) {
        await init();
      }

      // Rate limit: Jika notifikasi sistem sudah berdering dalam 1.5 detik terakhir, hindari dering beruntun
      final now = DateTime.now();
      bool shouldPlaySound = true;
      if (_lastSystemNotificationTime != null && now.difference(_lastSystemNotificationTime!).inMilliseconds < 1500) {
        shouldPlaySound = false;
      }
      _lastSystemNotificationTime = now;

      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: shouldPlaySound,
        enableVibration: shouldPlaySound,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
      );

      final darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: shouldPlaySound,
      );

      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS ||
                      defaultTargetPlatform == TargetPlatform.macOS)) {
        final platformDetails = NotificationDetails(
          android: androidDetails,
          iOS: darwinDetails,
          macOS: darwinDetails,
        );

        await _localNotifs.show(
          id: id,
          title: title,
          body: body,
          notificationDetails: platformDetails,
          payload: payload,
        );
      }
    } catch (e) {
      debugPrint('Error showing system notification: $e');
    }
  }

  static Future<void> scheduleProkerReminder({
    required int id,
    required String namaProker,
    required DateTime tanggalRencana,
    required String username,
  }) async {}

  static Future<void> cancelProkerReminder(int id) async {}

  // ── In-App Stakeholder Notifications & Activity Updates ───────────────────
  static Future<void> notifyUpdate({
    required String title,
    required String message,
    required String category,
    required String actor,
    List<String>? targetRoles,
  }) async {
    try {
      final roles = targetRoles ?? targetStakeholders;

      // Anti-spam deduplikasi
      final signature = '$category|$title|$message';
      final now = DateTime.now();
      if (_recentDeduplicationMap.containsKey(signature)) {
        final lastTime = _recentDeduplicationMap[signature]!;
        if (now.difference(lastTime).inSeconds < 4) {
          return;
        }
      }
      _recentDeduplicationMap[signature] = now;

      // 1. Broadcast ke perangkat lain via Supabase Realtime
      try {
        if (_realtimeChannel == null) {
          _subscribeRealtime();
        }
        await _realtimeChannel?.sendBroadcastMessage(
          event: 'update_event',
          payload: {
            'title': title,
            'message': message,
            'category': category,
            'actor': actor,
            'targetRoles': roles,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        debugPrint('Send broadcast error: $e');
      }

      // 2. Simpan ke database local cache HANYA jika currentUser adalah salah satu role target
      final rawUser = await AuthService.getUserName() ?? '';
      final currentUser = rawUser.trim().toUpperCase();
      final actorUpper = actor.trim().toUpperCase();

      if (isTargetRole(currentUser)) {
        final prefs = await SharedPreferences.getInstance();
        final list = await getNotifications();
        final item = AppNotification(
          id: _uuid.v4(),
          title: title,
          body: message,
          category: category,
          timestamp: DateTime.now(),
          actor: actor.isNotEmpty ? actor : 'Sistem',
          targetRoles: roles,
          isRead: false,
        );

        list.insert(0, item);
        final trimmed = list.take(100).toList();
        final jsonString = jsonEncode(trimmed.map((e) => e.toJson()).toList());
        await prefs.setString(_keyNotifications, jsonString);

        // 3. Local Pop-up Banner: Munculkan hanya jika currentUser BUKAN pembuat perubahan itu sendiri
        if (currentUser.isNotEmpty && currentUser != actorUpper) {
          final notifId = idFromString(item.id);
          await showSystemNotification(
            id: notifId,
            title: title,
            body: message,
            payload: category,
          );
        }
      }
    } catch (e) {
      debugPrint('notifyUpdate error: $e');
    }
  }

  static Future<List<AppNotification>> getNotifications({String? forUser}) async {
    try {
      if (forUser != null && forUser.isNotEmpty && !isTargetRole(forUser)) {
        return [];
      }

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyNotifications);
      if (raw == null || raw.isEmpty) return [];
      final List decoded = jsonDecode(raw);
      var list = decoded.map((e) => AppNotification.fromJson(e)).toList();

      if (forUser != null && forUser.isNotEmpty) {
        final u = forUser.trim().toUpperCase();
        list = list.where((n) {
          if (n.targetRoles.isEmpty) return true;
          return n.targetRoles.map((r) => r.toUpperCase()).contains(u);
        }).toList();
      }

      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<int> getUnreadCount({String? forUser}) async {
    if (forUser != null && forUser.isNotEmpty && !isTargetRole(forUser)) {
      return 0;
    }
    final list = await getNotifications(forUser: forUser);
    return list.where((n) => !n.isRead).length;
  }

  static Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getNotifications();
      final index = all.indexWhere((n) => n.id == id);
      if (index != -1) {
        final old = all[index];
        all[index] = AppNotification(
          id: old.id,
          title: old.title,
          body: old.body,
          category: old.category,
          timestamp: old.timestamp,
          actor: old.actor,
          targetRoles: old.targetRoles,
          isRead: true,
        );
        final jsonString = jsonEncode(all.map((e) => e.toJson()).toList());
        await prefs.setString(_keyNotifications, jsonString);
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  static Future<void> markAllAsRead({String? forUser}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getNotifications();
      final updated = all.map((n) {
        return AppNotification(
          id: n.id,
          title: n.title,
          body: n.body,
          category: n.category,
          timestamp: n.timestamp,
          actor: n.actor,
          targetRoles: n.targetRoles,
          isRead: true,
        );
      }).toList();
      final jsonString = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(_keyNotifications, jsonString);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  static Future<void> deleteNotification(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getNotifications();
      all.removeWhere((n) => n.id == id);
      final jsonString = jsonEncode(all.map((e) => e.toJson()).toList());
      await prefs.setString(_keyNotifications, jsonString);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  static Future<void> clearAll({String? forUser}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyNotifications);
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }
}
