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

      // 2. Listen to Database Postgres Changes across all data tables
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
          callback: (payload) => _handleRealtimeEvent(table: table, payload: payload),
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
      // Pastikan data service menerima notifikasi update
      DataService.notifyDataChanged(category);

      final rawUser = await AuthService.getUserName() ?? '';
      final currentUser = rawUser.trim().toUpperCase();

      // HANYA user KETUA, WAKIL, SEKRETARIS, BENDAHARA, PEMBINA, KESISWAAN yang boleh menerima notifikasi
      if (!isTargetRole(currentUser)) return;

      final actor = (payload['actor']?.toString() ?? '').trim().toUpperCase();

      // JANGAN munculkan notifikasi jika device ini adalah actor yang membuat perubahan
      if (currentUser.isNotEmpty && actor.isNotEmpty && currentUser == actor) {
        return;
      }

      final title = payload['title']?.toString() ?? 'Pemberitahuan OSIS';
      final message = payload['message']?.toString() ?? '';

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
      // Hindari duplikasi jika ada notifikasi dengan title dan pesan sama dalam 4 detik
      if (list.any((n) => n.title == title && n.body == message && DateTime.now().difference(n.timestamp).inSeconds < 4)) {
        return;
      }

      list.insert(0, item);
      final trimmed = list.take(100).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyNotifications, jsonEncode(trimmed.map((e) => e.toJson()).toList()));

      // Tampilkan Notifikasi Sistem Real-time (Heads-Up Banner + Suara + Getar)
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

  static Future<void> _handleRealtimeEvent({
    required String table,
    required PostgresChangePayload payload,
  }) async {
    try {
      // Segera notify UI data service terlepas dari role
      DataService.notifyDataChanged(table);

      final rawUser = await AuthService.getUserName() ?? '';
      final currentUser = rawUser.trim().toUpperCase();
      // Hanya 6 role pimpinan/stakeholder yang menerima notif
      if (!isTargetRole(currentUser)) return;

      final record = payload.newRecord.isNotEmpty ? payload.newRecord : payload.oldRecord;
      String title = '';
      String message = '';
      String actor = '';

      if (table == 'arsip') {
        final judul = record['judul'] ?? 'File Dokumen';
        final kategori = (record['kategori'] == null || record['kategori'].toString().isEmpty)
            ? 'Root (/)'
            : record['kategori'];
        actor = record['pembuat_id'] ?? '';
        if (payload.eventType == PostgresChangeEvent.insert) {
          title = 'File Arsip Baru';
          message = 'File "$judul" ditambahkan di folder $kategori${actor.isNotEmpty ? " oleh $actor" : ""}';
        } else if (payload.eventType == PostgresChangeEvent.update) {
          title = 'File Arsip Diperbarui';
          message = 'File "$judul" di folder $kategori telah diperbarui';
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          title = 'File Arsip Dihapus';
          message = 'File "$judul" di folder $kategori telah dihapus';
        }
      } else if (table == 'laporan_kegiatan') {
        final judul = record['judul'] ?? 'Laporan';
        final sekbid = record['sekbid'] ?? '';
        actor = record['pembuat_id'] ?? sekbid;
        if (payload.eventType == PostgresChangeEvent.insert) {
          title = 'Laporan Kegiatan Baru';
          message = 'Laporan "$judul" ($sekbid) dibuat${actor.isNotEmpty ? " oleh $actor" : ""}';
        } else if (payload.eventType == PostgresChangeEvent.update) {
          title = 'Laporan Kegiatan Diperbarui';
          message = 'Laporan "$judul" ($sekbid) telah diperbarui';
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          title = 'Laporan Kegiatan Dihapus';
          message = 'Laporan "$judul" ($sekbid) telah dihapus';
        }
      } else if (table == 'proker') {
        final nama = record['nama'] ?? 'Proker';
        final sekbid = record['sekbid'] ?? '';
        actor = record['sekbid'] ?? '';
        if (payload.eventType == PostgresChangeEvent.insert) {
          title = 'Program Kerja Baru';
          message = 'Proker "$nama" dibuat untuk divisi $sekbid';
        } else if (payload.eventType == PostgresChangeEvent.update) {
          title = 'Program Kerja Diperbarui';
          message = 'Proker "$nama" ($sekbid) telah diperbarui';
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          title = 'Program Kerja Dihapus';
          message = 'Proker "$nama" ($sekbid) telah dihapus';
        }
      } else if (table == 'pelanggaran') {
        final keterangan = record['keterangan'] ?? '';
        if (payload.eventType == PostgresChangeEvent.insert) {
          title = 'Catatan Pelanggaran Baru';
          message = 'Catatan pelanggaran siswa baru telah ditambahkan${keterangan.isNotEmpty ? " ($keterangan)" : ""}';
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          title = 'Catatan Pelanggaran Dihapus';
          message = 'Catatan pelanggaran siswa telah dihapus';
        }
      } else if (table == 'siswa') {
        final nama = record['nama'] ?? 'Siswa';
        final kelas = record['kelas'] ?? '';
        if (payload.eventType == PostgresChangeEvent.insert) {
          title = 'Data Siswa Ditambahkan';
          message = 'Siswa baru "$nama" ($kelas) telah ditambahkan';
        } else if (payload.eventType == PostgresChangeEvent.update) {
          title = 'Data Siswa Diperbarui';
          message = 'Data siswa "$nama" ($kelas) telah diperbarui';
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          title = 'Data Siswa Dihapus';
          message = 'Data siswa "$nama" telah dihapus';
        }
      } else if (table == 'jenis_pelanggaran') {
        final nama = record['nama'] ?? 'Jenis Pelanggaran';
        if (payload.eventType == PostgresChangeEvent.insert) {
          title = 'Jenis Pelanggaran Ditambahkan';
          message = 'Jenis pelanggaran baru "$nama" telah ditambahkan';
        } else if (payload.eventType == PostgresChangeEvent.update) {
          title = 'Jenis Pelanggaran Diperbarui';
          message = 'Jenis pelanggaran "$nama" telah diperbarui';
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          title = 'Jenis Pelanggaran Dihapus';
          message = 'Jenis pelanggaran "$nama" telah dihapus';
        }
      }

      if (title.isEmpty) return;

      if (currentUser.isNotEmpty && actor.isNotEmpty && currentUser == actor.toUpperCase()) {
        return;
      }

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
      if (list.any((n) => n.title == title && n.body == message && DateTime.now().difference(n.timestamp).inSeconds < 4)) {
        return;
      }

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
    } catch (e) {
      debugPrint('Realtime handle error: $e');
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

      final androidDetails = AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
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
    required String category, // 'arsip', 'laporan', 'proker', 'pelanggaran', 'manajemen'
    required String actor,
    List<String>? targetRoles,
  }) async {
    try {
      final roles = targetRoles ?? targetStakeholders;

      // 1. Broadcast ke perangkat lain yang sedang online via Supabase Realtime Channel
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

  static Future<void> markAllAsRead({String? forUser}) async {
    try {
      if (forUser != null && forUser.isNotEmpty && !isTargetRole(forUser)) {
        return;
      }
      final u = forUser?.trim().toUpperCase();
      final prefs = await SharedPreferences.getInstance();
      final all = await getNotifications();
      final updated = all.map((n) {
        if (u == null || n.targetRoles.isEmpty || n.targetRoles.map((r) => r.toUpperCase()).contains(u)) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();
      final jsonString = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(_keyNotifications, jsonString);
    } catch (_) {}
  }

  static Future<void> markAsRead(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getNotifications();
      final updated = all.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
      final jsonString = jsonEncode(updated.map((e) => e.toJson()).toList());
      await prefs.setString(_keyNotifications, jsonString);
    } catch (_) {}
  }

  static Future<void> deleteNotification(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final all = await getNotifications();
      all.removeWhere((n) => n.id == id);
      final jsonString = jsonEncode(all.map((e) => e.toJson()).toList());
      await prefs.setString(_keyNotifications, jsonString);
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyNotifications);
    } catch (_) {}
  }
}
