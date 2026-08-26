import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/data_service.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _appNameCtrl = TextEditingController();
  final _appSubtitleCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  Color _selectedAccent = const Color(0xFF00B4D8);
  bool _savingBranding = false;
  bool _isSyncing = false;
  StreamSubscription<String>? _dataSub;
  List<AppAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _appNameCtrl.text = AppSettingsService.appNameNotifier.value;
    _appSubtitleCtrl.text = AppSettingsService.appSubtitleNotifier.value;
    _logoUrlCtrl.text = AppSettingsService.logoUrlNotifier.value;
    _selectedAccent = AppSettingsService.accentColorNotifier.value;

    _loadAccounts();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'accounts' || table == 'app_settings' || table == 'all') {
        if (mounted) _loadAccounts();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _appNameCtrl.dispose();
    _appSubtitleCtrl.dispose();
    _logoUrlCtrl.dispose();
    _dataSub?.cancel();
    super.dispose();
  }

  void _loadAccounts() {
    setState(() {
      _accounts = AuthService.allAccounts;
    });
  }

  Future<void> _saveBranding() async {
    setState(() => _savingBranding = true);
    await AppSettingsService.setAppBranding(
      name: _appNameCtrl.text.trim(),
      subtitle: _appSubtitleCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
      globalColor: _selectedAccent,
    );
    if (!mounted) return;
    setState(() => _savingBranding = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocalizationService.tr('msg_saved')),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _syncAccountsCloud() async {
    setState(() => _isSyncing = true);
    final success = await AuthService.syncWithSupabase();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _accounts = AuthService.allAccounts;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Berhasil sinkronisasi akun dengan Supabase' : 'Gagal sinkronisasi atau offline'),
        backgroundColor: success ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showAddOrEditAccountDialog([AppAccount? existing]) {
    final userC = TextEditingController(text: existing?.username ?? '');
    final passC = TextEditingController(text: existing?.password ?? '');
    final nameC = TextEditingController(text: existing?.displayName ?? '');
    String selectedRole = existing?.role ?? 'SEKBID';
    bool obscure = true;

    final roles = ['ADMIN', 'PEMBINA', 'KESISWAAN', 'KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA', 'SEKBID', 'GURU', 'ANGGOTA'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'Tambah Akun Baru' : 'Edit Akun: ${existing.username}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  TextField(
                    controller: userC,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Username (contoh: SEKBID11, GURU_BK)',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap / Tampilan (Display Name)',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passC,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setD(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: roles.contains(selectedRole) ? selectedRole : 'SEKBID',
                  decoration: const InputDecoration(
                    labelText: 'Hak Akses (Role)',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) {
                    if (v != null) setD(() => selectedRole = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final uname = existing?.username ?? userC.text.trim();
                final pwd = passC.text.trim();
                final dName = nameC.text.trim();
                if (uname.isEmpty || pwd.isEmpty) return;

                final acc = AppAccount(
                  username: uname,
                  password: pwd,
                  role: selectedRole,
                  displayName: dName.isEmpty ? uname : dName,
                );

                await AuthService.saveAccount(acc);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadAccounts();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Akun berhasil disimpan ke Supabase'), backgroundColor: Colors.green),
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(AppAccount acc) {
    if (acc.username == 'ADMIN') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun master ADMIN tidak dapat dihapus'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Akun ${acc.username}?'),
        content: Text('Akun "${acc.displayName}" (${acc.username}) akan dihapus permanen dari Supabase & lokal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await AuthService.deleteAccount(acc.username);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadAccounts();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Akun ${acc.username} berhasil dihapus'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Hapus Akun'),
          ),
        ],
      ),
    );
  }

  void _showResetAccountsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Semua Akun ke Default?'),
        content: const Text('Seluruh akun (termasuk ADMIN, PEMBINA, KESISWAAN, KETUA, dsb.) akan dikembalikan ke konfigurasi dan password bawaan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await AuthService.resetAccounts();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadAccounts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Semua akun telah direset ke default'), backgroundColor: Colors.orange),
              );
            },
            child: const Text('Reset Semua'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('Panel Super Admin & Konfigurasi'),
          ],
        ),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Tema & Branding', icon: Icon(Icons.palette_outlined, size: 18)),
            Tab(text: 'Kelola Akun', icon: Icon(Icons.manage_accounts_outlined, size: 18)),
            Tab(text: 'Sistem & Hak Akses', icon: Icon(Icons.security_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // TAB 1: BRANDING & TEMA
          _buildBrandingTab(theme, isDark, primary),

          // TAB 2: KELOLA AKUN
          _buildAccountsTab(theme, isDark, primary),

          // TAB 3: SISTEM & MATRIX AKSES
          _buildSystemMatrixTab(theme, isDark, primary),
        ],
      ),
    );
  }

  Widget _buildBrandingTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primary.withAlpha(isDark ? 80 : 40), primary.withAlpha(isDark ? 40 : 15)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withAlpha(80)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: primary, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kustomisasi Identitas & Tema Sistem',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Perubahan nama, subtitle, dan warna tema akan disinkronkan ke cloud untuk seluruh pengguna.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // NAMA APLIKASI
          TextField(
            controller: _appNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Aplikasi / Judul Utama',
              prefixIcon: Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 14),

          // SUBTITLE
          TextField(
            controller: _appSubtitleCtrl,
            decoration: const InputDecoration(
              labelText: 'Subtitle / Instansi (contoh: OSIS SMK Bakti Nusantara 666)',
              prefixIcon: Icon(Icons.subtitles_outlined),
            ),
          ),
          const SizedBox(height: 14),

          // LOGO URL
          TextField(
            controller: _logoUrlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL Logo Kustom (Kosongkan untuk logo bawaan)',
              prefixIcon: Icon(Icons.image_outlined),
            ),
          ),
          const SizedBox(height: 24),

          // PALET WARNA UTAMA
          const Text(
            'WARNA AKSEN UTAMA SISTEM',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: AppSettingsService.presets.map((p) {
              final isSelected = _selectedAccent.value == p.color.value;
              return InkWell(
                onTap: () => setState(() => _selectedAccent = p.color),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? p.color.withAlpha(isDark ? 80 : 35) : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? p.color : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: p.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: p.color.withAlpha(100), blurRadius: 4, offset: const Offset(0, 1)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? p.color : null,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),

          // TOMBOL SIMPAN
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _savingBranding ? null : _saveBranding,
              icon: _savingBranding
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_savingBranding ? 'Menyimpan ke Supabase...' : 'Terapkan & Simpan Konfigurasi'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsTab(ThemeData theme, bool isDark, Color primary) {
    return Column(
      children: [
        Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daftar Akun (${_accounts.length} Akun)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Text('Kelola role, display name, & password', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              IconButton(
                icon: _isSyncing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.sync_rounded),
                tooltip: 'Sinkronisasi Cloud',
                onPressed: _isSyncing ? null : _syncAccountsCloud,
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddOrEditAccountDialog(),
                icon: const Icon(Icons.person_add_rounded, size: 16),
                label: const Text('Tambah Akun', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: _accounts.length,
            itemBuilder: (_, i) {
              final acc = _accounts[i];
              Color badgeColor;
              switch (acc.role) {
                case 'ADMIN':
                  badgeColor = Colors.amber;
                  break;
                case 'PEMBINA':
                case 'KESISWAAN':
                  badgeColor = Colors.purple;
                  break;
                case 'KETUA':
                case 'WAKIL':
                case 'SEKRETARIS':
                case 'BENDAHARA':
                  badgeColor = Colors.blue;
                  break;
                default:
                  badgeColor = Colors.teal;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: badgeColor.withAlpha(30),
                    child: Text(
                      acc.username.isNotEmpty ? acc.username.substring(0, 1) : '?',
                      style: TextStyle(fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(acc.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withAlpha(100)),
                        ),
                        child: Text(
                          acc.role,
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${acc.displayName} • Password: ●●●●●●',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                        tooltip: 'Edit Akun',
                        onPressed: () => _showAddOrEditAccountDialog(acc),
                      ),
                      if (acc.username != 'ADMIN')
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          tooltip: 'Hapus Akun',
                          onPressed: () => _showDeleteAccountDialog(acc),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showResetAccountsDialog,
                  icon: const Icon(Icons.restart_alt_rounded, color: Colors.red, size: 18),
                  label: const Text('Reset Akun Bawaan', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSystemMatrixTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Matriks Hak Akses & Peran (Role-Based Access Control)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _roleMatrixCard(
            role: 'ADMIN (Super Admin)',
            color: Colors.amber,
            desc: 'Akses tanpa batas ke seluruh modul aplikasi, konfigurasi identitas/branding, warna tema, manajemen seluruh akun, data siswa, pelanggaran, arsip, laporan, dan proker.',
          ),
          const SizedBox(height: 10),
          _roleMatrixCard(
            role: 'PEMBINA & KESISWAAN',
            color: Colors.purple,
            desc: 'Akses supervisi penuh atas Proker, Laporan Kegiatan, Manajemen Siswa, Jenis Pelanggaran, Status Cloud, Rekap Data, Arsip, dan Notifikasi Seluruh Aktivitas.',
          ),
          const SizedBox(height: 10),
          _roleMatrixCard(
            role: 'BPH (KETUA, WAKIL, SEKRETARIS, BENDAHARA)',
            color: Colors.blue,
            desc: 'Akses kelola data proker, laporan, siswa, jenis pelanggaran, arsip umum, rekap data, dan notifikasi real-time.',
          ),
          const SizedBox(height: 10),
          _roleMatrixCard(
            role: 'SEKBID (SEKBID 1 - 10)',
            color: Colors.teal,
            desc: 'Akses pembuatan & update proker sekbid terkait, upload laporan kegiatan, penginputan pelanggaran tata tertib (khusus Sekbid 2 kelola jenis), dan akses arsip/rekap.',
          ),
        ],
      ),
    );
  }

  Widget _roleMatrixCard({required String role, required Color color, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(role, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(fontSize: 11.5, height: 1.4)),
        ],
      ),
    );
  }
}
