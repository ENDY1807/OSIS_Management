import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as exc;
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'sync_service.dart';
import 'app_settings_service.dart';
import 'baknus_drive_service.dart';
import 'bundled_students.dart';

const _uuid = Uuid();

class DataService {
  static const _supabaseUrl = 'https://vvvrzxaxnumtstlgovqw.supabase.co';
  static const _supabaseKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2dnJ6eGF4bnVtdHN0bGdvdnF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI2MzMxOTksImV4cCI6MjA5ODIwOTE5OX0.XHGfzuADTS9BCILR6FAm0RIOxpslwX6DJkABYaan1Eo';

  static const _keyFileRiwayat = 'file_riwayat';

  // Cache keys (fallback offline)
  static const _keySiswa = 'siswa';
  static const _keyJenis = 'jenis_pelanggaran';
  static const _keyPelanggaran = 'pelanggaran';
  static const _keyKebaikan = 'kebaikan';
  static const _keyProker = 'proker';
  static const _keyArsip = 'arsip';
  static const _keyArsipFolder = 'arsip_folder';
  static const _keyLaporan = 'laporan_kegiatan_v2';
  static const _keySekbid = 'sekbid';
  static const _keyKasOsis = 'kas_osis_sessions_v2';
  static const _keyKasTransaksi = 'kas_osis_transaksi_v2';
  static const _keyAbsensiOsis = 'absensi_osis_sessions_v2';
  static const _keyAnggotaOsis = 'anggota_osis_v2';
  static const _keyProfilOsis = 'profil_osis_v1';
  static const _keyInventarisOsis = 'inventaris_osis_v1';
  static const _keyAgendaOsis = 'agenda_osis_v1';
  static const _keyPengumumanOsis = 'pengumuman_osis_v1';
  static const _keyDokumentasiKegiatan = 'dokumentasi_kegiatan_v1';
  static const _keyEvaluasiProker = 'evaluasi_proker_v1';
  static const _keyAktivitasPengguna = 'aktivitas_pengguna_v1';
  static final String _localClientId = const Uuid().v4();

  static final StreamController<String> _dataChangeController =
      StreamController<String>.broadcast();
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
          debugPrint(
              'Realtime broadcast data changed from remote device: $table');
          if (table == 'accounts' || table == 'all') {
            AuthService.syncWithSupabase();
          }
          if (table == 'app_settings' || table == 'sekbid' || table == 'all') {
            if (payload['primary_color'] != null) {
              final colorStr = payload['primary_color'].toString();
              try {
                final parsedInt = int.parse(
                    colorStr.replaceFirst('#', '').replaceFirst('0x', ''),
                    radix: 16);
                final fullColor = (parsedInt <= 0xFFFFFF)
                    ? 0xFF000000 | parsedInt
                    : parsedInt;
                AppSettingsService.accentColorNotifier.value = Color(fullColor);
                SharedPreferences.getInstance()
                    .then((p) => p.setInt('app_accent_color', fullColor));
              } catch (_) {}
            }
            if (payload['app_name'] != null) {
              AppSettingsService.appNameNotifier.value =
                  payload['app_name'].toString();
            }
            if (payload['app_subtitle'] != null) {
              AppSettingsService.appSubtitleNotifier.value =
                  payload['app_subtitle'].toString();
            }
            if (payload['logo_url'] != null) {
              AppSettingsService.logoUrlNotifier.value =
                  payload['logo_url'].toString();
            }
            if (payload['custom_fields'] != null) {
              try {
                dynamic raw = payload['custom_fields'];
                if (raw is String) raw = jsonDecode(raw);
                if (raw is Map) {
                  final Map<String, List<AppCustomInputField>> map = {};
                  raw.forEach((key, val) {
                    if (val is List) {
                      map[key.toString()] = val
                          .map((e) => AppCustomInputField.fromJson(
                              Map<String, dynamic>.from(e as Map)))
                          .toList();
                    }
                  });
                  if (map.isNotEmpty) {
                    AppSettingsService.customFieldsNotifier.value = map;
                    SharedPreferences.getInstance().then((p) => p.setString(
                        'cfg_dynamic_custom_fields', jsonEncode(raw)));
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
        'kas_osis',
        'absensi_osis',
        'kas_transaksi',
        'anggota_osis',
        'profil_osis',
        'inventaris_osis',
        'agenda_osis',
        'pengumuman_osis',
        'dokumentasi_kegiatan',
        'evaluasi_proker',
        'aktivitas_pengguna',
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
                    final parsedInt = int.parse(
                        colorStr.replaceFirst('#', '').replaceFirst('0x', ''),
                        radix: 16);
                    final fullColor = (parsedInt <= 0xFFFFFF)
                        ? 0xFF000000 | parsedInt
                        : parsedInt;
                    AppSettingsService.accentColorNotifier.value =
                        Color(fullColor);
                    SharedPreferences.getInstance()
                        .then((p) => p.setInt('app_accent_color', fullColor));
                  } catch (_) {}
                }
                if (newRec['app_name'] != null) {
                  AppSettingsService.appNameNotifier.value =
                      newRec['app_name'].toString();
                }
                if (newRec['app_subtitle'] != null) {
                  AppSettingsService.appSubtitleNotifier.value =
                      newRec['app_subtitle'].toString();
                }
                if (newRec['logo_url'] != null) {
                  AppSettingsService.logoUrlNotifier.value =
                      newRec['logo_url'].toString();
                }
                if (newRec['custom_fields'] != null) {
                  try {
                    dynamic raw = newRec['custom_fields'];
                    if (raw is String) raw = jsonDecode(raw);
                    if (raw is Map) {
                      final Map<String, List<AppCustomInputField>> map = {};
                      raw.forEach((key, val) {
                        if (val is List) {
                          map[key.toString()] = val
                              .map((e) => AppCustomInputField.fromJson(
                                  Map<String, dynamic>.from(e as Map)))
                              .toList();
                        }
                      });
                      if (map.isNotEmpty) {
                        AppSettingsService.customFieldsNotifier.value = map;
                        SharedPreferences.getInstance().then((p) => p.setString(
                            'cfg_dynamic_custom_fields', jsonEncode(raw)));
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

  static List<SekbidItem> defaultSekbidItems() => [
    SekbidItem(id: 'SEKBID1', name: 'SEKBID 1', deskripsi: 'Keimanan & Ketakwaan', urutan: 1),
    SekbidItem(id: 'SEKBID2', name: 'SEKBID 2', deskripsi: 'Budi Pekerti & Karakter', urutan: 2),
    SekbidItem(id: 'SEKBID3', name: 'SEKBID 3', deskripsi: 'Bela Negara & Kepemimpinan', urutan: 3),
    SekbidItem(id: 'SEKBID4', name: 'SEKBID 4', deskripsi: 'Prestasi Akademik & IPTEK', urutan: 4),
    SekbidItem(id: 'SEKBID5', name: 'SEKBID 5', deskripsi: 'Demokrasi & Pendidikan Politik', urutan: 5),
    SekbidItem(id: 'SEKBID6', name: 'SEKBID 6', deskripsi: 'Keterampilan & Kewirausahaan', urutan: 6),
    SekbidItem(id: 'SEKBID7', name: 'SEKBID 7', deskripsi: 'Kebugaran Jasmani & Olahraga', urutan: 7),
    SekbidItem(id: 'SEKBID8', name: 'SEKBID 8', deskripsi: 'Sastra & Seni Budaya', urutan: 8),
    SekbidItem(id: 'SEKBID9', name: 'SEKBID 9', deskripsi: 'Teknologi Informasi & Multimedia', urutan: 9),
    SekbidItem(id: 'SEKBID10', name: 'SEKBID 10', deskripsi: 'Komunikasi Bahasa & Hubungan Masyarakat', urutan: 10),
  ];

  static Future<List<SekbidItem>> getSekbidTable() async {
    // 1. Ambil dari Supabase
    try {
      final rows = await _db
          .from('sekbid')
          .select()
          .order('urutan', ascending: true)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => SekbidItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keySekbid, list.map((e) => e.toJson()).toList());
      AppSettingsService.sekbidListNotifier.value = list.map((s) => s.id).toList();
      return list;
    } catch (_) {
      // 2. Fallback baca dari cache lokal
      final cache = await _readCache(_keySekbid);
      final list = cache.map((e) => SekbidItem.fromJson(e)).toList();
      list.sort((a, b) => a.urutan.compareTo(b.urutan));
      AppSettingsService.sekbidListNotifier.value = list.map((s) => s.id).toList();
      return list;
    }
  }

  static Future<void> saveSekbidItem(SekbidItem item) async {
    final list = await getSekbidTable();
    final idx = list.indexWhere((s) => s.id.toUpperCase() == item.id.toUpperCase());
    if (idx != -1) {
      list[idx] = item;
    } else {
      list.add(item);
    }
    list.sort((a, b) => a.urutan.compareTo(b.urutan));

    await _saveCache(_keySekbid, list.map((e) => e.toJson()).toList());
    final strList = list.map((e) => e.id).toList();
    AppSettingsService.sekbidListNotifier.value = strList;
    await AppSettingsService.saveAdminConfigs(sekbidList: strList);

    try {
      await _db.from('sekbid').upsert(item.toJson());
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('sekbid', item.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'sekbid',
        data: item.toJson(),
        targetId: item.id,
      );
    }
    await broadcastDataChange('sekbid');
  }

  static Future<void> deleteSekbidItem(String id) async {
    final list = await getSekbidTable();
    list.removeWhere((s) => s.id.toUpperCase() == id.toUpperCase());

    await _saveCache(_keySekbid, list.map((e) => e.toJson()).toList());
    final strList = list.map((e) => e.id).toList();
    AppSettingsService.sekbidListNotifier.value = strList;
    await AppSettingsService.saveAdminConfigs(sekbidList: strList);

    try {
      await _db.from('sekbid').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('sekbid', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'sekbid',
        targetId: id,
      );
    }
    await broadcastDataChange('sekbid');
  }

  static Future<List<String>> getSekbidList() async {
    if (AppSettingsService.sekbidListNotifier.value.isNotEmpty) {
      return AppSettingsService.sekbidListNotifier.value;
    }
    final items = await getSekbidTable();
    return items.map((e) => e.id).toList();
  }

  static Future<void> saveSekbidList(List<String> sekbids) async {
    AppSettingsService.sekbidListNotifier.value = List.from(sekbids);
    final items = <SekbidItem>[];
    for (int i = 0; i < sekbids.length; i++) {
      items.add(SekbidItem(
        id: sekbids[i],
        name: sekbids[i],
        deskripsi: AuthService.getDisplayName(sekbids[i]),
        urutan: i + 1,
      ));
    }
    await _saveCache(_keySekbid, items.map((s) => s.toJson()).toList());
    await AppSettingsService.saveAdminConfigs(sekbidList: sekbids);
    try {
      for (final item in items) {
        await _db.from('sekbid').upsert(item.toJson(), onConflict: 'id');
      }
      SyncService.setOnlineManually();
      await broadcastDataChange('sekbid');
    } catch (_) {}
  }

  static Future<void> broadcastDataChange(String table,
      [Map<String, dynamic>? extra]) async {
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
    final hasClearedMock = prefs.getBool('has_cleared_mock_seeds_v2') ?? false;
    if (!hasClearedMock) {
      await clearMockSeedCache();
      await prefs.setBool('has_cleared_mock_seeds_v2', true);
    }
  }

  static Future<void> clearMockSeedCache() async {
    try {
      final inv = await _readCache(_keyInventarisOsis);
      inv.removeWhere((e) => e['id']?.toString().startsWith('inv-') == true);
      await _saveCache(_keyInventarisOsis, inv);

      final agd = await _readCache(_keyAgendaOsis);
      agd.removeWhere((e) => e['id']?.toString().startsWith('agd-') == true);
      await _saveCache(_keyAgendaOsis, agd);

      final peng = await _readCache(_keyPengumumanOsis);
      peng.removeWhere((e) => e['id']?.toString().startsWith('peng-') == true);
      await _saveCache(_keyPengumumanOsis, peng);

      final dok = await _readCache(_keyDokumentasiKegiatan);
      dok.removeWhere((e) => e['id']?.toString().startsWith('dok-') == true);
      await _saveCache(_keyDokumentasiKegiatan, dok);

      final evl = await _readCache(_keyEvaluasiProker);
      evl.removeWhere((e) => e['id']?.toString().startsWith('evl-') == true);
      await _saveCache(_keyEvaluasiProker, evl);

      final ang = await _readCache(_keyAnggotaOsis);
      ang.removeWhere((e) => e['id']?.toString().startsWith('ang-') == true);
      await _saveCache(_keyAnggotaOsis, ang);
    } catch (_) {}
  }

  // ── helpers cache ────────────────────────────────────────────────────────
  static Future<void> _saveCache(
      String key, List<Map<String, dynamic>> list) async {
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
      return list
          .map((e) {
            try {
              return Map<String, dynamic>.from(jsonDecode(e) as Map);
            } catch (_) {
              return <String, dynamic>{};
            }
          })
          .where((m) => m.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Error reading cache for $key: $e');
      return [];
    }
  }

  // ── Siswa ────────────────────────────────────────────────────────────────
  static Future<List<Siswa>> getSiswa() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasInitialized = prefs.getBool('has_initialized_siswa') ?? false;

    // 1. Tarik pembaruan dari Supabase
    try {
      final rows = await _db
          .from('siswa')
          .select()
          .order('nama')
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => Siswa.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keySiswa, list.map((e) => e.toJson()).toList());
      await prefs.setBool('has_initialized_siswa', true);
      SyncService.setOnlineManually();
      return list;
    } catch (e) {
      debugPrint('Supabase getSiswa fallback ke cache lokal: $e');
    }

    // 2. Ambil dari cache lokal
    List<Map<String, dynamic>> cache = await _readCache(_keySiswa);

    // 3. Hanya isi dengan dataset awal sekali saat aplikasi pertama kali diinstall jika belum pernah ada inisialisasi
    if (!hasInitialized && cache.isEmpty) {
      cache = List<Map<String, dynamic>>.from(bundledStudentsSeed);
      await _saveCache(_keySiswa, cache);
      await prefs.setBool('has_initialized_siswa', true);
    }

    return cache.map(Siswa.fromJson).toList();
  }

  static Future<void> saveSiswa(List<Siswa> list) async {
    await _saveCache(_keySiswa, list.map((e) => e.toJson()).toList());
  }

  static Future<Siswa> addSiswa(String nama, String kelas, String nis) async {
    final s = Siswa(id: _uuid.v4(), nama: nama, kelas: kelas, nis: nis);
    final cache = await _readCache(_keySiswa);
    cache.add(s.toJson());
    await _saveCache(_keySiswa, cache);

    try {
      await _db.from('siswa').insert(s.toJson());
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('siswa', s.id));
    } catch (e) {
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
    final cache = await _readCache(_keySiswa);
    final index = cache.indexWhere((item) => item['id'] == s.id);
    if (index != -1) {
      cache[index] = s.toJson();
    } else {
      cache.add(s.toJson());
    }
    await _saveCache(_keySiswa, cache);

    try {
      await _db.from('siswa').upsert(s.toJson());
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('siswa', s.id));
    } catch (e) {
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
    final cache = await _readCache(_keySiswa);
    final toDelete = cache
        .where((item) => nisList.contains(item['nis']))
        .map((e) => e['id']?.toString())
        .whereType<String>()
        .toList();
    cache.removeWhere((item) => nisList.contains(item['nis']));
    await _saveCache(_keySiswa, cache);

    try {
      await _db.from('siswa').delete().inFilter('nis', nisList);
      SyncService.setOnlineManually();
      for (final id in toDelete) {
        unawaited(SyncService.removeAction('siswa', id));
      }
    } catch (e) {
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
    final cache = await _readCache(_keySiswa);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keySiswa, cache);

    try {
      await _db.from('siswa').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('siswa', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'siswa',
        targetId: id,
      );
    }
    await broadcastDataChange('siswa');
  }

  // ── Jenis Pelanggaran ────────────────────────────────────────────────────
  static List<JenisPelanggaran> _deduplicateJenis(List<JenisPelanggaran> list) {
    final seenNames = <String>{};
    final seenIds = <String>{};
    final result = <JenisPelanggaran>[];

    for (final j in list) {
      final cleanName = j.nama.trim().toLowerCase();
      final cleanId = j.id.trim();
      if (cleanName.isEmpty) continue;
      if (seenNames.contains(cleanName) || (cleanId.isNotEmpty && seenIds.contains(cleanId))) {
        continue;
      }
      seenNames.add(cleanName);
      if (cleanId.isNotEmpty) seenIds.add(cleanId);
      result.add(j);
    }
    return result;
  }

  static Future<List<JenisPelanggaran>> getJenis() async {
    try {
      final rows = await _db
          .from('jenis_pelanggaran')
          .select()
          .timeout(const Duration(seconds: 4));
      final rawList = (rows as List)
          .map((e) =>
              JenisPelanggaran.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final list = _deduplicateJenis(rawList);
      await _saveCache(_keyJenis, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      return list;
    } catch (_) {
      final cache = await _readCache(_keyJenis);
      final parsed = cache.map(JenisPelanggaran.fromJson).toList();
      return _deduplicateJenis(parsed);
    }
  }

  static List<JenisPelanggaran> defaultJenis() => [
        // Senin saja
        JenisPelanggaran(
            id: 'jp_dasi', nama: 'Tidak pakai Dasi', hariAktif: [1]),
        JenisPelanggaran(
            id: 'jp_rompi', nama: 'Tidak pakai Rompi', hariAktif: [1]),
        JenisPelanggaran(
            id: 'jp_pin_bncc', nama: 'Tidak pakai Pin BNCC', hariAktif: [1]),
        // Selasa saja
        JenisPelanggaran(
            id: 'jp_kacu', nama: 'Tidak pakai Kacu', hariAktif: [2]),
        // Senin–Jumat
        JenisPelanggaran(
            id: 'jp_sabuk',
            nama: 'Tidak pakai Sabuk',
            hariAktif: [1, 2, 3, 4, 5]),
        JenisPelanggaran(
            id: 'jp_kaos_kaki',
            nama: 'Kaos kaki tidak sesuai',
            hariAktif: [1, 2, 3, 4, 5]),
        JenisPelanggaran(
            id: 'jp_id_card',
            nama: 'Tidak pakai ID Card',
            hariAktif: [1, 2, 3, 4, 5]),
        JenisPelanggaran(
            id: 'jp_sepatu_sesuai',
            nama: 'Sepatu tidak sesuai',
            hariAktif: [1, 2, 3, 4, 5]),
        JenisPelanggaran(
            id: 'jp_tanpa_sepatu',
            nama: 'Tidak pakai Sepatu',
            hariAktif: [1, 2, 3, 4, 5]),
      ];

  static Future<void> saveJenis(List<JenisPelanggaran> list) async {
    final clean = _deduplicateJenis(list);
    await _saveCache(_keyJenis, clean.map((e) => e.toJson()).toList());
  }

  static Future<int> cleanupDuplicateJenis() async {
    try {
      final cache = await _readCache(_keyJenis);
      final seen = <String, String>{};
      final duplicateIds = <String>[];

      for (final item in cache) {
        final name = (item['nama']?.toString() ?? '').trim().toLowerCase();
        final id = (item['id']?.toString() ?? '').trim();
        if (name.isEmpty || id.isEmpty) continue;
        if (seen.containsKey(name)) {
          duplicateIds.add(id);
        } else {
          seen[name] = id;
        }
      }

      for (final dupId in duplicateIds) {
        await deleteJenis(dupId);
      }
      return duplicateIds.length;
    } catch (e) {
      debugPrint('cleanupDuplicateJenis error: $e');
      return 0;
    }
  }

  static Future<JenisPelanggaran> addJenis(String nama,
      {List<int> hariAktif = const []}) async {
    final j =
        JenisPelanggaran(id: _uuid.v4(), nama: nama.trim(), hariAktif: hariAktif);
    final dbData = {'id': j.id, 'nama': j.nama, 'hari_aktif': j.hariAktif};

    final cache = await _readCache(_keyJenis);
    cache.add(j.toJson());
    await _saveCache(_keyJenis, cache);

    try {
      await _db.from('jenis_pelanggaran').insert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('jenis_pelanggaran', j.id));
    } catch (e) {
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

    final cache = await _readCache(_keyJenis);
    final index = cache.indexWhere((item) => item['id'] == j.id);
    if (index != -1) {
      cache[index] = j.toJson();
    } else {
      cache.add(j.toJson());
    }
    await _saveCache(_keyJenis, cache);

    try {
      await _db.from('jenis_pelanggaran').upsert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('jenis_pelanggaran', j.id));
    } catch (e) {
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
    final cache = await _readCache(_keyJenis);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyJenis, cache);

    try {
      await _db.from('jenis_pelanggaran').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('jenis_pelanggaran', id));
    } catch (e) {
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

    // 2. Jika online, ambil dari Supabase dengan timeout
    try {
      final rows = await _db
          .from('pelanggaran')
          .select()
          .order('tanggal', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => Pelanggaran(
                id: e['id'],
                siswaId: e['siswa_id'] ?? '',
                jenisId: e['jenis_id'] ?? '',
                tanggal: DateTime.parse(e['tanggal']),
                keterangan: e['keterangan'] ?? '',
                namaSiswa: e['nama_siswa'] ?? e['siswa_nama'],
                kelasSiswa: e['kelas_siswa'] ?? e['siswa_kelas'],
                nisSiswa: e['nis_siswa'] ?? e['siswa_nis'],
              ))
          .toList();

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

    try {
      await _db.from('pelanggaran').insert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('pelanggaran', pelanggaran.id));
    } catch (e) {
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
    final cache = await _readCache(_keyPelanggaran);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyPelanggaran, cache);

    try {
      await _db.from('pelanggaran').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('pelanggaran', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'pelanggaran',
        targetId: id,
      );
    }
    await broadcastDataChange('pelanggaran');
  }

  // ── Kebaikan (Catatan Kebaikan & Prestasi Siswa) ─────────────────────────
  static Future<List<CatatanKebaikan>> getKebaikan() async {
    try {
      final rows = await _db
          .from('kebaikan')
          .select()
          .order('tanggal', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => CatatanKebaikan.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final cacheData = list.map((k) => k.toJson()).toList();
      await _saveCache(_keyKebaikan, cacheData);
      return list;
    } catch (_) {
      final cache = await _readCache(_keyKebaikan);
      return cache.map(CatatanKebaikan.fromJson).toList();
    }
  }

  static Future<void> addKebaikan(CatatanKebaikan k) async {
    final dbData = {
      'id': k.id,
      'siswa_id': k.siswaId,
      'judul': k.judul,
      'kategori': k.kategori,
      'poin': k.poin,
      'tanggal': k.tanggal.toIso8601String(),
      'keterangan': k.keterangan,
      'nama_siswa': k.namaSiswa ?? '',
      'kelas_siswa': k.kelasSiswa ?? '',
      'nis_siswa': k.nisSiswa ?? '',
      'petugas': k.petugas,
      'apresiasi': k.apresiasi,
    };

    // 1. Update cache lokal instan
    final cache = await _readCache(_keyKebaikan);
    cache.removeWhere((item) => item['id'] == k.id);
    cache.insert(0, k.toJson());
    await _saveCache(_keyKebaikan, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    try {
      await _db.from('kebaikan').insert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('kebaikan', k.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.insert,
        table: 'kebaikan',
        data: dbData,
        targetId: k.id,
      );
    }
    await broadcastDataChange('kebaikan');
  }

  static Future<void> updateKebaikan(CatatanKebaikan k) async {
    final dbData = {
      'id': k.id,
      'siswa_id': k.siswaId,
      'judul': k.judul,
      'kategori': k.kategori,
      'poin': k.poin,
      'tanggal': k.tanggal.toIso8601String(),
      'keterangan': k.keterangan,
      'nama_siswa': k.namaSiswa ?? '',
      'kelas_siswa': k.kelasSiswa ?? '',
      'nis_siswa': k.nisSiswa ?? '',
      'petugas': k.petugas,
      'apresiasi': k.apresiasi,
    };

    final cache = await _readCache(_keyKebaikan);
    final idx = cache.indexWhere((item) => item['id'] == k.id);
    if (idx != -1) {
      cache[idx] = k.toJson();
    } else {
      cache.insert(0, k.toJson());
    }
    await _saveCache(_keyKebaikan, cache);

    try {
      await _db.from('kebaikan').upsert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('kebaikan', k.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'kebaikan',
        data: dbData,
        targetId: k.id,
      );
    }
    await broadcastDataChange('kebaikan');
  }

  static Future<void> deleteKebaikan(String id) async {
    final cache = await _readCache(_keyKebaikan);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyKebaikan, cache);

    try {
      await _db.from('kebaikan').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('kebaikan', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'kebaikan',
        targetId: id,
      );
    }
    await broadcastDataChange('kebaikan');
  }

  // ── Proker ───────────────────────────────────────────────────────────────
  static Future<List<Proker>> getProker() async {
    try {
      final rows = await _db
          .from('proker')
          .select()
          .order('tanggal_rencana')
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => Proker(
                id: e['id'],
                nama: e['nama'],
                deskripsi: e['deskripsi'] ?? '',
                sekbid: e['sekbid'] ?? '',
                penanggungJawab: e['penanggung_jawab'] ?? '',
                tanggalRencana: DateTime.parse(e['tanggal_rencana']),
                tanggalRealisasi: e['tanggal_realisasi'] != null
                    ? DateTime.parse(e['tanggal_realisasi'])
                    : null,
                status: e['status'] ?? StatusProker.belum,
                keterangan: e['keterangan'] ?? '',
                disahkanKepsek: e['disahkan_kepsek'] == true || e['disahkan_kepsek'] == 1,
                catatanKepsek: e['catatan_kepsek']?.toString() ?? '',
              ))
          .toList();
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
      'disahkan_kepsek': p.disahkanKepsek,
      'catatan_kepsek': p.catatanKepsek,
    };

    // 1. Update cache lokal instan (deduplikasi ID)
    final cache = await _readCache(_keyProker);
    cache.removeWhere((item) => item['id'] == p.id);
    cache.add(p.toJson());
    await _saveCache(_keyProker, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    try {
      await _db.from('proker').insert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('proker', p.id));
    } catch (e) {
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
      'disahkan_kepsek': p.disahkanKepsek,
      'catatan_kepsek': p.catatanKepsek,
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
    try {
      await _db.from('proker').upsert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('proker', p.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'proker',
        data: dbData,
        targetId: p.id,
      );
    }
    await broadcastDataChange('proker');
  }

  /// Pengesahan Program Kerja oleh Kepala Sekolah
  static Future<void> setApprovalProkerKepsek(
    String prokerId, {
    required bool disahkan,
    String catatan = '',
  }) async {
    final prokers = await getProker();
    final idx = prokers.indexWhere((p) => p.id == prokerId);
    if (idx != -1) {
      final p = prokers[idx];
      p.disahkanKepsek = disahkan;
      p.catatanKepsek = catatan;
      await updateProker(p);
    }
  }

  static Future<void> deleteProker(String id) async {
    // 1. Update cache lokal instan
    final cache = await _readCache(_keyProker);
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyProker, cache);

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    try {
      await _db.from('proker').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('proker', id));
    } catch (e) {
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
    try {
      final rows = await _db
          .from('arsip')
          .select()
          .order('tanggal', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => Arsip(
                id: e['id']?.toString() ?? '',
                judul: e['judul']?.toString() ?? '',
                kategori: e['kategori']?.toString() ?? KategoriArsip.lainnya,
                deskripsi: e['deskripsi']?.toString() ?? '',
                nomorSurat: (e['nomor_surat'] ?? e['nomorSurat'] ?? '').toString(),
                tanggal: e['tanggal'] != null ? (DateTime.tryParse(e['tanggal'].toString()) ?? DateTime.now()) : DateTime.now(),
                pembuatId: (e['pembuat_id'] ?? e['pembuatId'] ?? '').toString(),
                fileUrl: (e['file_url'] ?? e['fileUrl'] ?? '').toString(),
                keterangan: (e['keterangan'] ?? '').toString(),
              ))
          .toList();
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
    try {
      await _db.from('arsip').insert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('arsip', a.id));
    } catch (e) {
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
    try {
      await _db.from('arsip').upsert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('arsip', a.id));
    } catch (e) {
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
    // Sinkronisasi folder ke BaknusDrive
    unawaited(BaknusDriveService.ensureFolderExists(clean));
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
      final rows = await _db.from('arsip').select('id, kategori, file_url');
      final toDeleteRows = rows
          .where((r) {
            final kat = (r['kategori'] ?? '').toString().trim();
            return kat == clean || kat.startsWith('$clean/');
          })
          .toList();
      final toDeleteIds = toDeleteRows.map((r) => r['id'].toString()).toList();
      if (toDeleteIds.isNotEmpty) {
        await _db.from('arsip').delete().inFilter('id', toDeleteIds);
      }
      // Hapus berkas-berkas di dalam folder dari BaknusDrive
      for (final r in toDeleteRows) {
        final fUrl = r['file_url']?.toString() ?? '';
        if (fUrl.isNotEmpty) {
          unawaited(BaknusDriveService.deleteFileByUrl(fUrl));
        }
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
    // Ganti nama folder di BaknusDrive
    unawaited(BaknusDriveService.renameFolder(oldPath, newPath.split('/').last));
    await broadcastDataChange('arsip');
  }

  static Future<void> moveArsipToFolder(
      List<String> ids, String targetFolder) async {
    final allArsip = await getArsip();
    for (final a in allArsip) {
      if (ids.contains(a.id)) {
        a.kategori = targetFolder;
        await updateArsip(a);
        if (a.fileUrl.isNotEmpty) {
          unawaited(BaknusDriveService.moveFileByUrl(a.fileUrl, targetFolder));
        }
      }
    }
    await broadcastDataChange('arsip');
  }

  static Future<void> copyArsipToFolder(
      List<Arsip> list, String targetFolder) async {
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
    // 1. Dapatkan info file untuk hapus dari BaknusDrive
    final cache = await _readCache(_keyArsip);
    final item = cache.firstWhere((item) => item['id'] == id, orElse: () => <String, dynamic>{});
    final fileUrl = (item['file_url'] ?? item['fileUrl'] ?? '').toString();
    if (fileUrl.isNotEmpty) {
      unawaited(BaknusDriveService.deleteFileByUrl(fileUrl));
    }

    // 2. Update cache lokal instan
    cache.removeWhere((item) => item['id'] == id);
    await _saveCache(_keyArsip, cache);

    // 3. Kirim ke Supabase atau antrekan ke SyncService
    try {
      await _db.from('arsip').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('arsip', id));
    } catch (e) {
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
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };

  static Future<String> uploadArsipFile(
      Uint8List bytes, String fileName, {String? folderPath}) async {
    try {
      // 1. Prioritaskan upload ke BaknusDrive (https://baknusdrive.smkbn666.sch.id)
      return await BaknusDriveService.uploadFile(bytes, fileName, folderPath: folderPath);
    } catch (e) {
      debugPrint('BaknusDrive upload failed ($e), falling back to Supabase storage...');
      // 2. Fallback jika ada kendala jaringan khusus BaknusDrive
      final ext =
          fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      final path = '${_uuid.v4()}${ext.isNotEmpty ? '.$ext' : ''}';
      final mime = _mimeTypes[ext] ?? 'application/octet-stream';
      await _db.storage.from('arsip').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
      return _db.storage.from('arsip').getPublicUrl(path);
    }
  }

  // ── Laporan Kegiatan ─────────────────────────────────────────────────────
  static Future<List<LaporanKegiatan>> getLaporan() async {
    try {
      final rows = await _db
          .from('laporan_kegiatan')
          .select()
          .order('tanggal_kegiatan', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => LaporanKegiatan(
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
                peserta: (e['peserta'] as List?)
                        ?.map((p) => p.toString())
                        .toList() ??
                    [],
                pembuatId: e['pembuat_id'] ?? '',
              ))
          .toList();
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
    try {
      await _db.from('laporan_kegiatan').insert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('laporan_kegiatan', l.id));
    } catch (e) {
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
    try {
      await _db.from('laporan_kegiatan').upsert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('laporan_kegiatan', l.id));
    } catch (e) {
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
    try {
      await _db.from('laporan_kegiatan').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('laporan_kegiatan', id));
    } catch (e) {
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
      final rows = await _db
          .from('file_riwayat')
          .select()
          .order('tanggal_upload', ascending: false);
      final list = rows
          .map((e) => FileRiwayat(
                id: e['id'],
                namaFile: e['nama_file'] ?? '',
                tanggalUpload: DateTime.parse(e['tanggal_upload']),
                nisList: (e['nis_list'] as List?)
                        ?.map((n) => n.toString())
                        .toList() ??
                    [],
              ))
          .toList();
      // Simpan ke cache lokal sebagai fallback
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _keyFileRiwayat, list.map((e) => jsonEncode(e.toJson())).toList());
      return list;
    } catch (_) {
      // Fallback ke cache lokal
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_keyFileRiwayat) ?? [])
          .map((e) =>
              FileRiwayat.fromJson(Map<String, dynamic>.from(jsonDecode(e))))
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
        .map((e) =>
            FileRiwayat.fromJson(Map<String, dynamic>.from(jsonDecode(e))))
        .where((r) => r.id != f.id)
        .toList()
      ..insert(0, f);
    await prefs.setStringList(
        _keyFileRiwayat, cached.map((e) => jsonEncode(e.toJson())).toList());

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    try {
      await _db.from('file_riwayat').upsert(dbData);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('file_riwayat', f.id));
    } catch (_) {
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
        .map((e) =>
            FileRiwayat.fromJson(Map<String, dynamic>.from(jsonDecode(e))))
        .where((f) => f.id != id)
        .toList();
    await prefs.setStringList(
        _keyFileRiwayat, list.map((e) => jsonEncode(e.toJson())).toList());

    // 2. Kirim ke Supabase atau antrekan ke SyncService
    try {
      await _db.from('file_riwayat').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('file_riwayat', id));
    } catch (_) {
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
    final targets =
        siswaList.where((s) => file.nisList.contains(s.nis)).toList();
    for (final s in targets) {
      await updateSiswa(Siswa(
          id: s.id, nama: s.nama, kelas: _naikKelas(s.kelas), nis: s.nis));
    }
    await broadcastDataChange('siswa');
    return targets.length;
  }

  static Future<int> turunKelasFromFile(FileRiwayat file) async {
    final siswaList = await getSiswa();
    final targets =
        siswaList.where((s) => file.nisList.contains(s.nis)).toList();
    for (final s in targets) {
      await updateSiswa(Siswa(
          id: s.id, nama: s.nama, kelas: _turunKelas(s.kelas), nis: s.nis));
    }
    await broadcastDataChange('siswa');
    return targets.length;
  }

  // ── SISTEM KAS & ABSENSI OSIS ──────────────────────────────────────────────

  static List<AnggotaOsis> defaultAnggotaOsis() {
    return [];
  }

  // 1. Anggota OSIS
  static Future<List<AnggotaOsis>> getAnggotaOsis() async {
    try {
      final rows = await _db
          .from('anggota_osis')
          .select()
          .order('jabatan')
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => AnggotaOsis.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyAnggotaOsis, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      return list;
    } catch (e) {
      debugPrint('Error fetching anggota_osis from Supabase, fallback to cache: $e');
    }

    final cache = await _readCache(_keyAnggotaOsis);
    return cache.map(AnggotaOsis.fromJson).toList();
  }

  static Future<void> saveAnggotaOsis(List<AnggotaOsis> list) async {
    final oldList = await _readCache(_keyAnggotaOsis);
    final oldIds = oldList.map((e) => e['id']?.toString()).whereType<String>().toSet();
    final newIds = list.map((e) => e.id).toSet();
    final toDelete = oldIds.difference(newIds);

    await _saveCache(_keyAnggotaOsis, list.map((e) => e.toJson()).toList());
    try {
      for (final delId in toDelete) {
        await _db.from('anggota_osis').delete().eq('id', delId);
        unawaited(SyncService.removeAction('anggota_osis', delId));
      }
      for (final item in list) {
        await _db.from('anggota_osis').upsert(item.toJson(), onConflict: 'id');
        unawaited(SyncService.removeAction('anggota_osis', item.id));
      }
      SyncService.setOnlineManually();
    } catch (e) {
      for (final delId in toDelete) {
        await SyncService.enqueueAction(actionType: SyncActionType.delete, table: 'anggota_osis', targetId: delId);
      }
      for (final item in list) {
        await SyncService.enqueueAction(actionType: SyncActionType.upsert, table: 'anggota_osis', data: item.toJson(), targetId: item.id);
      }
    }
    await broadcastDataChange('anggota_osis');
  }

  static Future<void> addAnggotaOsis(AnggotaOsis a) async {
    final list = await getAnggotaOsis();
    list.add(a);
    await _saveCache(_keyAnggotaOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('anggota_osis').upsert(a.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('anggota_osis', a.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'anggota_osis',
        data: a.toJson(),
        targetId: a.id,
      );
    }
    await broadcastDataChange('anggota_osis');
  }

  static Future<void> updateAnggotaOsis(AnggotaOsis a) async {
    final list = await getAnggotaOsis();
    final idx = list.indexWhere((item) => item.id == a.id);
    if (idx != -1) {
      list[idx] = a;
    } else {
      list.add(a);
    }
    await _saveCache(_keyAnggotaOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('anggota_osis').upsert(a.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('anggota_osis', a.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'anggota_osis',
        data: a.toJson(),
        targetId: a.id,
      );
    }
    await broadcastDataChange('anggota_osis');
  }

  static Future<void> deleteAnggotaOsis(String id) async {
    final list = await getAnggotaOsis();
    list.removeWhere((item) => item.id == id);
    await _saveCache(_keyAnggotaOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('anggota_osis').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('anggota_osis', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'anggota_osis',
        targetId: id,
      );
    }
    await broadcastDataChange('anggota_osis');
  }

  // 2. Sesi Kas OSIS
  static Future<List<KasOsisSession>> getKasOsisSessions() async {
    try {
      final rows = await _db
          .from('kas_osis')
          .select()
          .order('tanggal', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => KasOsisSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyKasOsis, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return list;
    } catch (e) {
      debugPrint('Error fetching kas_osis from Supabase, fallback to cache: $e');
    }

    final cache = await _readCache(_keyKasOsis);
    final list = cache.map(KasOsisSession.fromJson).toList();
    list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  static Future<void> saveKasOsisSession(KasOsisSession session) async {
    final list = await getKasOsisSessions();
    final idx = list.indexWhere((s) => s.id == session.id);
    if (idx != -1) {
      list[idx] = session;
    } else {
      list.insert(0, session);
    }
    await _saveCache(_keyKasOsis, list.map((e) => e.toJson()).toList());

    try {
      await _db.from('kas_osis').upsert(session.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('kas_osis', session.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'kas_osis',
        data: session.toJson(),
        targetId: session.id,
      );
    }
    await broadcastDataChange('kas_osis');
  }

  static Future<void> deleteKasOsisSession(String id) async {
    final list = await getKasOsisSessions();
    list.removeWhere((s) => s.id == id);
    await _saveCache(_keyKasOsis, list.map((e) => e.toJson()).toList());

    try {
      await _db.from('kas_osis').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('kas_osis', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'kas_osis',
        targetId: id,
      );
    }
    await broadcastDataChange('kas_osis');
  }

  // 3. Buku Transaksi Kas Umum
  static Future<List<KasOsisTransaksi>> getKasTransaksi() async {
    try {
      final rows = await _db
          .from('kas_transaksi')
          .select()
          .order('tanggal', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => KasOsisTransaksi.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyKasTransaksi, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return list;
    } catch (e) {
      debugPrint('Error fetching kas_transaksi from Supabase, fallback to cache: $e');
    }

    final cache = await _readCache(_keyKasTransaksi);
    final list = cache.map(KasOsisTransaksi.fromJson).toList();
    list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  static Future<void> addKasTransaksi(KasOsisTransaksi t) async {
    final list = await getKasTransaksi();
    list.insert(0, t);
    await _saveCache(_keyKasTransaksi, list.map((e) => e.toJson()).toList());

    try {
      await _db.from('kas_transaksi').upsert(t.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('kas_transaksi', t.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'kas_transaksi',
        data: t.toJson(),
        targetId: t.id,
      );
    }
    await broadcastDataChange('kas_transaksi');
  }

  static Future<void> deleteKasTransaksi(String id) async {
    final list = await getKasTransaksi();
    list.removeWhere((t) => t.id == id);
    await _saveCache(_keyKasTransaksi, list.map((e) => e.toJson()).toList());

    try {
      await _db.from('kas_transaksi').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('kas_transaksi', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'kas_transaksi',
        targetId: id,
      );
    }
    await broadcastDataChange('kas_transaksi');
  }

  // 4. Sesi Absensi OSIS
  static Future<List<AbsensiOsisSession>> getAbsensiOsisSessions() async {
    try {
      final rows = await _db
          .from('absensi_osis')
          .select()
          .order('tanggal', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => AbsensiOsisSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyAbsensiOsis, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
      return list;
    } catch (e) {
      debugPrint('Error fetching absensi_osis from Supabase, fallback to cache: $e');
    }

    final cache = await _readCache(_keyAbsensiOsis);
    final list = cache.map(AbsensiOsisSession.fromJson).toList();
    list.sort((a, b) => b.tanggal.compareTo(a.tanggal));
    return list;
  }

  static Future<void> saveAbsensiOsisSession(AbsensiOsisSession session) async {
    final list = await getAbsensiOsisSessions();
    final idx = list.indexWhere((s) => s.id == session.id);
    if (idx != -1) {
      list[idx] = session;
    } else {
      list.insert(0, session);
    }
    await _saveCache(_keyAbsensiOsis, list.map((e) => e.toJson()).toList());

    try {
      await _db.from('absensi_osis').upsert(session.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('absensi_osis', session.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'absensi_osis',
        data: session.toJson(),
        targetId: session.id,
      );
    }
    await broadcastDataChange('absensi_osis');
  }

  static Future<void> deleteAbsensiOsisSession(String id) async {
    final list = await getAbsensiOsisSessions();
    list.removeWhere((s) => s.id == id);
    await _saveCache(_keyAbsensiOsis, list.map((e) => e.toJson()).toList());

    try {
      await _db.from('absensi_osis').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('absensi_osis', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'absensi_osis',
        targetId: id,
      );
    }
    await broadcastDataChange('absensi_osis');
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
        uint8[0] == 0xD0 &&
        uint8[1] == 0xCF &&
        uint8[2] == 0x11 &&
        uint8[3] == 0xE0) {
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
      int jabatanCol = -1, statusCol = -1;
      for (int h = 0; h < maxSearch; h++) {
        final hRow = sheet.rows[h];
        int tempNama = -1, tempNis = -1, tempJab = -1, tempStat = -1;
        for (int i = 0; i < hRow.length; i++) {
          final val = hRow[i]?.value?.toString().toLowerCase().trim() ?? '';
          if (val.contains('nama') || val == 'siswa') tempNama = i;
          if (val.contains('nis')) tempNis = i;
          if (val.contains('jabatan') || val.contains('peran') || val.contains('divisi') || val.contains('sekbid') || val.contains('posisi')) tempJab = i;
          if (val.contains('status') || val.contains('keterangan') || val.contains('kehadiran') || val.contains('absen')) tempStat = i;
        }
        if (tempNama != -1) {
          headerRow = h;
          namaCol = tempNama;
          nisCol = tempNis;
          jabatanCol = tempJab;
          statusCol = tempStat;
          // Jika header ditemukan di baris >= 4 dan ada NIS, anggap format absen sekolah
          isFormatAbsen = h >= 4 && tempNis != -1;
          break;
        }
      }

      if (isFormatAbsen && nisCol != -1) {
        // Format Absen: data mulai 2 baris setelah header (skip sub-header)
        final dataStart = headerRow + 2;
        for (int r = dataStart; r < sheet.maxRows; r++) {
          final row = sheet.rows[r];
          final nama = (row.length > namaCol
                  ? row[namaCol]?.value?.toString().trim()
                  : null) ??
              '';
          if (nama.isEmpty) continue;
          final nisRaw = row.length > nisCol ? row[nisCol]?.value : null;
          final nis = _cellValueToNis(nisRaw);
          final jabVal = (jabatanCol != -1 && row.length > jabatanCol)
              ? (row[jabatanCol]?.value?.toString().trim() ?? '')
              : '';
          final statVal = (statusCol != -1 && row.length > statusCol)
              ? (row[statusCol]?.value?.toString().trim() ?? '')
              : '';
          result.add({
            'nama': nama,
            'kelas': kelas,
            'nis': nis.isNotEmpty ? nis : 'OSIS-${r + 1}',
            if (jabVal.isNotEmpty) 'jabatan': jabVal,
            if (statVal.isNotEmpty) 'status': statVal,
          });
        }
      } else if (namaCol != -1) {
        // Format sederhana: cari kolom kelas juga
        int kelasCol = -1;
        final hRow = sheet.rows[headerRow];
        for (int i = 0; i < hRow.length; i++) {
          final val = hRow[i]?.value?.toString().toLowerCase().trim() ?? '';
          if (val.contains('kelas') || val.contains('tingkat')) kelasCol = i;
        }
        for (int r = headerRow + 1; r < sheet.maxRows; r++) {
          final row = sheet.rows[r];
          final nama = (row.length > namaCol
                  ? row[namaCol]?.value?.toString().trim()
                  : null) ??
              '';
          if (nama.isEmpty) continue;
          final nisRaw = (nisCol != -1 && row.length > nisCol) ? row[nisCol]?.value : null;
          final nis = _cellValueToNis(nisRaw);
          final kelasVal = (kelasCol != -1 && row.length > kelasCol)
              ? (row[kelasCol]?.value?.toString().trim() ?? kelas)
              : kelas;
          final jabVal = (jabatanCol != -1 && row.length > jabatanCol)
              ? (row[jabatanCol]?.value?.toString().trim() ?? '')
              : '';
          final statVal = (statusCol != -1 && row.length > statusCol)
              ? (row[statusCol]?.value?.toString().trim() ?? '')
              : '';

          result.add({
            'nama': nama,
            'kelas': kelasVal.isNotEmpty ? kelasVal : '-',
            'nis': nis.isNotEmpty ? nis : 'OSIS-${r + 1}',
            if (jabVal.isNotEmpty) 'jabatan': jabVal,
            if (statVal.isNotEmpty) 'status': statVal,
          });
        }
      }
    }
    return result;
  }

  // ── Import & Export Excel Khusus OSIS ───────────────────────────────────────

  /// Impor Anggota OSIS langsung dari file Excel (.xlsx / .xls)
  static Future<List<AnggotaOsis>> importAnggotaOsisFromExcel(List<int> bytes) async {
    final parsed = _parseExcel(bytes);
    if (parsed.isEmpty) return [];

    final current = await getAnggotaOsis();
    final map = {for (var m in current) m.nama.toLowerCase().trim(): m};

    final imported = <AnggotaOsis>[];
    for (int i = 0; i < parsed.length; i++) {
      final p = parsed[i];
      final nama = (p['nama'] ?? '').trim();
      if (nama.isEmpty) continue;

      final kelas = (p['kelas'] ?? '').trim();
      final nis = (p['nis'] ?? '').trim();
      final jabatan = (p['jabatan'] ?? '').trim().isNotEmpty
          ? p['jabatan']!.trim()
          : 'Anggota OSIS';

      final key = nama.toLowerCase().trim();
      final existing = map[key];
      final item = AnggotaOsis(
        id: existing?.id ?? 'ang-${DateTime.now().millisecondsSinceEpoch}-$i',
        nama: nama,
        kelas: kelas.isNotEmpty ? kelas : (existing?.kelas ?? '-'),
        nis: nis.isNotEmpty ? nis : (existing?.nis ?? ''),
        jabatan: jabatan,
      );
      map[key] = item;
      imported.add(item);
    }

    final updated = map.values.toList();
    await saveAnggotaOsis(updated);
    return imported;
  }

  /// Impor Sesi Absensi OSIS langsung dari file Excel.
  /// Otomatis membuat sesi baru hanya dengan nama-nama anggota OSIS yang tercantum di Excel.
  static Future<AbsensiOsisSession?> importAbsensiOsisFromExcel(
    List<int> bytes, {
    required String namaKegiatan,
    DateTime? tanggal,
    String lokasi = 'Ruang OSIS',
  }) async {
    final parsed = _parseExcel(bytes);
    if (parsed.isEmpty) return null;

    final sessionId = 'abs-${DateTime.now().millisecondsSinceEpoch}';
    final sessionDate = tanggal ?? DateTime.now();

    final absensiItems = <AbsensiOsisItem>[];
    for (int i = 0; i < parsed.length; i++) {
      final p = parsed[i];
      final nama = (p['nama'] ?? '').trim();
      if (nama.isEmpty) continue;

      final kelas = (p['kelas'] ?? '').trim();
      final jabatan = (p['jabatan'] ?? '').trim().isNotEmpty
          ? p['jabatan']!.trim()
          : 'Anggota OSIS';

      String status = 'Hadir';
      final rawStatus = (p['status'] ?? '').trim().toUpperCase();
      if (rawStatus.startsWith('I') || rawStatus.contains('IZIN')) {
        status = 'Izin';
      } else if (rawStatus.startsWith('S') || rawStatus.contains('SAKIT')) {
        status = 'Sakit';
      } else if (rawStatus.startsWith('A') || rawStatus.contains('ALPA') || rawStatus.contains('ALPHA')) {
        status = 'Alpa';
      }

      final angId = 'ang-${DateTime.now().millisecondsSinceEpoch}-$i';
      absensiItems.add(AbsensiOsisItem(
        anggotaId: angId,
        nama: nama,
        kelas: kelas.isNotEmpty ? kelas : '-',
        jabatan: jabatan,
        status: status,
      ));
    }

    if (absensiItems.isEmpty) return null;

    final newSession = AbsensiOsisSession(
      id: sessionId,
      namaKegiatan: namaKegiatan,
      tanggal: sessionDate,
      lokasi: lokasi,
      items: absensiItems,
      updatedAt: DateTime.now(),
    );

    await saveAbsensiOsisSession(newSession);

    // Otomatis sinkronkan anggota baru ke daftar Anggota OSIS
    final currentAnggota = await getAnggotaOsis();
    final nameSet = currentAnggota.map((a) => a.nama.toLowerCase().trim()).toSet();
    bool addedAny = false;

    for (int i = 0; i < absensiItems.length; i++) {
      final item = absensiItems[i];
      if (!nameSet.contains(item.nama.toLowerCase().trim())) {
        final rawNis = i < parsed.length ? (parsed[i]['nis'] ?? '').trim() : '';
        currentAnggota.add(AnggotaOsis(
          id: item.anggotaId,
          nama: item.nama,
          kelas: item.kelas,
          nis: rawNis,
          jabatan: item.jabatan,
        ));
        nameSet.add(item.nama.toLowerCase().trim());
        addedAny = true;
      }
    }

    if (addedAny) {
      await saveAnggotaOsis(currentAnggota);
    }

    return newSession;
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

    final wbBytes = _readBiffStream(bytes, workbookFirstSec, sat, sectorSize,
        maxSize: workbookSize);
    return _parseWorkbookBiff8(wbBytes);
  }

  static Uint8List _readBiffStream(
      Uint8List fileBytes, int startSec, List<int> sat, int sectorSize,
      {int? maxSize}) {
    final builder = BytesBuilder();
    int sec = startSec;
    while (sec >= 0 &&
        sec < sat.length &&
        sec != 0xFFFFFFFE &&
        sec != 0xFFFFFFFF) {
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

      if (recType == 0x0085 && recLen >= 8) {
        // BOUNDSHEET
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
          sheetName = String.fromCharCodes(
              wb.sublist(dataPos + 8, dataPos + 8 + nameLen));
        } else {
          sheetName = 'Sheet';
        }
        sheets.add(_BiffSheetInfo(sheetName.trim(), offset));
      } else if (recType == 0x00FC) {
        // SST
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

        if (recType == 0x00FD && recLen >= 10) {
          // LABELSST
          final r = bd.getUint16(dataPos, Endian.little);
          final c = bd.getUint16(dataPos + 2, Endian.little);
          final sstIdx = bd.getUint32(dataPos + 6, Endian.little);
          if (sstIdx < sst.length) {
            cellMap.putIfAbsent(r, () => {})[c] = sst[sstIdx];
          }
        } else if (recType == 0x0203 && recLen >= 14) {
          // NUMBER
          final r = bd.getUint16(dataPos, Endian.little);
          final c = bd.getUint16(dataPos + 2, Endian.little);
          final val = bd.getFloat64(dataPos + 6, Endian.little);
          final valStr =
              val == val.toInt() ? val.toInt().toString() : val.toString();
          cellMap.putIfAbsent(r, () => {})[c] = valStr;
        } else if (recType == 0x027E && recLen >= 10) {
          // RK
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

  static void _extractStudentsFromBiffSheet(String sheetName,
      Map<int, Map<int, String>> cellMap, List<Map<String, String>> results) {
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
      if (nama.toLowerCase().contains('nama') ||
          nama.toLowerCase().contains('pertemuan')) {
        continue;
      }

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
  static Future<int> importStudentsFromExcel(List<int> bytes,
      {String namaFile = 'file.xlsx'}) async {
    final rows = _parseExcel(bytes);
    if (rows.isEmpty) {
      throw Exception('File kosong atau format tidak dikenali.\n'
          'Gunakan format Excel absen sekolah:\n'
          '• Setiap sheet = satu kelas (nama sheet = nama kelas)\n'
          '• Baris ke-6: header (N0 | NIS | NAMA LENGKAP | ...)\n'
          '• Baris ke-7: sub-header (L | P | angka)\n'
          '• Baris ke-8+: data siswa\n'
          'Atau format sederhana dengan kolom Nama, Kelas, NIS.');
    }

    final toUpsert = rows
        .map((row) => {
              'id': _uuid.v4(),
              'nama': row['nama']!,
              'kelas': row['kelas']!,
              'nis': row['nis']!,
            })
        .toList();

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

    // 2. Upsert ke Supabase per batch 50 (langsung) atau enqueue jika offline
    const batchSize = 50;
    try {
      for (int i = 0; i < toUpsert.length; i += batchSize) {
        final end = (i + batchSize).clamp(0, toUpsert.length);
        await _db.from('siswa').upsert(
              toUpsert.sublist(i, end),
              onConflict: 'nis',
              ignoreDuplicates: true,
            );
      }
      SyncService.setOnlineManually();
      for (final item in toUpsert) {
        final targetId = item['id']?.toString() ?? item['nis']?.toString();
        if (targetId != null) {
          unawaited(SyncService.removeAction('siswa', targetId));
        }
      }
    } catch (e) {
      for (final item in toUpsert) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'siswa',
          data: item,
          targetId: item['id']?.toString() ?? item['nis']?.toString(),
        );
      }
    }

    // Simpan riwayat file
    final nisList =
        rows.map((r) => r['nis']!).where((n) => n.isNotEmpty).toList();
    final riwayat = await getFileRiwayat();
    final existing = riwayat.firstWhere((f) => f.namaFile == namaFile,
        orElse: () => FileRiwayat(
            id: _uuid.v4(),
            namaFile: namaFile,
            tanggalUpload: DateTime.now(),
            nisList: []));
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
    if (rows.isEmpty) {
      throw Exception('File kosong atau format tidak dikenali.');
    }

    final nisList =
        rows.map((r) => r['nis']!).where((n) => n.isNotEmpty).toList();
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

  // ── 1. PROFIL OSIS ─────────────────────────────────────────────────────────
  static Future<ProfilOsis> getProfilOsis() async {
    try {
      final rows = await _db
          .from('profil_osis')
          .select()
          .limit(1)
          .timeout(const Duration(seconds: 4));
      if ((rows as List).isNotEmpty) {
        final item = ProfilOsis.fromJson(Map<String, dynamic>.from(rows.first as Map));
        await _saveCache(_keyProfilOsis, [item.toJson()]);
        return item;
      }
    } catch (_) {}

    final cache = await _readCache(_keyProfilOsis);
    if (cache.isNotEmpty) {
      return ProfilOsis.fromJson(cache.first);
    }

    final def = ProfilOsis();
    await _saveCache(_keyProfilOsis, [def.toJson()]);
    return def;
  }

  static Future<void> saveProfilOsis(ProfilOsis p) async {
    await _saveCache(_keyProfilOsis, [p.toJson()]);
    try {
      await _db.from('profil_osis').upsert(p.toJson());
      SyncService.setOnlineManually();
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'profil_osis',
        data: p.toJson(),
        targetId: 'single',
      );
    }
    await broadcastDataChange('profil_osis');
    await logAktivitas(aksi: 'Perbarui Profil OSIS', modul: 'Profil OSIS', detail: 'Memperbarui informasi organisasi');
  }

  // ── 3. INVENTARIS OSIS ─────────────────────────────────────────────────────
  static List<InventarisOsis> defaultInventarisSeed() => [
    InventarisOsis(
      id: 'inv-1',
      namaBarang: 'Pengeras Suara Wireless Portable (Megaphone)',
      kodeBarang: 'INV-ELK-001',
      kategori: 'Elektronik',
      jumlah: 2,
      kondisi: 'Baik',
      lokasiSimpan: 'Lemari Audio Ruang OSIS',
      statusPeminjaman: 'Tersedia',
      keterangan: 'Kondisi baterai prima, siap digunakan apel/kegiatan luar.',
    ),
    InventarisOsis(
      id: 'inv-2',
      namaBarang: 'Proyektor Epson LCD Portable',
      kodeBarang: 'INV-ELK-002',
      kategori: 'Elektronik',
      jumlah: 1,
      kondisi: 'Baik',
      lokasiSimpan: 'Ruang Rapat OSIS',
      statusPeminjaman: 'Tersedia',
      keterangan: 'Kabel HDMI & adaptor lengkap.',
    ),
    InventarisOsis(
      id: 'inv-3',
      namaBarang: 'Bendera Pataka & Bendera OSIS Resmi',
      kodeBarang: 'INV-UPC-003',
      kategori: 'Perlengkapan Acara',
      jumlah: 4,
      kondisi: 'Baik',
      lokasiSimpan: 'Kotak Khusus Upacara',
      statusPeminjaman: 'Tersedia',
      keterangan: 'Digunakan saat pelantikan dan hari besar nasional.',
    ),
    InventarisOsis(
      id: 'inv-4',
      namaBarang: 'Stempel Resmi & Bantalan Tinta OSIS',
      kodeBarang: 'INV-ADM-004',
      kategori: 'ATK & Kantor',
      jumlah: 2,
      kondisi: 'Baik',
      lokasiSimpan: 'Meja Sekretaris OSIS',
      statusPeminjaman: 'Tersedia',
      keterangan: 'Hanya digunakan untuk surat resmi organisasi.',
    ),
  ];

  static Future<List<InventarisOsis>> getInventaris() async {
    try {
      final rows = await _db
          .from('inventaris_osis')
          .select()
          .order('nama_barang')
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => InventarisOsis.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyInventarisOsis, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      return list;
    } catch (_) {}

    final cache = await _readCache(_keyInventarisOsis);
    return cache.map(InventarisOsis.fromJson).toList();
  }

  static Future<void> saveInventaris(InventarisOsis item) async {
    final list = await getInventaris();
    final idx = list.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }

    await _saveCache(_keyInventarisOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('inventaris_osis').upsert(item.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('inventaris_osis', item.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'inventaris_osis',
        data: item.toJson(),
        targetId: item.id,
      );
    }
    await broadcastDataChange('inventaris_osis');
    await logAktivitas(aksi: 'Simpan Inventaris', modul: 'Administrasi', detail: '${item.namaBarang} (${item.kondisi})');
  }

  static Future<void> deleteInventaris(String id) async {
    final list = await getInventaris();
    final item = list.firstWhere((i) => i.id == id, orElse: () => InventarisOsis(id: id, namaBarang: 'Barang'));
    list.removeWhere((i) => i.id == id);

    await _saveCache(_keyInventarisOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('inventaris_osis').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('inventaris_osis', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'inventaris_osis',
        targetId: id,
      );
    }
    await broadcastDataChange('inventaris_osis');
    await logAktivitas(aksi: 'Hapus Inventaris', modul: 'Administrasi', detail: item.namaBarang);
  }

  // ── 5. KALENDER & AGENDA KEGIATAN ─────────────────────────────────────────
  static List<AgendaOsis> defaultAgendaSeed() {
    final now = DateTime.now();
    return [
      AgendaOsis(
        id: 'agd-1',
        judul: 'Rapat Koordinasi Mingguan Pengurus Inti & Sekbid',
        kategori: 'Rapat OSIS',
        bidang: 'BPH',
        waktuMulai: DateTime(now.year, now.month, now.day + 2, 14, 30),
        waktuSelesai: DateTime(now.year, now.month, now.day + 2, 16, 00),
        lokasi: 'Ruang Sekretariat OSIS',
        penanggungJawab: 'Ketua & Sekretaris OSIS',
        deskripsi: 'Evaluasi mingguan program kerja dan persiapan agenda upacara hari Senin.',
        status: 'Akan Datang',
      ),
      AgendaOsis(
        id: 'agd-2',
        judul: 'Pelaksanaan Latihan Dasar Kepemimpinan Siswa (LDKS)',
        kategori: 'Kegiatan Sekolah',
        bidang: 'SEKBID3',
        waktuMulai: DateTime(now.year, now.month, now.day + 7, 8, 00),
        waktuSelesai: DateTime(now.year, now.month, now.day + 9, 15, 00),
        lokasi: 'Aula Sekolah & Lapangan Luar',
        penanggungJawab: 'Sekbid 3 & Pembina OSIS',
        deskripsi: 'Membentuk karakter kepemimpinan, disiplin, dan kekompakan calon pengurus baru.',
        status: 'Akan Datang',
      ),
      AgendaOsis(
        id: 'agd-3',
        judul: 'Turnamen Futsal Antarkelas (Class Meeting)',
        kategori: 'Perlombaan',
        bidang: 'SEKBID7',
        waktuMulai: DateTime(now.year, now.month, now.day + 14, 8, 30),
        waktuSelesai: DateTime(now.year, now.month, now.day + 16, 16, 30),
        lokasi: 'Gelanggang Olahraga Sekolah',
        penanggungJawab: 'Sekbid 7 (Olahraga)',
        deskripsi: 'Mempererat tali silaturahmi antarsiswa pasca ujian semester.',
        status: 'Akan Datang',
      ),
    ];
  }

  static Future<List<AgendaOsis>> getAgenda() async {
    try {
      final rows = await _db
          .from('agenda_osis')
          .select()
          .order('waktu_mulai', ascending: true)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => AgendaOsis.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyAgendaOsis, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      return list;
    } catch (_) {}

    final cache = await _readCache(_keyAgendaOsis);
    final list = cache.map(AgendaOsis.fromJson).toList();
    list.sort((a, b) => a.waktuMulai.compareTo(b.waktuMulai));
    return list;
  }

  static Future<void> saveAgenda(AgendaOsis item) async {
    final list = await getAgenda();
    final idx = list.indexWhere((a) => a.id == item.id);
    if (idx != -1) {
      list[idx] = item;
    } else {
      list.add(item);
    }
    list.sort((a, b) => a.waktuMulai.compareTo(b.waktuMulai));

    await _saveCache(_keyAgendaOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('agenda_osis').upsert(item.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('agenda_osis', item.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'agenda_osis',
        data: item.toJson(),
        targetId: item.id,
      );
    }
    await broadcastDataChange('agenda_osis');
    await logAktivitas(aksi: 'Simpan Agenda', modul: 'Agenda & Kalender', detail: '${item.judul} (${DateFormat('d MMM yyyy').format(item.waktuMulai)})');
  }

  static Future<void> deleteAgenda(String id) async {
    final list = await getAgenda();
    final item = list.firstWhere((a) => a.id == id, orElse: () => AgendaOsis(id: id, judul: 'Agenda', waktuMulai: DateTime.now()));
    list.removeWhere((a) => a.id == id);

    await _saveCache(_keyAgendaOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('agenda_osis').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('agenda_osis', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'agenda_osis',
        targetId: id,
      );
    }
    await broadcastDataChange('agenda_osis');
    await logAktivitas(aksi: 'Hapus Agenda', modul: 'Agenda & Kalender', detail: item.judul);
  }

  // ── 8. INFORMASI & PENGUMUMAN ──────────────────────────────────────────────
  static List<PengumumanOsis> defaultPengumumanSeed() {
    final now = DateTime.now();
    return [
      PengumumanOsis(
        id: 'pgm-1',
        judul: 'Instruksi Persiapan Rapat Kerja & Pleno Tahunan OSIS',
        isi: 'Kepada seluruh Koordinator Bidang (Sekbid 1 - 10), mohon segera menyusun berkas rencana anggaran dan jadwal pelaksanaan program kerja semester ganjil untuk dipresentasikan pada rapat pleno mendatang.',
        pengirim: 'Ketua OSIS',
        rolePengirim: 'Ketua OSIS',
        kategori: 'Ketua OSIS',
        targetBidang: 'Semua',
        tanggal: DateTime(now.year, now.month, now.day - 1, 10, 00),
        isPinned: true,
      ),
      PengumumanOsis(
        id: 'pgm-2',
        judul: 'Arahan Pembina: Kedisiplinan Piket & Penjagaan Ruang OSIS',
        isi: 'Diharapkan seluruh pengurus yang bertugas piket harian menjaga kebersihan ruang OSIS dan mematikan AC serta perangkat elektronik sebelum meninggalkan ruangan.',
        pengirim: 'Pembina OSIS',
        rolePengirim: 'Pembina OSIS',
        kategori: 'Pembina OSIS',
        targetBidang: 'Semua',
        tanggal: DateTime(now.year, now.month, now.day - 3, 13, 15),
        isPinned: false,
      ),
    ];
  }

  static Future<List<PengumumanOsis>> getPengumuman() async {
    try {
      final rows = await _db
          .from('pengumuman_osis')
          .select()
          .order('tanggal', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => PengumumanOsis.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyPengumumanOsis, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      return list;
    } catch (_) {}

    final cache = await _readCache(_keyPengumumanOsis);
    final list = cache.map(PengumumanOsis.fromJson).toList();
    list.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.tanggal.compareTo(a.tanggal);
    });
    return list;
  }

  static Future<void> savePengumuman(PengumumanOsis item) async {
    final list = await getPengumuman();
    final idx = list.indexWhere((p) => p.id == item.id);
    if (idx != -1) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }

    await _saveCache(_keyPengumumanOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('pengumuman_osis').upsert(item.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('pengumuman_osis', item.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'pengumuman_osis',
        data: item.toJson(),
        targetId: item.id,
      );
    }
    await broadcastDataChange('pengumuman_osis');
    await logAktivitas(aksi: 'Kirim Pengumuman', modul: 'Pengumuman', detail: item.judul);
  }

  static Future<void> deletePengumuman(String id) async {
    final list = await getPengumuman();
    final item = list.firstWhere((p) => p.id == id, orElse: () => PengumumanOsis(id: id, judul: 'Pengumuman', isi: '', pengirim: ''));
    list.removeWhere((p) => p.id == id);

    await _saveCache(_keyPengumumanOsis, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('pengumuman_osis').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('pengumuman_osis', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'pengumuman_osis',
        targetId: id,
      );
    }
    await broadcastDataChange('pengumuman_osis');
    await logAktivitas(aksi: 'Hapus Pengumuman', modul: 'Pengumuman', detail: item.judul);
  }

  // ── 9. DOKUMENTASI KEGIATAN ───────────────────────────────────────────────
  static List<DokumentasiKegiatan> defaultDokumentasiSeed() {
    final now = DateTime.now();
    return [
      DokumentasiKegiatan(
        id: 'dok-1',
        judul: 'Peringatan Hari Pahlawan & Upacara Bendera Khidmat',
        kategori: 'Kegiatan Sekolah',
        tanggal: DateTime(now.year, now.month, now.day - 11),
        deskripsi: 'Upacara bendera gabungan bersama dewan guru dan seluruh siswa-siswi, dilanjutkan dengan persembahan puisi kepahlawanan.',
        bidang: 'SEKBID3',
        penanggungJawab: 'Sekbid 3 (Bela Negara)',
        fotoUrls: const [
          'https://images.unsplash.com/photo-1577495508048-b635879837f1?auto=format&fit=crop&w=600&q=80',
        ],
      ),
      DokumentasiKegiatan(
        id: 'dok-2',
        judul: 'Bakti Sosial & Santunan Panti Asuhan',
        kategori: 'Kegiatan Sosial',
        tanggal: DateTime(now.year, now.month, now.day - 20),
        deskripsi: 'Penyaluran bantuan sembako dan perlengkapan sekolah dari donasi warga sekolah untuk panti asuhan sekitar lingkungan sekolah.',
        bidang: 'SEKBID1',
        penanggungJawab: 'Sekbid 1 & Sekbid 2',
        fotoUrls: const [
          'https://images.unsplash.com/photo-1593113598332-cd288d649433?auto=format&fit=crop&w=600&q=80',
        ],
      ),
    ];
  }

  static Future<List<DokumentasiKegiatan>> getDokumentasi() async {
    try {
      final rows = await _db
          .from('dokumentasi_kegiatan')
          .select()
          .order('tanggal', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => DokumentasiKegiatan.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyDokumentasiKegiatan, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      return list;
    } catch (_) {}

    final cache = await _readCache(_keyDokumentasiKegiatan);
    return cache.map(DokumentasiKegiatan.fromJson).toList();
  }

  static Future<void> saveDokumentasi(DokumentasiKegiatan item) async {
    final list = await getDokumentasi();
    final idx = list.indexWhere((d) => d.id == item.id);
    if (idx != -1) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }

    await _saveCache(_keyDokumentasiKegiatan, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('dokumentasi_kegiatan').upsert(item.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('dokumentasi_kegiatan', item.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'dokumentasi_kegiatan',
        data: item.toJson(),
        targetId: item.id,
      );
    }
    await broadcastDataChange('dokumentasi_kegiatan');
    await logAktivitas(aksi: 'Tambah Dokumentasi', modul: 'Dokumentasi', detail: item.judul);
  }

  static Future<void> deleteDokumentasi(String id) async {
    final list = await getDokumentasi();
    final item = list.firstWhere((d) => d.id == id, orElse: () => DokumentasiKegiatan(id: id, judul: 'Dokumentasi', tanggal: DateTime.now()));
    list.removeWhere((d) => d.id == id);

    await _saveCache(_keyDokumentasiKegiatan, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('dokumentasi_kegiatan').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('dokumentasi_kegiatan', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'dokumentasi_kegiatan',
        targetId: id,
      );
    }
    await broadcastDataChange('dokumentasi_kegiatan');
    await logAktivitas(aksi: 'Hapus Dokumentasi', modul: 'Dokumentasi', detail: item.judul);
  }

  // ── 10. EVALUASI DAN PENILAIAN KINERJA ────────────────────────────────────
  static List<EvaluasiProker> defaultEvaluasiSeed() {
    return [
      EvaluasiProker(
        id: 'evl-1',
        prokerId: 'prk-1',
        namaProker: 'Peringatan Hari Pahlawan & Lomba Teatrikal',
        sekbid: 'SEKBID3',
        hasilCapaian: 'Acara berjalan lancar, 95% kelas berpartisipasi aktif dalam perlombaan.',
        kendala: 'Keterbatasan sound system di lapangan saat hujan rintik-rintik.',
        saranMasukan: 'Menyediakan tenda cadangan dan proteksi alat elektronik untuk kegiatan luar ruangan.',
        nilaiKinerja: 90,
        penilai: 'Pembina OSIS',
        rekomendasi: 'Program sangat baik, dapat dipertahankan untuk tahun ajaran berikutnya.',
      ),
    ];
  }

  static Future<List<EvaluasiProker>> getEvaluasi() async {
    try {
      final rows = await _db
          .from('evaluasi_proker')
          .select()
          .order('tanggal_evaluasi', ascending: false)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => EvaluasiProker.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyEvaluasiProker, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      return list;
    } catch (_) {}

    final cache = await _readCache(_keyEvaluasiProker);
    return cache.map(EvaluasiProker.fromJson).toList();
  }

  static Future<void> saveEvaluasi(EvaluasiProker item) async {
    final list = await getEvaluasi();
    final idx = list.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }

    await _saveCache(_keyEvaluasiProker, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('evaluasi_proker').upsert(item.toJson(), onConflict: 'id');
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('evaluasi_proker', item.id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'evaluasi_proker',
        data: item.toJson(),
        targetId: item.id,
      );
    }
    await broadcastDataChange('evaluasi_proker');
    await logAktivitas(aksi: 'Catat Evaluasi Proker', modul: 'Evaluasi & Pelaporan', detail: '${item.namaProker} (Skor: ${item.nilaiKinerja})');
  }

  static Future<void> deleteEvaluasi(String id) async {
    final list = await getEvaluasi();
    final item = list.firstWhere((e) => e.id == id, orElse: () => EvaluasiProker(id: id, prokerId: '', namaProker: 'Evaluasi', sekbid: ''));
    list.removeWhere((e) => e.id == id);

    await _saveCache(_keyEvaluasiProker, list.map((e) => e.toJson()).toList());
    try {
      await _db.from('evaluasi_proker').delete().eq('id', id);
      SyncService.setOnlineManually();
      unawaited(SyncService.removeAction('evaluasi_proker', id));
    } catch (e) {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'evaluasi_proker',
        targetId: id,
      );
    }
    await broadcastDataChange('evaluasi_proker');
    await logAktivitas(aksi: 'Hapus Evaluasi', modul: 'Evaluasi & Pelaporan', detail: item.namaProker);
  }

  // ── 12.10. RIWAYAT AKTIVITAS PENGGUNA (AUDIT LOG) ──────────────────────────
  static Future<List<AktivitasPengguna>> getAktivitas() async {
    try {
      final rows = await _db
          .from('aktivitas_pengguna')
          .select()
          .order('waktu', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 4));
      final list = (rows as List)
          .map((e) => AktivitasPengguna.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      await _saveCache(_keyAktivitasPengguna, list.map((e) => e.toJson()).toList());
      SyncService.setOnlineManually();
      return list;
    } catch (_) {}

    final cache = await _readCache(_keyAktivitasPengguna);
    return cache.map(AktivitasPengguna.fromJson).toList();
  }

  static Future<void> logAktivitas({
    required String aksi,
    required String modul,
    String detail = '',
    String? username,
    String? displayName,
    String? role,
  }) async {
    try {
      final u = username ?? (await AuthService.getUserName() ?? 'SYSTEM');
      final d = displayName ?? (await AuthService.getCurrentDisplayName());
      final r = role ?? AuthService.getRole(u);

      final logItem = AktivitasPengguna(
        id: const Uuid().v4(),
        username: u,
        displayName: d.isNotEmpty ? d : AuthService.getDisplayName(u),
        role: r,
        aksi: aksi,
        modul: modul,
        waktu: DateTime.now(),
        detail: detail,
      );

      final current = await _readCache(_keyAktivitasPengguna);
      current.insert(0, logItem.toJson());
      if (current.length > 200) {
        current.removeRange(200, current.length);
      }
      await _saveCache(_keyAktivitasPengguna, current);

      try {
        await _db.from('aktivitas_pengguna').insert(logItem.toJson());
      } catch (_) {}
      notifyDataChanged('aktivitas_pengguna');
    } catch (_) {}
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
      await getKasOsisSessions();
      await getKasTransaksi();
      await getAbsensiOsisSessions();
      await getAnggotaOsis();
      await getProfilOsis();
      await getInventaris();
      await getAgenda();
      await getPengumuman();
      await getDokumentasi();
      await getEvaluasi();
      await getAktivitas();
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
    await prefs.remove(_keyKasOsis);
    await prefs.remove(_keyKasTransaksi);
    await prefs.remove(_keyAbsensiOsis);
    await prefs.remove(_keyAnggotaOsis);
    await prefs.remove(_keyProfilOsis);
    await prefs.remove(_keyInventarisOsis);
    await prefs.remove(_keyAgendaOsis);
    await prefs.remove(_keyPengumumanOsis);
    await prefs.remove(_keyDokumentasiKegiatan);
    await prefs.remove(_keyEvaluasiProker);
    await prefs.remove(_keyAktivitasPengguna);
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
