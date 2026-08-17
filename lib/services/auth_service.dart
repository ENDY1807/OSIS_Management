import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyLoggedIn  = 'logged_in';
  static const _keyUserName  = 'user_name';
  static const _keyAccounts  = 'accounts_v2'; // bump versi agar data lama diabaikan

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
  };

  static Map<String, String>? _accounts;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _accounts = await _loadAccounts();
  }

  static Future<Map<String, String>> _loadAccounts() async {
    final prefs = await _sp;
    final raw = prefs.getStringList(_keyAccounts);
    if (raw == null) {
      // Belum ada data sama sekali — simpan defaults
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
      map[entry.substring(0, idx)] = entry.substring(idx + 1);
    }
    // Tambahkan akun baru dari _defaults yang belum ada, lalu simpan
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

  static Future<void> _saveAccounts() async {
    final prefs = await _sp;
    await prefs.setStringList(
      _keyAccounts,
      (_accounts ?? _defaults).entries.map((e) => '${e.key}:${e.value}').toList(),
    );
  }

  static List<String> get sekbidList => [
    'SEKBID1', 'SEKBID2', 'SEKBID3', 'SEKBID4', 'SEKBID5',
    'SEKBID6', 'SEKBID7', 'SEKBID8', 'SEKBID9', 'SEKBID10',
  ];

  static Map<String, String> get accounts =>
      Map.unmodifiable(_accounts ?? _defaults);

  static Future<void> changePassword(String username, String newPassword) async {
    final acc = Map<String, String>.from(_accounts ?? _defaults);
    if (!acc.containsKey(username)) return;
    acc[username] = newPassword;
    _accounts = acc;
    await _saveAccounts();
  }

  static Future<void> renameUser(String oldName, String newName) async {
    final acc = Map<String, String>.from(_accounts ?? _defaults);
    if (!acc.containsKey(oldName)) return;
    final pass = acc.remove(oldName)!;
    acc[newName.trim().toUpperCase()] = pass;
    _accounts = acc;
    await _saveAccounts();
  }

  static Future<void> resetAccounts() async {
    _accounts = Map.from(_defaults);
    await _saveAccounts();
  }

  // Sinkron — instan, tidak perlu await
  static bool checkPassword(String username, String password) =>
      (_accounts ?? _defaults)[username.trim().toUpperCase()] == password;

  // Simpan sesi di background, tidak blocking navigasi
  static void saveSession(String uname) {
    _sp.then((p) => Future.wait([
      p.setBool(_keyLoggedIn, true),
      p.setString(_keyUserName, uname),
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
