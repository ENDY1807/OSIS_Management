import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as exc;
import '../models/models.dart';
import 'auth_service.dart';
import 'sync_service.dart';
import 'app_settings_service.dart';

const _uuid = Uuid();

class DataService {
  static const _supabaseUrl = 'https://vvvrzxaxnumtstlgovqw.supabase.co';
  static const _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2dnJ6eGF4bnVtdHN0bGdvdnF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI2MzMxOTksImV4cCI6MjA5ODIwOTE5OX0.XHGfzuADTS9BCILR6FAm0RIOxpslwX6DJkABYaan1Eo';

  static const _keyFileRiwayat = 'file_riwayat';

  // Cache keys (fallback offline)
  static const _keySiswa        = 'siswa';
  static const _keyJenis        = 'jenis_pelanggaran';
  static const _keyPelanggaran  = 'pelanggaran';
  static const _keyProker       = 'proker';
  static const _keyArsip        = 'arsip';
  static const _keyArsipFolder  = 'arsip_folder';
  static const _keyLaporan      = 'laporan_kegiatan_v2';
  static const _keySekbid       = 'sekbid';
  static final String _localClientId = const Uuid().v4();

  static final StreamController<String> _dataChangeController = StreamController<String>.broadcast();
  static Stream<String> get onDataChanged => _dataChangeController.stream;
  static RealtimeChannel? _realtimeChannel;

  static void notifyDataChanged(String table) {
    if (!_dataChangeController.isClosed) {
      _dataChangeController.add(table);
    }
  }

  static void initRealtime() {
    if (!_initialized || _realtimeChannel != null) return;
    try {
      _realtimeChannel = _db.channel('osis_data_sync_channel');

      // 1. Listen to broadcast data change messages across all devices
      _realtimeChannel?.onBroadcast(
        event: 'data_changed',
        callback: (payload) {
          final clientId = payload['client_id']?.toString();
          // Abaikan pesan broadcast yang berasal dari device sendiri untuk mencegah feedback loop / overwrite
          if (clientId != null && clientId == _localClientId) {
            return;
          }

          final table = payload['table']?.toString() ?? 'all';
          debugPrint('Realtime broadcast data changed from remote device: $table');
          if (table == 'accounts' || table == 'all') {
            AuthService.syncWithSupabase();
          }
          if (table == 'app_settings' || table == 'sekbid' || table == 'all') {
            if (payload['primary_color'] != null) {
              final colorStr = payload['primary_color'].toString();
              try {
                final parsedInt = int.parse(colorStr.replaceFirst('#', '').replaceFirst('0x', ''), radix: 16);
                final fullColor = (parsedInt <= 0xFFFFFF) ? 0xFF000000 | parsedInt : parsedInt;
                AppSettingsService.accentColorNotifier.value = Color(fullColor);
                SharedPreferences.getInstance().then((p) => p.setInt('app_accent_color', fullColor));
              } catch (_) {}
            }
            if (payload['app_name'] != null) {
              AppSettingsService.appNameNotifier.value = payload['app_name'].toString();
            }
            if (payload['app_subtitle'] != null) {
              AppSettingsService.appSubtitleNotifier.value = payload['app_subtitle'].toString();
            }
            if (payload['logo_url'] != null) {
              AppSettingsService.logoUrlNotifier.value = payload['logo_url'].toString();
            }
            if (payload['custom_fields'] != null) {
              try {
                dynamic raw = payload['custom_fields'];
                if (raw is String) raw = jsonDecode(raw);
                if (raw is Map) {
                  final Map<String, List<AppCustomInputField>> map = {};
                  raw.forEach((key, val) {
                    if (val is List) {
                      map[key.toString()] = val.map((e) => AppCustomInputField.fromJson(Map<String, dynamic>.from(e as Map))).toList();
                    }
                  });
                  if (map.isNotEmpty) {
                    AppSettingsService.customFieldsNotifier.value = map;
                    SharedPreferences.getInstance().then((p) => p.setString('cfg_dynamic_custom_fields', jsonEncode(raw)));
                  }
                }
              } catch (_) {}
            }
            AppSettingsService.syncFromSupabase();
          }
          notifyDataChanged(table);
        },
      );

      // 2. Listen to Database Postgres Changes for all data tables
      const monitoredTables = [
        'siswa',
        'jenis_pelanggaran',
        'pelanggaran',
        'proker',
        'arsip',
        'laporan_kegiatan',
        'file_riwayat',
        'accounts',
        'app_settings',
        'sekbid',
      ];
      for (final table in monitoredTables) {
        _realtimeChannel?.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (payload) {
            debugPrint('Postgres change on $table: ${payload.eventType}');
            if (table == 'accounts') {
              AuthService.syncWithSupabase();
            }
            if (table == 'app_settings' || table == 'sekbid') {
              if (payload.newRecord.isNotEmpty) {
                final newRec = payload.newRecord;
                if (newRec['primary_color'] != null) {
                  final colorStr = newRec['primary_color'].toString();
                  try {
                    final parsedInt = int.parse(colorStr.replaceFirst('#', '').replaceFirst('0x', ''), radix: 16);
                    final fullColor = (parsedInt <= 0xFFFFFF) ? 0xFF000000 | parsedInt : parsedInt;
                    AppSettingsService.accentColorNotifier.value = Color(fullColor);
                    SharedPreferences.getInstance().then((p) => p.setInt('app_accent_color', fullColor));
                  } catch (_) {}
                }
                if (newRec['app_name'] != null) {
                  AppSettingsService.appNameNotifier.value = newRec['app_name'].toString();
                }
                if (newRec['app_subtitle'] != null) {
                  AppSettingsService.appSubtitleNotifier.value = newRec['app_subtitle'].toString();
                }
                if (newRec['logo_url'] != null) {
                  AppSettingsService.logoUrlNotifier.value = newRec['logo_url'].toString();
                }
                if (newRec['custom_fields'] != null) {
                  try {
                    dynamic raw = newRec['custom_fields'];
                    if (raw is String) raw = jsonDecode(raw);
                    if (raw is Map) {
                      final Map<String, List<AppCustomInputField>> map = {};
                      raw.forEach((key, val) {
                        if (val is List) {
                          map[key.toString()] = val.map((e) => AppCustomInputField.fromJson(Map<String, dynamic>.from(e as Map))).toList();
                        }
                      });
                      if (map.isNotEmpty) {
                        AppSettingsService.customFieldsNotifier.value = map;
                        SharedPreferences.getInstance().then((p) => p.setString('cfg_dynamic_custom_fields', jsonEncode(raw)));
                      }
                    }
                  } catch (_) {}
                }
              }
              AppSettingsService.syncFromSupabase();
            }
            notifyDataChanged(table);
          },
        );
      }

      _realtimeChannel?.subscribe();
    } catch (e) {
      debugPrint('DataService realtime subscription error: $e');
    }
  }

  static Future<List<String>> getSekbidList() async {
    if (AppSettingsService.sekbidListNotifier.value.isNotEmpty) {
      return AppSettingsService.sekbidListNotifier.value;
    }
    final cache = await _readCache(_keySekbid);
    if (cache.isNotEmpty) {
      final list = cache.map((e) => (e['name'] ?? e['nama'] ?? '').toString()).where((s) => s.isNotEmpty).toList();
      if (list.isNotEmpty) {
        AppSettingsService.sekbidListNotifier.value = list;
        return list;
      }
    }
    return AppSettingsService.sekbidListNotifier.value;
  }

  static Future<void> saveSekbidList(List<String> sekbids) async {
    AppSettingsService.sekbidListNotifier.value = List.from(sekbids);
    await _saveCache(_keySekbid, sekbids.map((s) => {'name': s}).toList());
    await AppSettingsService.saveAdminConfigs(sekbidList: sekbids);
    if (SyncService.isOnline) {
      try {
        for (int i = 0; i < sekbids.length; i++) {
          await _db.from('sekbid').upsert({
            'id': 'sekbid_${i + 1}',
            'name': sekbids[i],
            'urutan': i + 1,
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'id');
        }
        await broadcastDataChange('sekbid');
      } catch (_) {}
    }
  }

  static Future<void> broadcastDataChange(String table, [Map<String, dynamic>? extra]) async {
    notifyDataChanged(table);
    try {
      if (_realtimeChannel == null) initRealtime();
      final payload = <String, dynamic>{
        'table': table,
        'client_id': _localClientId,
        'timestamp': DateTime.now().toIso8601String(),
        if (extra != null) ...extra,
      };
      await _realtimeChannel?.sendBroadcastMessage(
        event: 'data_changed',
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error broadcasting data change for $table: $e');
    }
  }

  static SupabaseClient get _db {
    if (!_initialized) throw StateError('Supabase belum diinisialisasi');
    return Supabase.instance.client;
  }

  static bool _initialized = false;

  static Future<void> initializeSupabase() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabaseKey,
    );
    _initialized = true;
    initRealtime();
    // Inisialisasi SyncService untuk manajemen antrean offline/online
    try {
      await SyncService.init();
    } catch (e) {
      debugPrint('SyncService init in DataService warning: $e');
    }
    // Sinkronisasi akun dari Supabase secara asinkron
    unawaited(AuthService.syncWithSupabase());
    // Sinkronisasi konfigurasi aplikasi & warna dari Supabase secara asinkron
    unawaited(AppSettingsService.syncFromSupabase());
    // Hapus cache lama yang tidak kompatibel
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('laporan_kegiatan');
  }

  // ── helpers cache ────────────────────────────────────────────────────────
  static Future<void> _saveCache(String key, List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, list.map((e) => jsonEncode(e)).toList());
    } catch (e) {
      debugPrint('Error saving cache for $key: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(key) ?? [];
      return list.map((e) {
        try {
          return Map<String, dynamic>.from(jsonDecode(e) as Map);
        } catch (_) {
          return <String, dynamic>{};
        }
      }).where((m) => m.isNotEmpty).toList();
    } catch (e) {
      debugPrint('Error reading cache for $key: $e');
      return [];
    }
  }

  // Default dataset siswa untuk inisialisasi awal offline jika belum ada data sama sekali
  static const List<Map<String, dynamic>> _defaultSiswa = [
    {'id': 's-1', 'nama': 'Ahmad Fauzi', 'kelas': 'X RPL 1', 'nis': '23241001'},
    {'id': 's-2', 'nama': 'Annisa Rahmawati', 'kelas': 'X RPL 1', 'nis': '23241002'},
    {'id': 's-3', 'nama': 'Bagas Pratama', 'kelas': 'X TKJ 1', 'nis': '23241003'},
    {'id': 's-4', 'nama': 'Dewi Lestari', 'kelas': 'XI RPL 2', 'nis': '22231015'},
    {'id': 's-5', 'nama': 'Dimas Saputra', 'kelas': 'XI TKJ 2', 'nis': '22231020'},
    {'id': 's-6', 'nama': 'Fajar Hidayat', 'kelas': 'XII RPL 1', 'nis': '21221005'},
    {'id': 's-7', 'nama': 'Gita Nurul', 'kelas': 'XII DKV 1', 'nis': '21221012'},
    {'id': 's-8', 'nama': 'Rizky Ramadhan', 'kelas': 'X DKV 2', 'nis': '23241030'},
    {'id': 's-9', 'nama': 'Siti Aisyah', 'kelas': 'XI DKV 2', 'nis': '22231040'},
    {'id': 's-10', 'nama': 'Zahra Putri', 'kelas': 'XII TKJ 1', 'nis': '21221055'},
  ];

  // ── Siswa ────────────────────────────────────────────────────────────────
  static Future<List<Siswa>> getSiswa() async {
    // 1. Jika offline, langsung ambil dari cache lokal instan tanpa menunggu network
    if (!SyncService.isOnline) {
      final cache = await _readCache(_keySiswa);
      if (cache.isNotEmpty) {
        return cache.map(Siswa.fromJson).toList();
      }
      await _saveCache(_keySiswa, _defaultSiswa);
      return _defaultSiswa.map(Siswa.fromJson).toList();
    }

    // 2. Jika online, tarik dari Supabase dengan timeout aman
    try {
      final rows = await _db.from('siswa').select().order('nama').timeout(const Duration(seconds: 4));
      final list = (rows as List).map((e) => Siswa.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (list.isNotEmpty) {
        await _saveCache(_keySiswa, list.map((e) => e.toJson()).toList());
      }
      return list;
    } catch (_) {
      final cache = await _readCache(_keySiswa);
      if (cache.isEmpty) {
        await _saveCache(_keySiswa, _defaultSiswa);
        return _defaultSiswa.map(Siswa.fromJson).toList();
      }
      return cache.map(Siswa.fromJson).toList();
    }
  }

  static Future<void> saveSiswa(List<Siswa> list) async {
    await _saveCache(_keySiswa, list.map((e) => e.toJson()).toList());
  }

  static Future<Siswa> addSiswa(String nama, String kelas, String nis) async {
    final s = Siswa(id: _uuid.v4(), nama: nama, kelas: kelas, nis: nis);
    // 1. Update cache lokal instan
    final cache = await _readCache(_keySiswa);
    cache.add(s.toJson());
    await _saveCache(_keySiswa, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('siswa').insert(s.toJson());
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.insert,
          table: 'siswa',
          data: s.toJson(),
          targetId: s.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.insert,
        table: 'siswa',
        data: s.toJson(),
        targetId: s.id,
      );
    }
    await broadcastDataChange('siswa');
    return s;
  }

  static Future<void> updateSiswa(Siswa s) async {
    // 1. Update cache lokal instan
    final cache = await _readCache(_keySiswa);
    final index = cache.indexWhere((item) => item['id'] == s.id);
    if (index != -1) {
      cache[index] = s.toJson();
    } else {
      cache.add(s.toJson());
    }
    await _saveCache(_keySiswa, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('siswa').upsert(s.toJson());
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'siswa',
          data: s.toJson(),
          targetId: s.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'siswa',
        data: s.toJson(),
        targetId: s.id,
      );
    }
    await broadcastDataChange('siswa');
  }

  static Future<void> deleteSiswaByNisList(List<String> nisList) async {
    if (nisList.isEmpty) return;
    // 1. Update cache lokal instan
    final cache = await _readCache(_keySiswa);
    final toDelete = cache
        .where((item) => nisList.contains(item['nis']))
        .map((e) => e['id']?.toString())
        .whereType<String>()
        .toList();
    cache.removeWhere((item) => nisList.contains(item['nis']));
    await _saveCache(_keySiswa, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('siswa').delete().inFilter('nis', nisList);
      } catch (e) {
        for (final id in toDelete) {
          await SyncService.enqueueAction(
            actionType: SyncActionType.delete,
            table: 'siswa',
            targetId: id,
          );
        }
      }
    } else {
      for (final id in toDelete) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'siswa',
          targetId: id,
        );
      }
    }
    await broadcastDataChange('siswa');
  }

  static Future<void> deleteSiswa(String id) async {
    // 1. Update cache lokal instan
    final cache = await _readCache(_keySiswa);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keySiswa, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('siswa').delete().eq('id', id);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'siswa',
          targetId: id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'siswa',
        targetId: id,
      );
    }
    await broadcastDataChange('siswa');
  }

  // ── Jenis Pelanggaran ────────────────────────────────────────────────────
  static Future<List<JenisPelanggaran>> getJenis() async {
    // 1. Jika offline, baca langsung dari cache lokal instan
    if (!SyncService.isOnline) {
      final cache = await _readCache(_keyJenis);
      if (cache.isNotEmpty) {
        return cache.map(JenisPelanggaran.fromJson).toList();
      }
      return _defaultJenis();
    }

    // 2. Jika online, ambil dari Supabase
    try {
      final rows = await _db.from('jenis_pelanggaran').select().timeout(const Duration(seconds: 4));
      if (rows.isEmpty) {
        final defaults = _defaultJenis();
        for (final j in defaults) {
          try {
            await _db.from('jenis_pelanggaran').upsert(j.toJson());
          } catch (_) {}
        }
        await _saveCache(_keyJenis, defaults.map((e) => e.toJson()).toList());
        return defaults;
      }
      final list = (rows as List).map((e) => JenisPelanggaran.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      await _saveCache(_keyJenis, list.map((e) => e.toJson()).toList());
      return list;
    } catch (_) {
      final cache = await _readCache(_keyJenis);
      if (cache.isEmpty) return _defaultJenis();
      return cache.map(JenisPelanggaran.fromJson).toList();
    }
  }

  static List<JenisPelanggaran> _defaultJenis() => [
        // Senin saja
        JenisPelanggaran(id: _uuid.v4(), nama: 'Tidak pakai Dasi',     hariAktif: [1]),
        JenisPelanggaran(id: _uuid.v4(), nama: 'Tidak pakai Rompi',    hariAktif: [1]),
        JenisPelanggaran(id: _uuid.v4(), nama: 'Tidak pakai Pin BNCC', hariAktif: [1]),
        // Selasa saja
        JenisPelanggaran(id: _uuid.v4(), nama: 'Tidak pakai Kacu',     hariAktif: [2]),
        // Senin–Jumat
        JenisPelanggaran(id: _uuid.v4(), nama: 'Tidak pakai Sabuk',         hariAktif: [1,2,3,4,5]),
        JenisPelanggaran(id: _uuid.v4(), nama: 'Kaos kaki tidak sesuai',    hariAktif: [1,2,3,4,5]),
        JenisPelanggaran(id: _uuid.v4(), nama: 'Tidak pakai ID Card',       hariAktif: [1,2,3,4,5]),
        JenisPelanggaran(id: _uuid.v4(), nama: 'Sepatu tidak sesuai',       hariAktif: [1,2,3,4,5]),
        JenisPelanggaran(id: _uuid.v4(), nama: 'Tidak pakai Sepatu',        hariAktif: [1,2,3,4,5]),
      ];

  static Future<void> saveJenis(List<JenisPelanggaran> list) async {
    await _saveCache(_keyJenis, list.map((e) => e.toJson()).toList());
  }

  static Future<JenisPelanggaran> addJenis(String nama, {List<int> hariAktif = const []}) async {
    final j = JenisPelanggaran(id: _uuid.v4(), nama: nama, hariAktif: hariAktif);
    final dbData = {'id': j.id, 'nama': j.nama, 'hari_aktif': j.hariAktif};

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyJenis);
    cache.add(j.toJson());
    await _saveCache(_keyJenis, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('jenis_pelanggaran').insert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.insert,
          table: 'jenis_pelanggaran',
          data: dbData,
          targetId: j.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.insert,
        table: 'jenis_pelanggaran',
        data: dbData,
        targetId: j.id,
      );
    }
    await broadcastDataChange('jenis_pelanggaran');
    return j;
  }

  static Future<void> updateJenis(JenisPelanggaran j) async {
    final dbData = {'id': j.id, 'nama': j.nama, 'hari_aktif': j.hariAktif};

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyJenis);
    final index = cache.indexWhere((item) => item['id'] == j.id);
    if (index != -1) {
      cache[index] = j.toJson();
    } else {
      cache.add(j.toJson());
    }
    await _saveCache(_keyJenis, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('jenis_pelanggaran').upsert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'jenis_pelanggaran',
          data: dbData,
          targetId: j.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'jenis_pelanggaran',
        data: dbData,
        targetId: j.id,
      );
    }
    await broadcastDataChange('jenis_pelanggaran');
  }

  static Future<void> deleteJenis(String id) async {
    // 1. Update cache lokal instan
    final cache = await _readCache(_keyJenis);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyJenis, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('jenis_pelanggaran').delete().eq('id', id);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'jenis_pelanggaran',
          targetId: id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'jenis_pelanggaran',
        targetId: id,
      );
    }
    await broadcastDataChange('jenis_pelanggaran');
  }

  // ── Pelanggaran ──────────────────────────────────────────────────────────
  static Future<List<Pelanggaran>> getPelanggaran() async {
    List<Siswa>? siswaCache;

    // 1. Jika offline, langsung ambil dari cache lokal instan
    if (!SyncService.isOnline) {
      final cache = await _readCache(_keyPelanggaran);
      final list = cache.map((e) => Pelanggaran.fromJson(e)).toList();
      if (list.any((p) => p.namaSiswa == null || p.namaSiswa!.isEmpty)) {
        siswaCache ??= await getSiswa();
        for (final p in list) {
          if (p.namaSiswa == null || p.namaSiswa!.isEmpty) {
            final s = siswaCache.firstWhere(
              (item) => item.id == p.siswaId,
              orElse: () => Siswa(id: '', nama: '', kelas: '', nis: ''),
            );
            if (s.nama.isNotEmpty) {
              p.namaSiswa = s.nama;
              p.kelasSiswa = s.kelas;
              p.nisSiswa = s.nis;
            }
          }
        }
      }
      return list;
    }

    // 2. Jika online, ambil dari Supabase dengan timeout
    try {
      final rows = await _db.from('pelanggaran').select().order('tanggal', ascending: false).timeout(const Duration(seconds: 4));
      final list = (rows as List).map((e) => Pelanggaran(
            id: e['id'],
            siswaId: e['siswa_id'] ?? '',
            jenisId: e['jenis_id'] ?? '',
            tanggal: DateTime.parse(e['tanggal']),
            keterangan: e['keterangan'] ?? '',
            namaSiswa: e['nama_siswa'] ?? e['siswa_nama'],
            kelasSiswa: e['kelas_siswa'] ?? e['siswa_kelas'],
            nisSiswa: e['nis_siswa'] ?? e['siswa_nis'],
          )).toList();

      // Backfill snapshot info if missing using active Siswa list
      if (list.any((p) => p.namaSiswa == null || p.namaSiswa!.isEmpty)) {
        siswaCache = await getSiswa();
        for (final p in list) {
          if (p.namaSiswa == null || p.namaSiswa!.isEmpty) {
            final s = siswaCache.firstWhere(
              (item) => item.id == p.siswaId,
              orElse: () => Siswa(id: '', nama: '', kelas: '', nis: ''),
            );
            if (s.nama.isNotEmpty) {
              p.namaSiswa = s.nama;
              p.kelasSiswa = s.kelas;
              p.nisSiswa = s.nis;
            }
          }
        }
      }

      final cacheData = list.map((p) => p.toJson()).toList();
      await _saveCache(_keyPelanggaran, cacheData);
      return list;
    } catch (_) {
      final cache = await _readCache(_keyPelanggaran);
      final list = cache.map((e) => Pelanggaran.fromJson(e)).toList();
      if (list.any((p) => p.namaSiswa == null || p.namaSiswa!.isEmpty)) {
        siswaCache ??= await getSiswa();
        for (final p in list) {
          if (p.namaSiswa == null || p.namaSiswa!.isEmpty) {
            final s = siswaCache.firstWhere(
              (item) => item.id == p.siswaId,
              orElse: () => Siswa(id: '', nama: '', kelas: '', nis: ''),
            );
            if (s.nama.isNotEmpty) {
              p.namaSiswa = s.nama;
              p.kelasSiswa = s.kelas;
              p.nisSiswa = s.nis;
            }
          }
        }
      }
      return list;
    }
  }

  static Future<void> savePelanggaran(List<Pelanggaran> list) async {
    await _saveCache(_keyPelanggaran, list.map((e) => e.toJson()).toList());
  }

  static Future<void> addPelanggaran(
    String siswaId,
    String jenisId,
    String ket, {
    DateTime? tanggal,
    String? namaSiswa,
    String? kelasSiswa,
    String? nisSiswa,
  }) async {
    String? snapNama = namaSiswa;
    String? snapKelas = kelasSiswa;
    String? snapNis = nisSiswa;

    if (snapNama == null || snapNama.isEmpty) {
      final sList = await getSiswa();
      final s = sList.firstWhere(
        (item) => item.id == siswaId,
        orElse: () => Siswa(id: '', nama: '', kelas: '', nis: ''),
      );
      if (s.nama.isNotEmpty) {
        snapNama = s.nama;
        snapKelas = s.kelas;
        snapNis = s.nis;
      }
    }

    final pelanggaran = Pelanggaran(
      id: _uuid.v4(),
      siswaId: siswaId,
      jenisId: jenisId,
      tanggal: tanggal ?? DateTime.now(),
      keterangan: ket,
      namaSiswa: snapNama,
      kelasSiswa: snapKelas,
      nisSiswa: snapNis,
    );
    
    // Data untuk database (snake_case)
    final dbData = {
      'id': pelanggaran.id,
      'siswa_id': pelanggaran.siswaId,
      'jenis_id': pelanggaran.jenisId,
      'tanggal': pelanggaran.tanggal.toIso8601String(),
      'keterangan': pelanggaran.keterangan,
    };
    
    // 1. Update cache lokal instan
    final cache = await _readCache(_keyPelanggaran);
    cache.insert(0, pelanggaran.toJson());
    await _saveCache(_keyPelanggaran, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('pelanggaran').insert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.insert,
          table: 'pelanggaran',
          data: dbData,
          targetId: pelanggaran.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.insert,
        table: 'pelanggaran',
        data: dbData,
        targetId: pelanggaran.id,
      );
    }

    await broadcastDataChange('pelanggaran');
  }

  static Future<void> deletePelanggaran(String id) async {
    // 1. Update cache lokal instan
    final cache = await _readCache(_keyPelanggaran);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyPelanggaran, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('pelanggaran').delete().eq('id', id);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'pelanggaran',
          targetId: id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'pelanggaran',
        targetId: id,
      );
    }
    await broadcastDataChange('pelanggaran');
  }

  // ── Proker ───────────────────────────────────────────────────────────────
  static Future<List<Proker>> getProker() async {
    if (!SyncService.isOnline) {
      final cache = await _readCache(_keyProker);
      return cache.map(Proker.fromJson).toList();
    }
    try {
      final rows = await _db.from('proker').select().order('tanggal_rencana').timeout(const Duration(seconds: 4));
      final list = (rows as List).map((e) => Proker(
            id: e['id'],
            nama: e['nama'],
            deskripsi: e['deskripsi'] ?? '',
            sekbid: e['sekbid'] ?? '',
            penanggungJawab: e['penanggung_jawab'] ?? '',
            tanggalRencana: DateTime.parse(e['tanggal_rencana']),
            tanggalRealisasi: e['tanggal_realisasi'] != null ? DateTime.parse(e['tanggal_realisasi']) : null,
            status: e['status'] ?? StatusProker.belum,
            keterangan: e['keterangan'] ?? '',
          )).toList();
      final cacheData = list.map((p) => p.toJson()).toList();
      await _saveCache(_keyProker, cacheData);
      return list;
    } catch (_) {
      final cache = await _readCache(_keyProker);
      return cache.map(Proker.fromJson).toList();
    }
  }

  static Future<void> saveProker(List<Proker> list) async {
    await _saveCache(_keyProker, list.map((e) => e.toJson()).toList());
  }

  static Future<void> addProker(Proker p) async {
    final dbData = {
      'id': p.id,
      'nama': p.nama,
      'deskripsi': p.deskripsi,
      'sekbid': p.sekbid,
      'penanggung_jawab': p.penanggungJawab,
      'tanggal_rencana': p.tanggalRencana.toIso8601String(),
      'tanggal_realisasi': p.tanggalRealisasi?.toIso8601String(),
      'status': p.status,
      'keterangan': p.keterangan,
    };

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyProker);
    cache.add(p.toJson());
    await _saveCache(_keyProker, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('proker').insert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.insert,
          table: 'proker',
          data: dbData,
          targetId: p.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.insert,
        table: 'proker',
        data: dbData,
        targetId: p.id,
      );
    }
    await broadcastDataChange('proker');
  }

  static Future<void> updateProker(Proker p) async {
    final dbData = {
      'id': p.id,
      'nama': p.nama,
      'deskripsi': p.deskripsi,
      'sekbid': p.sekbid,
      'penanggung_jawab': p.penanggungJawab,
      'tanggal_rencana': p.tanggalRencana.toIso8601String(),
      'tanggal_realisasi': p.tanggalRealisasi?.toIso8601String(),
      'status': p.status,
      'keterangan': p.keterangan,
    };

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyProker);
    final index = cache.indexWhere((item) => item['id'] == p.id);
    if (index != -1) {
      cache[index] = p.toJson();
    } else {
      cache.add(p.toJson());
    }
    await _saveCache(_keyProker, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('proker').upsert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'proker',
          data: dbData,
          targetId: p.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'proker',
        data: dbData,
        targetId: p.id,
      );
    }
    await broadcastDataChange('proker');
  }

  static Future<void> deleteProker(String id) async {
    // 1. Update cache lokal instan
    final cache = await _readCache(_keyProker);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyProker, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('proker').delete().eq('id', id);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'proker',
          targetId: id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'proker',
        targetId: id,
      );
    }
    await broadcastDataChange('proker');
  }

  // ── Arsip ────────────────────────────────────────────────────────────────
  static Future<List<Arsip>> getArsip() async {
    if (!SyncService.isOnline) {
      final cache = await _readCache(_keyArsip);
      return cache.map(Arsip.fromJson).toList();
    }
    try {
      final rows = await _db.from('arsip').select().order('tanggal', ascending: false).timeout(const Duration(seconds: 4));
      final list = (rows as List).map((e) => Arsip(
            id: e['id'],
            judul: e['judul'],
            kategori: e['kategori'] ?? KategoriArsip.lainnya,
            deskripsi: e['deskripsi'] ?? '',
            nomorSurat: e['nomor_surat'] ?? '',
            tanggal: DateTime.parse(e['tanggal']),
            pembuatId: e['pembuat_id'] ?? '',
            fileUrl: e['file_url'] ?? '',
            keterangan: e['keterangan'] ?? '',
          )).toList();
      final cacheData = list.map((a) => a.toJson()).toList();
      await _saveCache(_keyArsip, cacheData);
      return list;
    } catch (_) {
      final cache = await _readCache(_keyArsip);
      return cache.map(Arsip.fromJson).toList();
    }
  }

  static Future<void> saveArsip(List<Arsip> list) async {
    await _saveCache(_keyArsip, list.map((e) => e.toJson()).toList());
  }

  static Future<void> addArsip(Arsip a) async {
    final dbData = {
      'id': a.id,
      'judul': a.judul,
      'kategori': a.kategori,
      'deskripsi': a.deskripsi,
      'nomor_surat': a.nomorSurat,
      'tanggal': a.tanggal.toIso8601String(),
      'pembuat_id': a.pembuatId,
      'file_url': a.fileUrl,
      'keterangan': a.keterangan,
    };

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyArsip);
    cache.add(a.toJson());
    await _saveCache(_keyArsip, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('arsip').insert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.insert,
          table: 'arsip',
          data: dbData,
          targetId: a.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.insert,
        table: 'arsip',
        data: dbData,
        targetId: a.id,
      );
    }
    await broadcastDataChange('arsip');
  }

  static Future<void> updateArsip(Arsip a) async {
    final dbData = {
      'id': a.id,
      'judul': a.judul,
      'kategori': a.kategori,
      'deskripsi': a.deskripsi,
      'nomor_surat': a.nomorSurat,
      'tanggal': a.tanggal.toIso8601String(),
      'pembuat_id': a.pembuatId,
      'file_url': a.fileUrl,
      'keterangan': a.keterangan,
    };

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyArsip);
    final index = cache.indexWhere((item) => item['id'] == a.id);
    if (index != -1) {
      cache[index] = a.toJson();
    } else {
      cache.add(a.toJson());
    }
    await _saveCache(_keyArsip, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('arsip').upsert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'arsip',
          data: dbData,
          targetId: a.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'arsip',
        data: dbData,
        targetId: a.id,
      );
    }
    await broadcastDataChange('arsip');
  }

  // ── Arsip Folder ─────────────────────────────────────────────────────────
  static Future<List<String>> getArsipFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> folderSet = {};
    try {
      final arsipList = await getArsip();
      for (final a in arsipList) {
        final clean = a.kategori.trim();
        if (clean.isEmpty || clean.toLowerCase() == 'root') continue;
        final parts = clean.split('/');
        String current = '';
        for (final p in parts) {
          final segment = p.trim();
          if (segment.isEmpty || segment.toLowerCase() == 'root') continue;
          current = current.isEmpty ? segment : '$current/$segment';
          folderSet.add(current);
        }
      }
      final list = folderSet.toList()..sort();
      // Overwrite local cache with fresh list from server so deleted folders are not retained
      await prefs.setStringList(_keyArsipFolder, list);
      return list;
    } catch (_) {
      final localFolders = prefs.getStringList(_keyArsipFolder) ?? [];
      for (final lf in localFolders) {
        final clean = lf.trim();
        if (clean.isNotEmpty && clean.toLowerCase() != 'root') {
          folderSet.add(clean);
        }
      }
      return folderSet.toList()..sort();
    }
  }

  static Future<void> addArsipFolder(String nama) async {
    final clean = nama.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'root') return;

    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList(_keyArsipFolder) ?? [];
    if (!folders.contains(clean)) {
      folders.add(clean);
      await prefs.setStringList(_keyArsipFolder, folders);
    }

    // Save folder marker into Supabase arsip table so all users receive the folder
    final allArsip = await getArsip();
    final exists = allArsip.any((a) => a.kategori == clean);
    if (!exists) {
      final folderMarker = Arsip(
        id: _uuid.v4(),
        judul: clean.split('/').last,
        kategori: clean,
        deskripsi: '',
        nomorSurat: '__dir__',
        tanggal: DateTime.now(),
        pembuatId: '',
        fileUrl: '',
        keterangan: '__folder__',
      );
      await addArsip(folderMarker);
    } else {
      await broadcastDataChange('arsip');
    }
  }

  static Future<void> saveArsipFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyArsipFolder, folders);
    for (final f in folders) {
      await addArsipFolder(f);
    }
    await broadcastDataChange('arsip');
  }

  static Future<void> deleteArsipFolder(String nama) async {
    final clean = nama.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'root') return;

    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList(_keyArsipFolder) ?? [];
    folders.removeWhere((f) => f == clean || f.startsWith('$clean/'));
    await prefs.setStringList(_keyArsipFolder, folders);

    // Delete matching items (files and folder markers) from Supabase by ID and by kategori
    try {
      final rows = await _db.from('arsip').select('id, kategori');
      final toDeleteIds = rows
          .where((r) {
            final kat = (r['kategori'] ?? '').toString().trim();
            return kat == clean || kat.startsWith('$clean/');
          })
          .map((r) => r['id'].toString())
          .toList();
      if (toDeleteIds.isNotEmpty) {
        await _db.from('arsip').delete().inFilter('id', toDeleteIds);
      }
    } catch (_) {
      try {
        await _db.from('arsip').delete().eq('kategori', clean);
        await _db.from('arsip').delete().like('kategori', '$clean/%');
      } catch (_) {}
    }

    final cache = await _readCache(_keyArsip);
    cache.removeWhere((item) {
      final kat = item['kategori'] ?? '';
      return kat == clean || kat.toString().startsWith('$clean/');
    });
    await _saveCache(_keyArsip, cache);
    await broadcastDataChange('arsip');
  }

  static Future<void> renameArsipFolder(String oldPath, String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList(_keyArsipFolder) ?? [];
    final updatedFolders = <String>[];
    for (final f in folders) {
      if (f == oldPath) {
        updatedFolders.add(newPath);
      } else if (f.startsWith('$oldPath/')) {
        updatedFolders.add(f.replaceFirst(oldPath, newPath));
      } else {
        updatedFolders.add(f);
      }
    }
    await prefs.setStringList(_keyArsipFolder, updatedFolders);

    // Update all arsip items (files and folder markers) inside that folder
    final allArsip = await getArsip();
    for (final a in allArsip) {
      if (a.kategori == oldPath) {
        a.kategori = newPath;
        if (a.keterangan == '__folder__' || a.nomorSurat == '__dir__') {
          a.judul = newPath.split('/').last;
        }
        await updateArsip(a);
      } else if (a.kategori.startsWith('$oldPath/')) {
        a.kategori = a.kategori.replaceFirst(oldPath, newPath);
        await updateArsip(a);
      }
    }
    await broadcastDataChange('arsip');
  }

  static Future<void> moveArsipToFolder(List<String> ids, String targetFolder) async {
    final allArsip = await getArsip();
    for (final a in allArsip) {
      if (ids.contains(a.id)) {
        a.kategori = targetFolder;
        await updateArsip(a);
      }
    }
    await broadcastDataChange('arsip');
  }

  static Future<void> copyArsipToFolder(List<Arsip> list, String targetFolder) async {
    for (final a in list) {
      final copy = Arsip(
        id: _uuid.v4(),
        judul: '${a.judul} (Copy)',
        kategori: targetFolder,
        deskripsi: a.deskripsi,
        nomorSurat: a.nomorSurat,
        tanggal: DateTime.now(),
        pembuatId: a.pembuatId,
        fileUrl: a.fileUrl,
        keterangan: a.keterangan,
      );
      await addArsip(copy);
    }
    await broadcastDataChange('arsip');
  }

  static Future<void> deleteArsip(String id) async {
    // 1. Update cache lokal instan
    final cache = await _readCache(_keyArsip);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyArsip, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('arsip').delete().eq('id', id);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'arsip',
          targetId: id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'arsip',
        targetId: id,
      );
    }
    await broadcastDataChange('arsip');
  }

  static const _mimeTypes = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };

  static Future<String> uploadArsipFile(Uint8List bytes, String fileName) async {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    final path = '${_uuid.v4()}${ext.isNotEmpty ? '.$ext' : ''}';
    final mime = _mimeTypes[ext] ?? 'application/octet-stream';
    await _db.storage.from('arsip').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    return _db.storage.from('arsip').getPublicUrl(path);
  }

  // ── Laporan Kegiatan ─────────────────────────────────────────────────────
  static Future<List<LaporanKegiatan>> getLaporan() async {
    if (!SyncService.isOnline) {
      final cache = await _readCache(_keyLaporan);
      return cache.map(LaporanKegiatan.fromJson).toList();
    }
    try {
      final rows = await _db.from('laporan_kegiatan').select().order('tanggal_kegiatan', ascending: false).timeout(const Duration(seconds: 4));
      final list = (rows as List).map((e) => LaporanKegiatan(
            id: e['id'],
            judul: e['judul'],
            sekbid: e['sekbid'] ?? '',
            penanggungJawab: e['penanggung_jawab'] ?? '',
            tanggalKegiatan: DateTime.parse(e['tanggal_kegiatan']),
            lokasi: e['lokasi'] ?? '',
            deskripsi: e['deskripsi'] ?? '',
            hasilCapaian: e['hasil_capaian'] ?? '',
            kendalaSaran: e['kendala_saran'] ?? '',
            status: e['status'] ?? StatusLaporan.draft,
            tanggalBuat: DateTime.parse(e['tanggal_buat']),
            peserta: (e['peserta'] as List?)?.map((p) => p.toString()).toList() ?? [],
            pembuatId: e['pembuat_id'] ?? '',
          )).toList();
      final cacheData = list.map((l) => l.toJson()).toList();
      await _saveCache(_keyLaporan, cacheData);
      return list;
    } catch (_) {
      final cache = await _readCache(_keyLaporan);
      return cache.map(LaporanKegiatan.fromJson).toList();
    }
  }

  static Future<void> saveLaporan(List<LaporanKegiatan> list) async {
    await _saveCache(_keyLaporan, list.map((e) => e.toJson()).toList());
  }

  static Future<void> addLaporan(LaporanKegiatan l) async {
    final dbData = {
      'id': l.id,
      'judul': l.judul,
      'sekbid': l.sekbid,
      'penanggung_jawab': l.penanggungJawab,
      'tanggal_kegiatan': l.tanggalKegiatan.toIso8601String(),
      'lokasi': l.lokasi,
      'deskripsi': l.deskripsi,
      'hasil_capaian': l.hasilCapaian,
      'kendala_saran': l.kendalaSaran,
      'status': l.status,
      'tanggal_buat': l.tanggalBuat.toIso8601String(),
      'peserta': l.peserta,
      'pembuat_id': l.pembuatId,
    };

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyLaporan);
    cache.add(l.toJson());
    await _saveCache(_keyLaporan, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('laporan_kegiatan').insert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.insert,
          table: 'laporan_kegiatan',
          data: dbData,
          targetId: l.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.insert,
        table: 'laporan_kegiatan',
        data: dbData,
        targetId: l.id,
      );
    }
    await broadcastDataChange('laporan_kegiatan');
  }

  static Future<void> updateLaporan(LaporanKegiatan l) async {
    final dbData = {
      'id': l.id,
      'judul': l.judul,
      'sekbid': l.sekbid,
      'penanggung_jawab': l.penanggungJawab,
      'tanggal_kegiatan': l.tanggalKegiatan.toIso8601String(),
      'lokasi': l.lokasi,
      'deskripsi': l.deskripsi,
      'hasil_capaian': l.hasilCapaian,
      'kendala_saran': l.kendalaSaran,
      'status': l.status,
      'tanggal_buat': l.tanggalBuat.toIso8601String(),
      'peserta': l.peserta,
      'pembuat_id': l.pembuatId,
    };

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyLaporan);
    final index = cache.indexWhere((item) => item['id'] == l.id);
    if (index != -1) {
      cache[index] = l.toJson();
    } else {
      cache.add(l.toJson());
    }
    await _saveCache(_keyLaporan, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('laporan_kegiatan').upsert(dbData);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'laporan_kegiatan',
          data: dbData,
          targetId: l.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'laporan_kegiatan',
        data: dbData,
        targetId: l.id,
      );
    }
    await broadcastDataChange('laporan_kegiatan');
  }

  static Future<void> deleteLaporan(String id) async {
    // 1. Update cache lokal instan
    final cache = await _readCache(_keyLaporan);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyLaporan, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('laporan_kegiatan').delete().eq('id', id);
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'laporan_kegiatan',
          targetId: id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'laporan_kegiatan',
        targetId: id,
      );
    }
    await broadcastDataChange('laporan_kegiatan');
  }

  // ── File Riwayat ─────────────────────────────────────────────────────────
  static Future<List<FileRiwayat>> getFileRiwayat() async {
    try {
      final rows = await _db.from('file_riwayat').select().order('tanggal_upload', ascending: false);
      final list = rows.map((e) => FileRiwayat(
        id: e['id'],
        namaFile: e['nama_file'] ?? '',
        tanggalUpload: DateTime.parse(e['tanggal_upload']),
        nisList: (e['nis_list'] as List?)?.map((n) => n.toString()).toList() ?? [],
      )).toList();
      // Simpan ke cache lokal sebagai fallback
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyFileRiwayat, list.map((e) => jsonEncode(e.toJson())).toList());
      return list;
    } catch (_) {
      // Fallback ke cache lokal
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_keyFileRiwayat) ?? [])
          .map((e) => FileRiwayat.fromJson(Map<String, dynamic>.from(jsonDecode(e))))
          .toList();
    }
  }

  static Future<void> _saveFileRiwayat(FileRiwayat f) async {
    final dbData = {
      'id': f.id,
      'nama_file': f.namaFile,
      'tanggal_upload': f.tanggalUpload.toIso8601String(),
      'nis_list': f.nisList,
    };

    // 1. Update cache lokal instan
    final prefs = await SharedPreferences.getInstance();
    final cached = (prefs.getStringList(_keyFileRiwayat) ?? [])
        .map((e) => FileRiwayat.fromJson(Map<String, dynamic>.from(jsonDecode(e))))
        .where((r) => r.id != f.id)
        .toList()
      ..insert(0, f);
    await prefs.setStringList(_keyFileRiwayat, cached.map((e) => jsonEncode(e.toJson())).toList());

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('file_riwayat').upsert(dbData);
      } catch (_) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'file_riwayat',
          data: dbData,
          targetId: f.id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'file_riwayat',
        data: dbData,
        targetId: f.id,
      );
    }
    await broadcastDataChange('file_riwayat');
  }

  static Future<void> deleteFileRiwayat(String id) async {
    // 1. Update cache lokal instan
    final prefs = await SharedPreferences.getInstance();
    final list = (prefs.getStringList(_keyFileRiwayat) ?? [])
        .map((e) => FileRiwayat.fromJson(Map<String, dynamic>.from(jsonDecode(e))))
        .where((f) => f.id != id)
        .toList();
    await prefs.setStringList(_keyFileRiwayat, list.map((e) => jsonEncode(e.toJson())).toList());

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        await _db.from('file_riwayat').delete().eq('id', id);
      } catch (_) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'file_riwayat',
          targetId: id,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'file_riwayat',
        targetId: id,
      );
    }
    await broadcastDataChange('file_riwayat');
  }

  static String _naikKelas(String kelas) {
    final t = kelas.trim().toUpperCase();
    if (t.startsWith('XII')) return kelas;
    if (t.startsWith('XI')) return 'XII${kelas.substring(2)}';
    if (t.startsWith('X')) return 'XI${kelas.substring(1)}';
    return kelas;
  }

  static String _turunKelas(String kelas) {
    final t = kelas.trim().toUpperCase();
    if (t.startsWith('XII')) return 'XI${kelas.substring(3)}';
    if (t.startsWith('XI')) return 'X${kelas.substring(2)}';
    return kelas;
  }

  static Future<int> naikKelasFromFile(FileRiwayat file) async {
    final siswaList = await getSiswa();
    final targets = siswaList.where((s) => file.nisList.contains(s.nis)).toList();
    for (final s in targets) {
      await updateSiswa(Siswa(id: s.id, nama: s.nama, kelas: _naikKelas(s.kelas), nis: s.nis));
    }
    await broadcastDataChange('siswa');
    return targets.length;
  }

  static Future<int> turunKelasFromFile(FileRiwayat file) async {
    final siswaList = await getSiswa();
    final targets = siswaList.where((s) => file.nisList.contains(s.nis)).toList();
    for (final s in targets) {
      await updateSiswa(Siswa(id: s.id, nama: s.nama, kelas: _turunKelas(s.kelas), nis: s.nis));
    }
    await broadcastDataChange('siswa');
    return targets.length;
  }

  // ── Excel Import / Delete ───────────────────────────────────────────────────

  /// Parse Excel bytes → list of {nama, kelas, nis}
  ///
  /// Mendukung format .xlsx (Excel XML) dan format legacy .xls (BIFF8 OLE Compound):
  /// 1. Format Absen Sekolah (format utama):
  ///    - Baris 0–4 : kosong / header sekolah
  ///    - Baris 5   : header kolom (N0 | NIS | NAMA LENGKAP | JENIS KELAMIN | ...)
  ///    - Baris 6   : sub-header (L | P | angka pertemuan)
  ///    - Baris 7+  : data siswa  [No, NIS, Nama, L/P, ...]
  ///    - Nama kelas diambil dari nama sheet (misal "X PPLG 1", "XI RPL 1")
  ///    - Semua sheet diproses (satu file bisa berisi banyak kelas)
  ///
  /// 2. Format sederhana (fallback):
  ///    - Baris 0 : header dengan kolom Nama / Kelas / NIS
  ///    - Baris 1+: data siswa
  static List<Map<String, String>> _parseExcel(List<int> bytes) {
    final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);

    // Cek magic bytes untuk format legacy .xls (OLE Compound: 0xD0CF11E0)
    if (uint8.length >= 8 &&
        uint8[0] == 0xD0 && uint8[1] == 0xCF &&
        uint8[2] == 0x11 && uint8[3] == 0xE0) {
      try {
        final biffResults = _parseBiff8Excel(uint8);
        if (biffResults.isNotEmpty) return biffResults;
      } catch (e) {
        debugPrint('BIFF8 parse fallback failed: $e');
      }
    }

    final excel = exc.Excel.decodeBytes(bytes);
    final result = <Map<String, String>>[];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null || sheet.maxRows < 2) continue;

      final kelas = sheetName.trim();

      // ── Deteksi format: cek apakah baris 5 mengandung header absen ──
      bool isFormatAbsen = false;
      int headerRow = 0;
      int namaCol = -1, nisCol = -1;

      // Cari header dari baris 0 sampai maksimal baris 8
      final maxSearch = sheet.maxRows < 9 ? sheet.maxRows : 9;
      for (int h = 0; h < maxSearch; h++) {
        final hRow = sheet.rows[h];
        int tempNama = -1, tempNis = -1;
        for (int i = 0; i < hRow.length; i++) {
          final val = hRow[i]?.value?.toString().toLowerCase().trim() ?? '';
          if (val.contains('nama')) tempNama = i;
          if (val.contains('nis'))  tempNis  = i;
        }
        if (tempNama != -1 && tempNis != -1) {
          headerRow = h;
          namaCol   = tempNama;
          nisCol    = tempNis;
          // Jika header ditemukan di baris >= 4, anggap format absen
          isFormatAbsen = h >= 4;
          break;
        }
      }

      if (isFormatAbsen) {
        // Format Absen: data mulai 2 baris setelah header (skip sub-header)
        final dataStart = headerRow + 2;
        for (int r = dataStart; r < sheet.maxRows; r++) {
          final row = sheet.rows[r];
          final nama = (row.length > namaCol ? row[namaCol]?.value?.toString().trim() : null) ?? '';
          if (nama.isEmpty) continue;
          // NIS bisa berupa angka → konversi ke string (hapus .0 dari double)
          final nisRaw = row.length > nisCol ? row[nisCol]?.value : null;
          final nis = _cellValueToNis(nisRaw);
          if (nis.isEmpty) continue;
          result.add({'nama': nama, 'kelas': kelas, 'nis': nis});
        }
      } else if (namaCol != -1 && nisCol != -1) {
        // Format sederhana: cari kolom kelas juga
        int kelasCol = -1;
        final hRow = sheet.rows[headerRow];
        for (int i = 0; i < hRow.length; i++) {
          final val = hRow[i]?.value?.toString().toLowerCase().trim() ?? '';
          if (val.contains('kelas')) kelasCol = i;
        }
        for (int r = headerRow + 1; r < sheet.maxRows; r++) {
          final row = sheet.rows[r];
          final nama = (row.length > namaCol ? row[namaCol]?.value?.toString().trim() : null) ?? '';
          if (nama.isEmpty) continue;
          final nisRaw = row.length > nisCol ? row[nisCol]?.value : null;
          final nis = _cellValueToNis(nisRaw);
          final kelasVal = kelasCol != -1
              ? (row.length > kelasCol ? row[kelasCol]?.value?.toString().trim() : null) ?? kelas
              : kelas;
          if (nis.isEmpty) continue;
          result.add({'nama': nama, 'kelas': kelasVal, 'nis': nis});
        }
      }
    }
    return result;
  }

  // ── Legacy BIFF8 (.xls) Parser Helper Implementation ─────────────────────
  static List<Map<String, String>> _parseBiff8Excel(Uint8List bytes) {
    final results = <Map<String, String>>[];
    if (bytes.length < 512) return results;

    final bd = ByteData.sublistView(bytes);
    final sectorSizePower = bd.getUint16(30, Endian.little);
    final sectorSize = 1 << sectorSizePower;

    final numSatSectors = bd.getUint32(44, Endian.little);
    final sat = <int>[];
    for (int i = 0; i < numSatSectors; i++) {
      final satSecId = bd.getUint32(76 + i * 4, Endian.little);
      final offset = (satSecId + 1) * sectorSize;
      for (int j = 0; j < sectorSize; j += 4) {
        if (offset + j + 4 <= bytes.length) {
          sat.add(bd.getUint32(offset + j, Endian.little));
        }
      }
    }

    final dirFirstSec = bd.getUint32(48, Endian.little);
    final dirBytes = _readBiffStream(bytes, dirFirstSec, sat, sectorSize);

    int workbookFirstSec = -1;
    int workbookSize = 0;
    for (int i = 0; i + 128 <= dirBytes.length; i += 128) {
      final dirBd = ByteData.sublistView(dirBytes);
      final nameLen = dirBd.getUint16(i + 64, Endian.little);
      if (nameLen > 0 && i + nameLen <= dirBytes.length) {
        final nameBytes = dirBytes.sublist(i, i + nameLen - 2);
        final name = String.fromCharCodes(nameBytes.where((b) => b != 0));
        if (name == 'Workbook' || name == 'Book') {
          workbookFirstSec = dirBd.getUint32(i + 116, Endian.little);
          workbookSize = dirBd.getUint32(i + 120, Endian.little);
          break;
        }
      }
    }

    if (workbookFirstSec == -1) return results;

    final wbBytes = _readBiffStream(bytes, workbookFirstSec, sat, sectorSize, maxSize: workbookSize);
    return _parseWorkbookBiff8(wbBytes);
  }

  static Uint8List _readBiffStream(Uint8List fileBytes, int startSec, List<int> sat, int sectorSize, {int? maxSize}) {
    final builder = BytesBuilder();
    int sec = startSec;
    while (sec >= 0 && sec < sat.length && sec != 0xFFFFFFFE && sec != 0xFFFFFFFF) {
      final offset = (sec + 1) * sectorSize;
      if (offset + sectorSize <= fileBytes.length) {
        builder.add(fileBytes.sublist(offset, offset + sectorSize));
      } else {
        break;
      }
      sec = sat[sec];
    }
    final res = builder.toBytes();
    if (maxSize != null && res.length > maxSize) {
      return Uint8List.sublistView(res, 0, maxSize);
    }
    return res;
  }

  static List<Map<String, String>> _parseWorkbookBiff8(Uint8List wb) {
    final results = <Map<String, String>>[];
    final sst = <String>[];
    final sheets = <_BiffSheetInfo>[];

    int pos = 0;
    final bd = ByteData.sublistView(wb);

    while (pos + 4 <= wb.length) {
      final recType = bd.getUint16(pos, Endian.little);
      final recLen = bd.getUint16(pos + 2, Endian.little);
      final dataPos = pos + 4;
      if (dataPos + recLen > wb.length) break;

      if (recType == 0x0085 && recLen >= 8) { // BOUNDSHEET
        final offset = bd.getUint32(dataPos, Endian.little);
        final nameLen = wb[dataPos + 6];
        final isUnicode = (wb[dataPos + 7] & 0x01) != 0;
        String sheetName;
        if (isUnicode && dataPos + 8 + nameLen * 2 <= wb.length) {
          final chars = <int>[];
          for (int k = 0; k < nameLen; k++) {
            chars.add(bd.getUint16(dataPos + 8 + k * 2, Endian.little));
          }
          sheetName = String.fromCharCodes(chars);
        } else if (dataPos + 8 + nameLen <= wb.length) {
          sheetName = String.fromCharCodes(wb.sublist(dataPos + 8, dataPos + 8 + nameLen));
        } else {
          sheetName = 'Sheet';
        }
        sheets.add(_BiffSheetInfo(sheetName.trim(), offset));
      } else if (recType == 0x00FC) { // SST
        _parseSST(wb.sublist(dataPos, dataPos + recLen), sst);
      }

      pos += 4 + recLen;
    }

    for (final sheet in sheets) {
      int sheetPos = sheet.offset;
      final cellMap = <int, Map<int, String>>{};

      while (sheetPos + 4 <= wb.length) {
        final recType = bd.getUint16(sheetPos, Endian.little);
        final recLen = bd.getUint16(sheetPos + 2, Endian.little);
        final dataPos = sheetPos + 4;
        if (dataPos + recLen > wb.length) break;

        if (recType == 0x000A) break;

        if (recType == 0x00FD && recLen >= 10) { // LABELSST
          final r = bd.getUint16(dataPos, Endian.little);
          final c = bd.getUint16(dataPos + 2, Endian.little);
          final sstIdx = bd.getUint32(dataPos + 6, Endian.little);
          if (sstIdx < sst.length) {
            cellMap.putIfAbsent(r, () => {})[c] = sst[sstIdx];
          }
        } else if (recType == 0x0203 && recLen >= 14) { // NUMBER
          final r = bd.getUint16(dataPos, Endian.little);
          final c = bd.getUint16(dataPos + 2, Endian.little);
          final val = bd.getFloat64(dataPos + 6, Endian.little);
          final valStr = val == val.toInt() ? val.toInt().toString() : val.toString();
          cellMap.putIfAbsent(r, () => {})[c] = valStr;
        } else if (recType == 0x027E && recLen >= 10) { // RK
          final r = bd.getUint16(dataPos, Endian.little);
          final c = bd.getUint16(dataPos + 2, Endian.little);
          final rkVal = bd.getUint32(dataPos + 6, Endian.little);
          cellMap.putIfAbsent(r, () => {})[c] = _decodeRK(rkVal);
        }

        sheetPos += 4 + recLen;
      }

      _extractStudentsFromBiffSheet(sheet.name, cellMap, results);
    }

    return results;
  }

  static String _decodeRK(int rk) {
    bool isFloat = (rk & 2) == 0;
    bool isDiv100 = (rk & 1) != 0;
    double raw;
    if (isFloat) {
      final bd = ByteData(8);
      bd.setUint32(4, rk & 0xFFFFFFFC, Endian.little);
      raw = bd.getFloat64(0, Endian.little);
    } else {
      int intVal = (rk >> 2);
      if ((rk & 0x80000000) != 0) {
        intVal = intVal - 0x40000000;
      }
      raw = intVal.toDouble();
    }
    if (isDiv100) raw /= 100.0;
    return raw == raw.toInt() ? raw.toInt().toString() : raw.toString();
  }

  static void _parseSST(Uint8List data, List<String> sst) {
    if (data.length < 8) return;
    final bd = ByteData.sublistView(data);
    final numStrings = bd.getUint32(4, Endian.little);
    int pos = 8;

    for (int i = 0; i < numStrings && pos < data.length; i++) {
      if (pos + 3 > data.length) break;
      final charCount = bd.getUint16(pos, Endian.little);
      final flags = data[pos + 2];
      final isUnicode = (flags & 0x01) != 0;
      final hasRichText = (flags & 0x08) != 0;
      final hasPhonetic = (flags & 0x04) != 0;
      pos += 3;

      int runCount = 0;
      if (hasRichText && pos + 2 <= data.length) {
        runCount = bd.getUint16(pos, Endian.little);
        pos += 2;
      }
      int cbExtRst = 0;
      if (hasPhonetic && pos + 4 <= data.length) {
        cbExtRst = bd.getUint32(pos, Endian.little);
        pos += 4;
      }

      String str = '';
      if (isUnicode) {
        final len = charCount * 2;
        if (pos + len <= data.length) {
          final chars = <int>[];
          for (int k = 0; k < charCount; k++) {
            chars.add(bd.getUint16(pos + k * 2, Endian.little));
          }
          str = String.fromCharCodes(chars);
          pos += len;
        }
      } else {
        if (pos + charCount <= data.length) {
          str = String.fromCharCodes(data.sublist(pos, pos + charCount));
          pos += charCount;
        }
      }
      pos += runCount * 4 + cbExtRst;
      sst.add(str.trim());
    }
  }

  static void _extractStudentsFromBiffSheet(String sheetName, Map<int, Map<int, String>> cellMap, List<Map<String, String>> results) {
    int headerRow = -1;
    int namaCol = -1;
    int nisCol = -1;

    for (final entry in cellMap.entries) {
      final r = entry.key;
      final row = entry.value;
      for (final colEntry in row.entries) {
        final val = colEntry.value.toLowerCase().trim();
        if (val.contains('nama')) namaCol = colEntry.key;
        // Use exact match for NIS to avoid false positives like 'jenis kelamin'
        if (val == 'nis') nisCol = colEntry.key;
      }
      if (namaCol != -1 && nisCol != -1) {
        headerRow = r;
        break;
      }
    }

    if (headerRow == -1 || namaCol == -1 || nisCol == -1) return;

    for (final entry in cellMap.entries) {
      final r = entry.key;
      if (r <= headerRow) continue;
      final row = entry.value;
      final nama = row[namaCol]?.trim() ?? '';
      final nisRaw = row[nisCol]?.trim() ?? '';
      
      if (nama.isEmpty || nisRaw.isEmpty) continue;
      if (nama.toLowerCase().contains('nama') || nama.toLowerCase().contains('pertemuan')) continue;

      String nis = nisRaw;
      if (nis.endsWith('.0')) nis = nis.substring(0, nis.length - 2);

      results.add({
        'nama': nama,
        'kelas': sheetName,
        'nis': nis,
      });
    }
  }

  /// Konversi [CellValue] dari package excel ke string NIS.
  /// NIS numerik seperti 2627020070001.0 → "2627020070001"
  static String _cellValueToNis(Object? val) {
    if (val == null) return '';
    final s = val.toString().trim();
    // Hapus suffix ".0" yang muncul saat nilai numerik
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  /// Import siswa dari Excel → upsert ke Supabase berdasarkan NIS
  static Future<int> importStudentsFromExcel(List<int> bytes, {String namaFile = 'file.xlsx'}) async {
    final rows = _parseExcel(bytes);
    if (rows.isEmpty) {
      throw Exception(
        'File kosong atau format tidak dikenali.\n'
        'Gunakan format Excel absen sekolah:\n'
        '• Setiap sheet = satu kelas (nama sheet = nama kelas)\n'
        '• Baris ke-6: header (N0 | NIS | NAMA LENGKAP | ...)\n'
        '• Baris ke-7: sub-header (L | P | angka)\n'
        '• Baris ke-8+: data siswa\n'
        'Atau format sederhana dengan kolom Nama, Kelas, NIS.'
      );
    }

    final toUpsert = rows.map((row) => {
      'id': _uuid.v4(),
      'nama': row['nama']!,
      'kelas': row['kelas']!,
      'nis': row['nis']!,
    }).toList();

    // 1. Simpan selalu ke Cache Lokal instan
    final cache = await _readCache(_keySiswa);
    for (final item in toUpsert) {
      final idx = cache.indexWhere((c) => c['nis'] == item['nis']);
      if (idx != -1) {
        cache[idx] = item;
      } else {
        cache.add(item);
      }
    }
    await _saveCache(_keySiswa, cache);

    // 2. Upsert ke Supabase per batch 50 (jika online) atau enqueue (jika offline)
    const batchSize = 50;
    if (SyncService.isOnline) {
      try {
        for (int i = 0; i < toUpsert.length; i += batchSize) {
          final end = (i + batchSize).clamp(0, toUpsert.length);
          await _db.from('siswa').upsert(
            toUpsert.sublist(i, end),
            onConflict: 'nis',
            ignoreDuplicates: true,
          );
        }
      } catch (e) {
        for (final item in toUpsert) {
          await SyncService.enqueueAction(
            actionType: SyncActionType.upsert,
            table: 'siswa',
            data: item,
            targetId: item['id']?.toString(),
          );
        }
      }
    } else {
      for (final item in toUpsert) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'siswa',
          data: item,
          targetId: item['id']?.toString(),
        );
      }
    }

    // Simpan riwayat file
    final nisList = rows.map((r) => r['nis']!).where((n) => n.isNotEmpty).toList();
    final riwayat = await getFileRiwayat();
    final existing = riwayat.firstWhere((f) => f.namaFile == namaFile,
        orElse: () => FileRiwayat(id: _uuid.v4(), namaFile: namaFile, tanggalUpload: DateTime.now(), nisList: []));
    // Hapus yang lama dulu jika ada
    if (riwayat.any((f) => f.namaFile == namaFile)) {
      await deleteFileRiwayat(existing.id);
    }
    final newRiwayat = FileRiwayat(
      id: _uuid.v4(),
      namaFile: namaFile,
      tanggalUpload: DateTime.now(),
      nisList: nisList,
    );
    await _saveFileRiwayat(newRiwayat);
    await broadcastDataChange('siswa');

    return toUpsert.length;
  }

  /// Hapus siswa berdasarkan NIS yang ada di file Excel
  static Future<int> deleteStudentsFromExcel(List<int> bytes) async {
    final rows = _parseExcel(bytes);
    if (rows.isEmpty) throw Exception('File kosong atau format tidak dikenali.');

    final nisList = rows.map((r) => r['nis']!).where((n) => n.isNotEmpty).toList();
    if (nisList.isEmpty) throw Exception('Tidak ada kolom NIS di file.');

    // Cari id siswa yang NIS-nya ada di file
    final existing = await getSiswa();
    final toDelete = existing.where((s) => nisList.contains(s.nis)).toList();
    if (toDelete.isEmpty) return 0;

    for (final s in toDelete) {
      await _db.from('siswa').delete().eq('id', s.id);
    }
    await broadcastDataChange('siswa');
    return toDelete.length;
  }

  // ── Batch Operations ─────────────────────────────────────────────────────
  static Future<void> syncPendingChanges() async {
    try {
      // 1. Flush semua antrean lokal keluar ke Supabase terlebih dahulu
      await SyncService.flushQueue();

      // 2. Tarik data terbaru dari Supabase ke cache lokal
      await getSiswa();
      await getJenis();
      await getPelanggaran();
      await getProker();
      await getArsip();
      await getLaporan();
      await getFileRiwayat();
    } catch (e) {
      debugPrint('sync error: $e');
    }
  }

  static Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySiswa);
    await prefs.remove(_keyJenis);
    await prefs.remove(_keyPelanggaran);
    await prefs.remove(_keyProker);
    await prefs.remove(_keyArsip);
    await prefs.remove(_keyLaporan);
    await prefs.remove(_keyFileRiwayat);
  }

  static Future<bool> checkConnection() async {
    return await SyncService.checkConnection();
  }
}

class _BiffSheetInfo {
  final String name;
  final int offset;
  _BiffSheetInfo(this.name, this.offset);
}

