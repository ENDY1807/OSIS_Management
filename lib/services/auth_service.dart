import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_service.dart';

class AuthService {
  static const _keyLoggedIn  = 'logged_in';
  static const _keyUserName  = 'user_name';
  static const _keyAccounts  = 'accounts_v3'; // bump version for clean sync

  static SharedPreferences? _prefs;
  static Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const Map<String, String> _defaults = {
    'PEMBINA'    : 'PembinaOSIS',
    'KESISWAAN'  : 'KesiswaanBaknus',
    'KETUA'      : 'OSISBN666',
    'WAKIL'      : 'OSISBN666',
    'SEKRETARIS' : 'OSISBN666',
    'BENDAHARA'  : 'OSISBN66',
    'SEKBID1'    : 'KeimananTakwa',
    'SEKBID2'    : 'BudiPekerti',
    'SEKBID3'    : 'Kepribadian',
    'SEKBID4'    : 'PrestasiAkademik',
    'SEKBID5'    : 'Demokrasi',
    'SEKBID6'    : 'Kreativitas',
    'SEKBID7'    : 'Kesehatan',
    'SEKBID8'    : 'SastraBudaya',
    'SEKBID9'    : 'TeknologiInformasi',
    'SEKBID10'   : 'KomunikasiBahasa',
  };

  static Map<String, String>? _accounts;

  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Normalisasi username: trim spasi, hilangkan spasi ganda, dan ubah ke UPPERCASE.
  /// Contoh: 'sekbid 1' -> 'SEKBID1', 'pembina' -> 'PEMBINA', 'sekbid 10' -> 'SEKBID10'
  static String normalizeUsername(String input) {
    String clean = input.trim().toUpperCase();
    // Hilangkan spasi jika formatnya SEKBID X -> SEKBIDX
    clean = clean.replaceAll(RegExp(r'\s+'), '');
    return clean;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _accounts = await _loadAccountsFromCache();
  }

  static Future<Map<String, String>> _loadAccountsFromCache() async {
    final prefs = await _sp;
    final raw = prefs.getStringList(_keyAccounts);
    if (raw == null) {
      final map = Map<String, String>.from(_defaults);
      await prefs.setStringList(
        _keyAccounts,
        map.entries.map((e) => '${e.key}:${e.value}').toList(),
      );
      return map;
    }
    final map = <String, String>{};
    for (final entry in raw) {
      final idx = entry.indexOf(':');
      if (idx < 0) continue;
      map[entry.substring(0, idx).toUpperCase()] = entry.substring(idx + 1);
    }
    // Tambahkan akun baru dari _defaults yang belum ada
    bool changed = false;
    for (final e in _defaults.entries) {
      if (!map.containsKey(e.key)) {
        map[e.key] = e.value;
        changed = true;
      }
    }
    if (changed) {
      await prefs.setStringList(
        _keyAccounts,
        map.entries.map((e) => '${e.key}:${e.value}').toList(),
      );
    }
    return map;
  }

  static Future<void> _saveAccountsToCache() async {
    final prefs = await _sp;
    await prefs.setStringList(
      _keyAccounts,
      (_accounts ?? _defaults).entries.map((e) => '${e.key}:${e.value}').toList(),
    );
  }

  /// Sinkronisasi akun dengan Supabase Cloud.
  /// Mengambil data dari tabel `accounts`. Jika tabel kosong, otomatis memasukkan akun default.
  static Future<bool> syncWithSupabase() async {
    try {
      final client = _supabase;
      if (client == null) return false;

      final rows = await client.from('accounts').select('username, password');
      if (rows.isEmpty) {
        // Tabel ada tapi kosong -> Seed default accounts ke Supabase
        debugPrint('Tabel accounts di Supabase kosong, melakukan initial seed default...');
        final seedData = _defaults.entries.map((e) => {
          'username': e.key,
          'password': e.value,
          'role': e.key,
          'display_name': e.key,
        }).toList();

        await client.from('accounts').upsert(seedData, onConflict: 'username');
        _accounts = Map.from(_defaults);
        await _saveAccountsToCache();
        return true;
      }

      final remoteMap = <String, String>{};
      for (final r in rows) {
        final u = (r['username']?.toString() ?? '').trim().toUpperCase();
        final p = r['password']?.toString() ?? '';
        if (u.isNotEmpty) {
          remoteMap[u] = p;
        }
      }

      // Pastikan akun default penting tetap tersedia jika remote belum memiliki semua
      for (final e in _defaults.entries) {
        if (!remoteMap.containsKey(e.key)) {
          remoteMap[e.key] = e.value;
        }
      }

      _accounts = remoteMap;
      await _saveAccountsToCache();
      debugPrint('AuthService: Berhasil sinkron ${remoteMap.length} akun dari Supabase.');
      return true;
    } catch (e) {
      debugPrint('AuthService syncWithSupabase warning/error: $e');
      return false;
    }
  }

  static List<String> get sekbidList => [
    'SEKBID1', 'SEKBID2', 'SEKBID3', 'SEKBID4', 'SEKBID5',
    'SEKBID6', 'SEKBID7', 'SEKBID8', 'SEKBID9', 'SEKBID10',
  ];

  static Map<String, String> get accounts =>
      Map.unmodifiable(_accounts ?? _defaults);

  /// Autentikasi user dengan pengecekan online Supabase + fallback offline cache.
  static Future<bool> authenticate(String username, String password) async {
    final uname = normalizeUsername(username);
    final pwd = password.trim();

    if (uname.isEmpty || pwd.isEmpty) return false;

    // 1. Cek di remote Supabase terlebih dahulu untuk kredensial terbaru
    try {
      final client = _supabase;
      if (client != null) {
        final rows = await client
            .from('accounts')
            .select('username, password')
            .eq('username', uname)
            .limit(1);

        if (rows.isNotEmpty) {
          final remotePass = rows.first['password']?.toString() ?? '';
          if (remotePass == pwd) {
            _accounts ??= await _loadAccountsFromCache();
            _accounts![uname] = remotePass;
            await _saveAccountsToCache();
            return true;
          } else {
            // Username ditemukan di Supabase tapi password salah
            return false;
          }
        }
      }
    } catch (e) {
      debugPrint('AuthService online auth error (falling back to local cache): $e');
    }

    // 2. Fallback: Cek cache lokal / default
    _accounts ??= await _loadAccountsFromCache();
    final localPass = (_accounts ?? _defaults)[uname];
    if (localPass != null && localPass == pwd) {
      return true;
    }

    return false;
  }

  // Sinkron — instan, pengecekan lokal
  static bool checkPassword(String username, String password) {
    final uname = normalizeUsername(username);
    return (_accounts ?? _defaults)[uname] == password.trim();
  }

  static Future<void> changePassword(String username, String newPassword) async {
    final uname = normalizeUsername(username);
    final nPass = newPassword.trim();
    final acc = Map<String, String>.from(_accounts ?? _defaults);
    acc[uname] = nPass;
    _accounts = acc;
    await _saveAccountsToCache();

    // Simpan ke Supabase jika terhubung
    try {
      final client = _supabase;
      if (client != null) {
        await client.from('accounts').upsert({
          'username': uname,
          'password': nPass,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'username');
        await DataService.broadcastDataChange('accounts');
      }
    } catch (e) {
      debugPrint('Error updating password to Supabase: $e');
    }
  }

  static Future<void> renameUser(String oldName, String newName) async {
    final oldU = normalizeUsername(oldName);
    final newU = normalizeUsername(newName);
    final acc = Map<String, String>.from(_accounts ?? _defaults);
    if (!acc.containsKey(oldU)) return;
    final pass = acc.remove(oldU)!;
    acc[newU] = pass;
    _accounts = acc;
    await _saveAccountsToCache();

    try {
      final client = _supabase;
      if (client != null) {
        await client.from('accounts').delete().eq('username', oldU);
        await client.from('accounts').upsert({
          'username': newU,
          'password': pass,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'username');
        await DataService.broadcastDataChange('accounts');
      }
    } catch (e) {
      debugPrint('Error renaming user in Supabase: $e');
    }
  }

  static Future<void> resetAccounts() async {
    _accounts = Map.from(_defaults);
    await _saveAccountsToCache();

    try {
      final client = _supabase;
      if (client != null) {
        final seedData = _defaults.entries.map((e) => {
          'username': e.key,
          'password': e.value,
          'role': e.key,
          'display_name': e.key,
          'updated_at': DateTime.now().toIso8601String(),
        }).toList();
        await client.from('accounts').upsert(seedData, onConflict: 'username');
        await DataService.broadcastDataChange('accounts');
      }
    } catch (e) {
      debugPrint('Error resetting accounts to Supabase: $e');
    }
  }

  // Simpan sesi di background, tidak blocking navigasi
  static void saveSession(String uname) {
    final normalized = normalizeUsername(uname);
    _sp.then((p) => Future.wait([
      p.setBool(_keyLoggedIn, true),
      p.setString(_keyUserName, normalized),
    ]));
  }

  static Future<bool> isLoggedIn() async {
    final p = await _sp;
    return p.getBool(_keyLoggedIn) ?? false;
  }

  static Future<void> logout() async {
    final p = await _sp;
    await Future.wait([p.remove(_keyLoggedIn), p.remove(_keyUserName)]);
  }

  static Future<String?> getUserName() async {
    final p = await _sp;
    return p.getString(_keyUserName);
  }
}
