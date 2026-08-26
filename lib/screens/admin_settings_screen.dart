import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/data_service.dart';
import '../widgets/color_wheel_picker.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Branding Controllers
  final _appNameCtrl = TextEditingController();
  final _appSubtitleCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  Color _selectedAccent = const Color(0xFF00B4D8);
  final _hexColorCtrl = TextEditingController();
  List<String> _selectedLanguages = ['id', 'en'];

  bool _saving = false;
  bool _isSyncing = false;
  StreamSubscription<String>? _dataSub;
  List<AppAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    // Load Branding
    _appNameCtrl.text = AppSettingsService.appNameNotifier.value;
    _appSubtitleCtrl.text = AppSettingsService.appSubtitleNotifier.value;
    _logoUrlCtrl.text = AppSettingsService.logoUrlNotifier.value;
    _selectedAccent = AppSettingsService.accentColorNotifier.value;
    _hexColorCtrl.text = '#${_selectedAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    _selectedLanguages = List<String>.from(AppSettingsService.enabledLanguagesNotifier.value);

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
    _hexColorCtrl.dispose();

    _dataSub?.cancel();
    super.dispose();
  }

  void _loadAccounts() {
    if (!mounted) return;
    setState(() => _accounts = AuthService.allAccounts);
  }

  void _onColorChanged(Color color) {
    setState(() {
      _selectedAccent = color;
      _hexColorCtrl.text = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    });
  }

  Future<void> _saveAllConfigs() async {
    setState(() => _saving = true);

    // 1. Save Branding to Cloud & Local
    await AppSettingsService.setAppBranding(
      name: _appNameCtrl.text.trim(),
      subtitle: _appSubtitleCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
      globalColor: _selectedAccent,
      enabledLanguages: _selectedLanguages.isEmpty ? ['id'] : _selectedLanguages,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(LocalizationService.tr('msg_saved'))),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _syncAccountsCloud() async {
    setState(() => _isSyncing = true);
    final success = await AuthService.syncWithSupabase();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _loadAccounts();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Berhasil sinkronisasi akun dengan Supabase' : 'Gagal sinkronisasi atau offline'),
        backgroundColor: success ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showAddOrEditAccountDialog([AppAccount? existing]) {
    final userC = TextEditingController(text: existing?.username);
    final nameC = TextEditingController(text: existing?.displayName);
    final passC = TextEditingController(text: existing?.password);
    String selectedRole = existing?.role ?? 'SEKBID';
    bool obscure = true;

    final roles = ['ADMIN', 'PEMBINA', 'KESISWAAN', 'KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA', 'SEKBID', 'USER'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'Tambah Akun Baru' : 'Edit Akun ${existing.username}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  TextField(
                    controller: userC,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Username (Huruf Kapital, cth: SEKBID11)',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameC,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tampilan / Jabatan Lengkap',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passC,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password Akun',
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
                  onChanged: (v) => setD(() => selectedRole = v ?? 'SEKBID'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(LocalizationService.tr('btn_cancel'))),
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
                  const SnackBar(content: Text('Akun berhasil disimpan'), backgroundColor: Colors.green),
                );
              },
              child: Text(LocalizationService.tr('btn_save')),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(LocalizationService.tr('btn_cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await AuthService.deleteAccount(acc.username);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadAccounts();
            },
            child: Text(LocalizationService.tr('btn_delete')),
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
        title: Text(LocalizationService.tr('admin_config')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveAllConfigs,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(_saving ? '...' : LocalizationService.tr('btn_save_changes')),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(text: LocalizationService.tr('tab_branding'), icon: const Icon(Icons.palette_outlined, size: 18)),
            Tab(text: LocalizationService.tr('tab_accounts'), icon: const Icon(Icons.manage_accounts_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildBrandingTab(theme, isDark, primary),
          _buildAccountsTab(theme, isDark, primary),
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_selectedAccent.withAlpha(50), _selectedAccent.withAlpha(10)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _selectedAccent.withAlpha(120), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _selectedAccent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: _selectedAccent.withAlpha(120), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _appNameCtrl.text.isEmpty ? 'OSIS Management' : _appNameCtrl.text,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _appSubtitleCtrl.text.isEmpty ? 'Sistem Manajemen Digital' : _appSubtitleCtrl.text,
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(title: LocalizationService.tr('theme_color_wheel'), icon: Icons.color_lens_rounded, color: _selectedAccent),
          const SizedBox(height: 12),
          ColorWheelPicker(initialColor: _selectedAccent, onColorChanged: _onColorChanged),
          const SizedBox(height: 20),
          _sectionHeader(title: LocalizationService.tr('color_presets'), icon: Icons.palette_rounded, color: _selectedAccent),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0))),
            child: Wrap(
              spacing: 12, runSpacing: 12,
              children: AppSettingsService.presets.map((p) {
                final isSel = _selectedAccent.toARGB32() == p.color.toARGB32();
                return InkWell(
                  onTap: () => _onColorChanged(p.color),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: isSel ? p.color.withAlpha(40) : Colors.transparent, borderRadius: BorderRadius.circular(30), border: Border.all(color: isSel ? p.color : Colors.grey.shade300)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [p.color, p.darkColor]))),
                        const SizedBox(width: 8),
                        Text(p.name, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.bold : FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(title: LocalizationService.tr('app_identity'), icon: Icons.badge_outlined, color: _selectedAccent),
          const SizedBox(height: 12),
          TextField(controller: _appNameCtrl, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: LocalizationService.tr('app_name_label'), prefixIcon: const Icon(Icons.title_rounded))),
          const SizedBox(height: 12),
          TextField(controller: _appSubtitleCtrl, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: LocalizationService.tr('app_subtitle_label'), prefixIcon: const Icon(Icons.subtitles_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _logoUrlCtrl, decoration: InputDecoration(labelText: LocalizationService.tr('logo_url_label'), prefixIcon: const Icon(Icons.image_outlined))),
        ],
      ),
    );
  }

  Widget _buildAccountsTab(ThemeData theme, bool isDark, Color primary) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(child: Text('Daftar Akun (${_accounts.length})', style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.sync_rounded), onPressed: _isSyncing ? null : _syncAccountsCloud),
              ElevatedButton.icon(onPressed: () => _showAddOrEditAccountDialog(), icon: const Icon(Icons.person_add_rounded, size: 16), label: const Text('Tambah')),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _accounts.length,
            itemBuilder: (_, i) {
              final acc = _accounts[i];
              return ListTile(
                title: Text(acc.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${acc.displayName} • ${acc.role}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showAddOrEditAccountDialog(acc)),
                    if (acc.username != 'ADMIN') IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () => _showDeleteAccountDialog(acc)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader({required String title, required IconData icon, required Color color}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: color)),
      ],
    );
  }
}
