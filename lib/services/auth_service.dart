import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data_service.dart';
import 'sync_service.dart';
import 'app_settings_service.dart';

class AppAccount {
  final String username;
  final String password;
  final String role;
  final String displayName;

  const AppAccount({
    required this.username,
    required this.password,
    required this.role,
    required this.displayName,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'role': role,
    'display_name': displayName,
  };

  factory AppAccount.fromJson(Map<String, dynamic> json) => AppAccount(
    username: json['username']?.toString() ?? '',
    password: json['password']?.toString() ?? '',
    role: json['role']?.toString() ?? 'SEKBID',
    displayName: json['display_name']?.toString() ?? json['username']?.toString() ?? '',
  );
}

class AuthService {
  static const _keyLoggedIn    = 'logged_in';
  static const _keyUserName    = 'user_name';
  static const _keyDisplayName = 'user_display_name';
  static const _keyUserRole    = 'user_role';
  static const _keyAccounts    = 'accounts_v5'; // bump version for clean display_name sync

  static SharedPreferences? _prefs;
  static Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  static const Map<String, String> _defaults = {
    'ADMIN'      : 'EndyMahavira24!!@',
    'PEMBINA'    : 'PembinaOSIS',
    'KESISWAAN'  : 'KesiswaanBaknus',
    'KETUA'      : 'OSISBN666',
    'WAKIL'      : 'OSISBN666',
    'SEKRETARIS' : 'OSISBN666',
    'BENDAHARA'  : 'OSISBN666',
    'SEKBID1'    : 'KeimananTakwa',
    'SEKBID2'    : 'BudiPekerti',
    'SEKBID3'    : 'Bela Negara',
    'SEKBID4'    : 'PrestasiAkademik',
    'SEKBID5'    : 'Demokrasi',
    'SEKBID6'    : 'Kewirausahaan',
    'SEKBID7'    : 'KebugaranJasmani',
    'SEKBID8'    : 'SastraBudaya',
    'SEKBID9'    : 'TeknologiInformasi',
    'SEKBID10'   : 'KomunikasiBahasa',
  };

  static const Map<String, String> defaultDisplayNames = {
    'ADMIN'      : 'Admin Aplikasi OSIS Management',
    'PEMBINA'    : 'Pembina OSIS',
    'KESISWAAN'  : 'Staf Kesiswaan',
    'KETUA'      : 'Ketua OSIS',
    'WAKIL'      : 'Wakil Ketua OSIS',
    'SEKRETARIS' : 'Sekretaris OSIS',
    'BENDAHARA'  : 'Bendahara OSIS',
    'SEKBID1'    : 'Sekbid 1 (Keimanan & Ketakwaan)',
    'SEKBID2'    : 'Sekbid 2 (Budi Pekerti)',
    'SEKBID3'    : 'Sekbid 3 (Bela Negara)',
    'SEKBID4'    : 'Sekbid 4 (Prestasi Akademik)',
    'SEKBID5'    : 'Sekbid 5 (Demokrasi)',
    'SEKBID6'    : 'Sekbid 6 (Kewirausahaan)',
    'SEKBID7'    : 'Sekbid 7 (Kebugaran Jasmani)',
    'SEKBID8'    : 'Sekbid 8 (Sastra & Budaya)',
    'SEKBID9'    : 'Sekbid 9 (Teknologi Informasi)',
    'SEKBID10'   : 'Sekbid 10 (Komunikasi & Bahasa)',
  };

  static Map<String, AppAccount>? _accountDetails;

  static SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Normalisasi username: trim spasi, hilangkan spasi ganda, dan ubah ke UPPERCASE.
  static String normalizeUsername(String input) {
    String clean = input.trim().toUpperCase();
    clean = clean.replaceAll(RegExp(r'\s+'), '');
    return clean;
  }

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAccountsFromCache();
    // Non-blocking sync with Supabase
    syncWithSupabase();
  }

  static Future<Map<String, String>> _loadAccountsFromCache() async {
    final prefs = await _sp;
    final raw = prefs.getStringList(_keyAccounts);
    _accountDetails = {};

    if (raw == null) {
      for (final e in _defaults.entries) {
        _accountDetails![e.key] = AppAccount(
          username: e.key,
          password: e.value,
          role: e.key,
          displayName: defaultDisplayNames[e.key] ?? e.key,
        );
      }
      await _saveAccountsToCache();
      return _defaults;
    }

    final map = <String, String>{};
    for (final entry in raw) {
      // Format: username:::password:::role:::displayName
      final parts = entry.split(':::');
      if (parts.isNotEmpty) {
        final u = parts[0].toUpperCase();
        final p = parts.length > 1 ? parts[1] : (_defaults[u] ?? '');
        final r = parts.length > 2 ? parts[2] : u;
        final d = parts.length > 3 ? parts[3] : (defaultDisplayNames[u] ?? u);

        map[u] = p;
        _accountDetails![u] = AppAccount(username: u, password: p, role: r, displayName: d);
      }
    }

    // Pastikan semua default accounts ada
    bool changed = false;
    for (final e in _defaults.entries) {
      if (!_accountDetails!.containsKey(e.key)) {
        _accountDetails![e.key] = AppAccount(
          username: e.key,
          password: e.value,
          role: e.key,
          displayName: defaultDisplayNames[e.key] ?? e.key,
        );
        map[e.key] = e.value;
        changed = true;
      }
    }

    if (changed) {
      await _saveAccountsToCache();
    }
    return map;
  }

  static Future<void> _saveAccountsToCache() async {
    final prefs = await _sp;
    final list = <String>[];
    for (final acc in (_accountDetails ?? {}).values) {
      list.add('${acc.username}:::${acc.password}:::${acc.role}:::${acc.displayName}');
    }
    await prefs.setStringList(_keyAccounts, list);
  }

  /// Sinkronisasi akun dengan Supabase Cloud.
  static Future<bool> syncWithSupabase() async {
    try {
      final client = _supabase;
      if (client == null) return false;

      final rows = await client.from('accounts').select('username, password, role, display_name');
      if (rows.isEmpty) {
        debugPrint('Tabel accounts di Supabase kosong, melakukan initial seed default...');
        final seedData = _defaults.entries.map((e) => {
          'username': e.key,
          'password': e.value,
          'role': e.key,
          'display_name': defaultDisplayNames[e.key] ?? e.key,
        }).toList();

        await client.from('accounts').upsert(seedData, onConflict: 'username');
        await _loadAccountsFromCache();
        return true;
      }

      final remoteAccounts = <String, AppAccount>{};
      for (final r in rows) {
        final u = (r['username']?.toString() ?? '').trim().toUpperCase();
        final p = r['password']?.toString() ?? '';
        final role = r['role']?.toString() ?? u;
        final dName = (r['display_name']?.toString() ?? '').trim().isNotEmpty
            ? r['display_name'].toString().trim()
            : (defaultDisplayNames[u] ?? u);

        if (u.isNotEmpty) {
          remoteAccounts[u] = AppAccount(username: u, password: p, role: role, displayName: dName);
        }
      }

      // Pastikan ADMIN & default akun selalu tersedia
      for (final e in _defaults.entries) {
        if (!remoteAccounts.containsKey(e.key)) {
          remoteAccounts[e.key] = AppAccount(
            username: e.key,
            password: e.value,
            role: e.key,
            displayName: defaultDisplayNames[e.key] ?? e.key,
          );
        }
      }

      _accountDetails = remoteAccounts;
      await _saveAccountsToCache();

      // Perbarui juga sesi lokal pengguna yang sedang login jika display_name berubah di Supabase
      final currentU = await getUserName();
      if (currentU != null && remoteAccounts.containsKey(currentU)) {
        final currentAcc = remoteAccounts[currentU]!;
        final p = await _sp;
        await p.setString(_keyDisplayName, currentAcc.displayName);
        await p.setString(_keyUserRole, currentAcc.role);
      }

      debugPrint('AuthService: Berhasil sinkron ${remoteAccounts.length} akun & display_name dari Supabase.');
      return true;
    } catch (e) {
      debugPrint('AuthService syncWithSupabase warning/error: $e');
      return false;
    }
  }

  static List<String> get sekbidList => AppSettingsService.sekbidListNotifier.value;

  static List<String> get prokerUnits {
    final list = <String>[
      'KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA',
    ];
    for (final s in AppSettingsService.sekbidListNotifier.value) {
      if (!list.contains(s)) {
        list.add(s);
      }
    }
    return list;
  }

  static Map<String, String> get accounts {
    final map = <String, String>{};
    for (final e in (_accountDetails ?? {}).entries) {
      map[e.key] = e.value.password;
    }
    return Map.unmodifiable(map.isEmpty ? _defaults : map);
  }

  static List<AppAccount> get allAccounts {
    return (_accountDetails ?? {}).values.toList();
  }

  static AppAccount? getAccount(String username) {
    final u = normalizeUsername(username);
    return _accountDetails?[u];
  }

  static String getDisplayName(String username) {
    final u = normalizeUsername(username);
    final acc = _accountDetails?[u];
    if (acc != null && acc.displayName.trim().isNotEmpty) {
      return acc.displayName;
    }
    if (defaultDisplayNames.containsKey(u)) {
      return defaultDisplayNames[u]!;
    }
    if (u == 'KETUA') return 'Ketua OSIS';
    if (u == 'WAKIL') return 'Wakil Ketua OSIS';
    if (u == 'SEKRETARIS') return 'Sekretaris OSIS';
    if (u == 'BENDAHARA') return 'Bendahara OSIS';
    return username;
  }

  static String getRole(String username) {
    final u = normalizeUsername(username);
    return _accountDetails?[u]?.role ?? (u.startsWith('SEKBID') ? 'SEKBID' : u);
  }

  /// Autentikasi user dengan pengecekan online Supabase + fallback offline cache.
  static Future<bool> authenticate(String username, String password) async {
    final uname = normalizeUsername(username);
    final pwd = password.trim();

    if (uname.isEmpty || pwd.isEmpty) return false;

    // 1. Cek di remote Supabase terlebih dahulu untuk kredensial dan display_name terbaru
    try {
      final client = _supabase;
      if (client != null) {
        final rows = await client
            .from('accounts')
            .select('username, password, role, display_name')
            .eq('username', uname)
            .limit(1);

        if (rows.isNotEmpty) {
          final remotePass = rows.first['password']?.toString() ?? '';
          if (remotePass == pwd) {
            final role = rows.first['role']?.toString() ?? uname;
            final rawDName = rows.first['display_name']?.toString() ?? '';
            final dName = rawDName.trim().isNotEmpty ? rawDName.trim() : (defaultDisplayNames[uname] ?? uname);

            _accountDetails ??= {};
            _accountDetails![uname] = AppAccount(username: uname, password: remotePass, role: role, displayName: dName);
            await _saveAccountsToCache();
            saveSession(uname, displayName: dName, role: role);
            return true;
          } else {
            return false;
          }
        }
      }
    } catch (e) {
      debugPrint('AuthService online auth error (falling back to local cache): $e');
    }

    // 2. Fallback: Cek cache lokal / default
    if (_accountDetails == null || _accountDetails!.isEmpty) {
      await _loadAccountsFromCache();
    }
    final localAcc = _accountDetails?[uname];
    if (localAcc != null && localAcc.password == pwd) {
      saveSession(uname, displayName: localAcc.displayName, role: localAcc.role);
      return true;
    }

    final defaultPass = _defaults[uname];
    if (defaultPass != null && defaultPass == pwd) {
      final dName = defaultDisplayNames[uname] ?? uname;
      saveSession(uname, displayName: dName, role: uname);
      return true;
    }

    return false;
  }

  static bool checkPassword(String username, String password) {
    final uname = normalizeUsername(username);
    final acc = _accountDetails?[uname];
    if (acc != null) return acc.password == password.trim();
    return _defaults[uname] == password.trim();
  }

  static Future<void> changePassword(String username, String newPassword) async {
    final uname = normalizeUsername(username);
    final nPass = newPassword.trim();
    final currentAcc = _accountDetails?[uname];
    final updatedAcc = AppAccount(
      username: uname,
      password: nPass,
      role: currentAcc?.role ?? uname,
      displayName: currentAcc?.displayName ?? defaultDisplayNames[uname] ?? uname,
    );

    _accountDetails ??= {};
    _accountDetails![uname] = updatedAcc;
    await _saveAccountsToCache();

    final dbData = {
      'username': uname,
      'password': nPass,
      'role': updatedAcc.role,
      'display_name': updatedAcc.displayName,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Kirim ke Supabase atau antrekan ke SyncService
    if (SyncService.isOnline) {
      try {
        final client = _supabase;
        if (client != null) {
          await client.from('accounts').upsert(dbData, onConflict: 'username');
          await DataService.broadcastDataChange('accounts');
        }
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'accounts',
          data: dbData,
          targetId: uname,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'accounts',
        data: dbData,
        targetId: uname,
      );
    }
  }

  static Future<void> saveAccount(AppAccount account) async {
    final uname = normalizeUsername(account.username);
    final acc = AppAccount(
      username: uname,
      password: account.password.trim(),
      role: account.role.trim().toUpperCase(),
      displayName: account.displayName.trim().isEmpty ? uname : account.displayName.trim(),
    );

    _accountDetails ??= {};
    _accountDetails![uname] = acc;
    await _saveAccountsToCache();

    final dbData = {
      'username': uname,
      'password': acc.password,
      'role': acc.role,
      'display_name': acc.displayName,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (SyncService.isOnline) {
      try {
        final client = _supabase;
        if (client != null) {
          await client.from('accounts').upsert(dbData, onConflict: 'username');
          await DataService.broadcastDataChange('accounts');
        }
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'accounts',
          data: dbData,
          targetId: uname,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.upsert,
        table: 'accounts',
        data: dbData,
        targetId: uname,
      );
    }
  }

  static Future<void> deleteAccount(String username) async {
    final uname = normalizeUsername(username);
    if (uname == 'ADMIN') return;

    _accountDetails?.remove(uname);
    await _saveAccountsToCache();

    if (SyncService.isOnline) {
      try {
        final client = _supabase;
        if (client != null) {
          await client.from('accounts').delete().eq('username', uname);
          await DataService.broadcastDataChange('accounts');
        }
      } catch (e) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.delete,
          table: 'accounts',
          targetId: uname,
        );
      }
    } else {
      await SyncService.enqueueAction(
        actionType: SyncActionType.delete,
        table: 'accounts',
        targetId: uname,
      );
    }
  }

  static Future<void> resetAccounts() async {
    _accountDetails = {};
    for (final e in _defaults.entries) {
      _accountDetails![e.key] = AppAccount(
        username: e.key,
        password: e.value,
        role: e.key,
        displayName: defaultDisplayNames[e.key] ?? e.key,
      );
    }
    await _saveAccountsToCache();

    final seedData = _defaults.entries.map((e) => {
      'username': e.key,
      'password': e.value,
      'role': e.key,
      'display_name': defaultDisplayNames[e.key] ?? e.key,
      'updated_at': DateTime.now().toIso8601String(),
    }).toList();

    if (SyncService.isOnline) {
      try {
        final client = _supabase;
        if (client != null) {
          await client.from('accounts').upsert(seedData, onConflict: 'username');
          await DataService.broadcastDataChange('accounts');
        }
      } catch (e) {
        for (final item in seedData) {
          await SyncService.enqueueAction(
            actionType: SyncActionType.upsert,
            table: 'accounts',
            data: item,
            targetId: item['username']?.toString(),
          );
        }
      }
    } else {
      for (final item in seedData) {
        await SyncService.enqueueAction(
          actionType: SyncActionType.upsert,
          table: 'accounts',
          data: item,
          targetId: item['username']?.toString(),
        );
      }
    }
  }

  static void saveSession(String uname, {String? displayName, String? role}) {
    final normalized = normalizeUsername(uname);
    final dName = displayName ?? getDisplayName(normalized);
    final r = role ?? getRole(normalized);
    _sp.then((p) => Future.wait([
      p.setBool(_keyLoggedIn, true),
      p.setString(_keyUserName, normalized),
      p.setString(_keyDisplayName, dName),
      p.setString(_keyUserRole, r),
    ]));
  }

  static Future<bool> isLoggedIn() async {
    final p = await _sp;
    return p.getBool(_keyLoggedIn) ?? false;
  }

  static Future<void> logout() async {
    final p = await _sp;
    await Future.wait([
      p.remove(_keyLoggedIn),
      p.remove(_keyUserName),
      p.remove(_keyDisplayName),
      p.remove(_keyUserRole),
    ]);
  }

  static Future<String?> getUserName() async {
    final p = await _sp;
    return p.getString(_keyUserName);
  }

  static Future<String> getCurrentDisplayName() async {
    final p = await _sp;
    final saved = p.getString(_keyDisplayName);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved;
    }
    final uname = p.getString(_keyUserName);
    if (uname != null && uname.isNotEmpty) {
      return getDisplayName(uname);
    }
    return '';
  }

  static Future<String> getCurrentUserRole() async {
    final p = await _sp;
    final saved = p.getString(_keyUserRole);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved;
    }
    final uname = p.getString(_keyUserName);
    if (uname != null && uname.isNotEmpty) {
      return getRole(uname);
    }
    return 'SEKBID';
  }
}
