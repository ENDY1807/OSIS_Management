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

  // Module Config Controllers
  final _sp1Ctrl = TextEditingController();
  final _sp2Ctrl = TextEditingController();
  final _sp3Ctrl = TextEditingController();
  final _skorsingCtrl = TextEditingController();
  final _arsipMaxMbCtrl = TextEditingController();
  List<String> _arsipFolders = [];
  List<String> _sekbidList = [];
  List<String> _laporanCategories = [];

  // PDF / Document Controllers
  final _schoolNameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _academicYearCtrl = TextEditingController();
  final _kepsekNameCtrl = TextEditingController();
  final _kepsekNipCtrl = TextEditingController();
  final _pembinaNameCtrl = TextEditingController();
  final _pembinaNipCtrl = TextEditingController();
  final _ketosNameCtrl = TextEditingController();
  final _ketosNisCtrl = TextEditingController();
  final _sekretarisNameCtrl = TextEditingController();
  final _sekretarisNisCtrl = TextEditingController();

  bool _saving = false;
  bool _isSyncing = false;
  StreamSubscription<String>? _dataSub;
  List<AppAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);

    // Load Branding
    _appNameCtrl.text = AppSettingsService.appNameNotifier.value;
    _appSubtitleCtrl.text = AppSettingsService.appSubtitleNotifier.value;
    _logoUrlCtrl.text = AppSettingsService.logoUrlNotifier.value;
    _selectedAccent = AppSettingsService.accentColorNotifier.value;
    _hexColorCtrl.text = '#${_selectedAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    _selectedLanguages = List<String>.from(AppSettingsService.enabledLanguagesNotifier.value);

    // Load Module Configs
    _sp1Ctrl.text = AppSettingsService.sp1ThresholdNotifier.value.toString();
    _sp2Ctrl.text = AppSettingsService.sp2ThresholdNotifier.value.toString();
    _sp3Ctrl.text = AppSettingsService.sp3ThresholdNotifier.value.toString();
    _skorsingCtrl.text = AppSettingsService.skorsingThresholdNotifier.value.toString();
    _arsipMaxMbCtrl.text = AppSettingsService.arsipMaxMbNotifier.value.toString();
    _arsipFolders = List<String>.from(AppSettingsService.arsipFoldersNotifier.value);
    _sekbidList = List<String>.from(AppSettingsService.sekbidListNotifier.value);
    _laporanCategories = List<String>.from(AppSettingsService.laporanCategoriesNotifier.value);

    // Load PDF / Signatures
    _schoolNameCtrl.text = AppSettingsService.schoolNameNotifier.value;
    _cityCtrl.text = AppSettingsService.cityNotifier.value;
    _academicYearCtrl.text = AppSettingsService.academicYearNotifier.value;
    _kepsekNameCtrl.text = AppSettingsService.kepsekNameNotifier.value;
    _kepsekNipCtrl.text = AppSettingsService.kepsekNipNotifier.value;
    _pembinaNameCtrl.text = AppSettingsService.pembinaNameNotifier.value;
    _pembinaNipCtrl.text = AppSettingsService.pembinaNipNotifier.value;
    _ketosNameCtrl.text = AppSettingsService.ketosNameNotifier.value;
    _ketosNisCtrl.text = AppSettingsService.ketosNisNotifier.value;
    _sekretarisNameCtrl.text = AppSettingsService.sekretarisNameNotifier.value;
    _sekretarisNisCtrl.text = AppSettingsService.sekretarisNisNotifier.value;

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

    _sp1Ctrl.dispose();
    _sp2Ctrl.dispose();
    _sp3Ctrl.dispose();
    _skorsingCtrl.dispose();
    _arsipMaxMbCtrl.dispose();

    _schoolNameCtrl.dispose();
    _cityCtrl.dispose();
    _academicYearCtrl.dispose();
    _kepsekNameCtrl.dispose();
    _kepsekNipCtrl.dispose();
    _pembinaNameCtrl.dispose();
    _pembinaNipCtrl.dispose();
    _ketosNameCtrl.dispose();
    _ketosNisCtrl.dispose();
    _sekretarisNameCtrl.dispose();
    _sekretarisNisCtrl.dispose();

    _dataSub?.cancel();
    super.dispose();
  }

  void _loadAccounts() {
    setState(() {
      _accounts = AuthService.allAccounts;
    });
  }

  Future<void> _saveAllConfigs() async {
    setState(() => _saving = true);

    // 1. Save Branding & Color
    await AppSettingsService.setAppBranding(
      name: _appNameCtrl.text.trim(),
      subtitle: _appSubtitleCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
      globalColor: _selectedAccent,
      enabledLanguages: _selectedLanguages.isEmpty ? ['id'] : _selectedLanguages,
    );

    // 2. Save Module & PDF Configs
    await AppSettingsService.saveAdminConfigs(
      schoolName: _schoolNameCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      academicYear: _academicYearCtrl.text.trim(),
      kepsekName: _kepsekNameCtrl.text.trim(),
      kepsekNip: _kepsekNipCtrl.text.trim(),
      pembinaName: _pembinaNameCtrl.text.trim(),
      pembinaNip: _pembinaNipCtrl.text.trim(),
      ketosName: _ketosNameCtrl.text.trim(),
      ketosNis: _ketosNisCtrl.text.trim(),
      sekretarisName: _sekretarisNameCtrl.text.trim(),
      sekretarisNis: _sekretarisNisCtrl.text.trim(),
      sp1: int.tryParse(_sp1Ctrl.text.trim()) ?? 20,
      sp2: int.tryParse(_sp2Ctrl.text.trim()) ?? 50,
      sp3: int.tryParse(_sp3Ctrl.text.trim()) ?? 75,
      skorsing: int.tryParse(_skorsingCtrl.text.trim()) ?? 100,
      arsipMaxMb: int.tryParse(_arsipMaxMbCtrl.text.trim()) ?? 25,
      arsipFolders: _arsipFolders,
      sekbidList: _sekbidList,
      laporanCategories: _laporanCategories,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              child: Text(LocalizationService.tr('btn_cancel')),
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
        content: Text('Akun "${acc.displayName}" (${acc.username}) akan dihapus permanen.'),
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

  void _showAddListItemDialog({required String title, required Function(String) onAdd}) {
    final textC = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textC,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nama Item Baru', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(LocalizationService.tr('btn_cancel'))),
          ElevatedButton(
            onPressed: () {
              if (textC.text.trim().isNotEmpty) {
                onAdd(textC.text.trim());
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: Text(LocalizationService.tr('btn_add')),
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
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 24),
            const SizedBox(width: 10),
            Text(LocalizationService.tr('admin_config'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveAllConfigs,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_done_rounded, size: 18),
              label: Text(_saving ? (LocalizationService.currentLocale.value.languageCode == 'en' ? 'Saving...' : 'Menyimpan...') : LocalizationService.tr('btn_save_changes')),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: [
            Tab(text: LocalizationService.tr('tab_branding'), icon: const Icon(Icons.palette_outlined, size: 18)),
            Tab(text: LocalizationService.tr('tab_module_configs'), icon: const Icon(Icons.tune_rounded, size: 18)),
            Tab(text: LocalizationService.tr('tab_signatures'), icon: const Icon(Icons.description_outlined, size: 18)),
            Tab(text: LocalizationService.tr('tab_accounts'), icon: const Icon(Icons.manage_accounts_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildBrandingTab(theme, isDark, primary),
          _buildModuleConfigsTab(theme, isDark, primary),
          _buildSignaturesTab(theme, isDark, primary),
          _buildAccountsTab(theme, isDark, primary),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: TEMA & BRANDING (LUXURY COLOR PICKER)
  // ==========================================
  Widget _buildBrandingTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. LIVE PREVIEW CARD MOCKUP
          Text(
            LocalizationService.tr('live_preview').toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _selectedAccent),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _selectedAccent.withAlpha(isDark ? 55 : 30),
                  _selectedAccent.withAlpha(isDark ? 20 : 10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _selectedAccent.withAlpha(120), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _selectedAccent.withAlpha(isDark ? 40 : 25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _selectedAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _selectedAccent.withAlpha(120), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _appNameCtrl.text.isEmpty ? 'OSIS Management' : _appNameCtrl.text,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            _appSubtitleCtrl.text.isEmpty ? 'Sistem Manajemen Digital' : _appSubtitleCtrl.text,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _selectedAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Aktif', style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.touch_app_rounded, size: 16),
                        label: const Text('Tombol Utama', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _selectedAccent, width: 1.5),
                        foregroundColor: _selectedAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Aksen Sekunder', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 2. RODA WARNA INTERAKTIF (COLOR WHEEL PICKER)
          Text(
            LocalizationService.tr('palette_wheel_title').toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: _selectedAccent),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
            ),
            child: ColorWheelPicker(
              initialColor: _selectedAccent,
              onColorChanged: (newColor) {
                setState(() {
                  _selectedAccent = newColor;
                  _hexColorCtrl.text = '#${newColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                });
              },
            ),
          ),
          const SizedBox(height: 24),

          // 3. PALET PRESET GRIDS
          Text(
            LocalizationService.tr('palette_presets').toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: primary),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 74,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: AppSettingsService.presets.length,
            itemBuilder: (context, i) {
              final preset = AppSettingsService.presets[i];
              final isSelected = _selectedAccent.toARGB32() == preset.color.toARGB32();

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedAccent = preset.color;
                    _hexColorCtrl.text = '#${preset.color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? preset.color.withAlpha(isDark ? 60 : 30) : theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? preset.color : (isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
                      width: isSelected ? 2.2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [preset.color, preset.darkColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          preset.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? preset.color : theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 4. IDENTITAS BRANDING SISTEM
          Text(
            'IDENTITAS SISTEM & INSTANSI',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: primary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appNameCtrl,
            decoration: const InputDecoration(labelText: 'Nama Aplikasi Utama', prefixIcon: Icon(Icons.title_rounded)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _appSubtitleCtrl,
            decoration: const InputDecoration(labelText: 'Subtitle / Tagline Instansi', prefixIcon: Icon(Icons.subtitles_outlined)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _logoUrlCtrl,
            decoration: const InputDecoration(labelText: 'URL Gambar Logo Kustom', prefixIcon: Icon(Icons.image_outlined)),
          ),
          const SizedBox(height: 24),

          // 5. BAHASA YANG DIAKTIFKAN
          Text(
            'BAHASA TERSEDIA UNTUK PENGGUNA',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: primary),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < LocalizationService.allSupportedLanguages.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
                  CheckboxListTile(
                    secondary: Text(LocalizationService.allSupportedLanguages[i].flag, style: const TextStyle(fontSize: 22)),
                    title: Text(LocalizationService.allSupportedLanguages[i].name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('Kode: ${LocalizationService.allSupportedLanguages[i].code}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    value: _selectedLanguages.contains(LocalizationService.allSupportedLanguages[i].code),
                    activeColor: _selectedAccent,
                    onChanged: (val) {
                      setState(() {
                        final code = LocalizationService.allSupportedLanguages[i].code;
                        if (val == true) {
                          if (!_selectedLanguages.contains(code)) _selectedLanguages.add(code);
                        } else {
                          if (_selectedLanguages.length > 1) {
                            _selectedLanguages.remove(code);
                          }
                        }
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: KONFIGURASI MODUL & FITUR
  // ==========================================
  Widget _buildModuleConfigsTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // SEKSI 1: PELANGGARAN POIN
          _sectionHeader(title: LocalizationService.tr('admin_section_pelanggaran'), icon: Icons.warning_amber_rounded, color: Colors.redAccent),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sp1Ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Batas Poin SP 1', prefixIcon: Icon(Icons.looks_one_outlined)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _sp2Ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Batas Poin SP 2', prefixIcon: Icon(Icons.looks_two_outlined)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _sp3Ctrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Batas SP 3 / Panggilan Ortu', prefixIcon: Icon(Icons.looks_3_outlined)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _skorsingCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Batas Skorsing / Sidang', prefixIcon: Icon(Icons.gavel_rounded)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SEKSI 2: ARSIP DOKUMEN & BERKAS
          _sectionHeader(title: LocalizationService.tr('admin_section_arsip'), icon: Icons.folder_special_rounded, color: Colors.blue),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _arsipMaxMbCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Maksimal Ukuran Unggah Berkas (MB)', prefixIcon: Icon(Icons.cloud_upload_outlined)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Folder Standar Arsip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.blue),
                      onPressed: () => _showAddListItemDialog(
                        title: 'Tambah Folder Arsip Standar',
                        onAdd: (item) => _arsipFolders.add(item),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _arsipFolders.map((f) {
                    return Chip(
                      avatar: const Icon(Icons.folder_rounded, size: 16, color: Colors.blue),
                      label: Text(f, style: const TextStyle(fontSize: 11.5)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () => setState(() => _arsipFolders.remove(f)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SEKSI 3: PROKER & SEKBID
          _sectionHeader(title: LocalizationService.tr('admin_section_proker'), icon: Icons.assignment_turned_in_rounded, color: Colors.teal),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Daftar Sekbid & Divisi Terdaftar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.teal),
                      onPressed: () => _showAddListItemDialog(
                        title: 'Tambah Sekbid / Divisi Baru',
                        onAdd: (item) => _sekbidList.add(item),
                      ),
                    ),
                  ],
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sekbidList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = _sekbidList[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.group_work_outlined, size: 18, color: Colors.teal),
                      title: Text(item, style: const TextStyle(fontSize: 12.5)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                        onPressed: () => setState(() => _sekbidList.remove(item)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // SEKSI 4: LAPORAN KEGIATAN & LPJ
          _sectionHeader(title: LocalizationService.tr('admin_section_laporan'), icon: Icons.article_rounded, color: Colors.purple),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kategori Laporan Kegiatan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.purple),
                      onPressed: () => _showAddListItemDialog(
                        title: 'Tambah Kategori Laporan',
                        onAdd: (item) => _laporanCategories.add(item),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _laporanCategories.map((c) {
                    return Chip(
                      avatar: const Icon(Icons.bookmark_outline_rounded, size: 16, color: Colors.purple),
                      label: Text(c, style: const TextStyle(fontSize: 11.5)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 14),
                      onDeleted: () => setState(() => _laporanCategories.remove(c)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: KOP SURAT & TANDA TANGAN PDF
  // ==========================================
  Widget _buildSignaturesTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title: 'Kop Surat & Titimangsa Instansi', icon: Icons.location_city_rounded, color: Colors.indigo),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _schoolNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Sekolah / Lembaga Lengkap', prefixIcon: Icon(Icons.school_outlined)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cityCtrl,
                        decoration: const InputDecoration(labelText: 'Kota / Lokasi Surat', prefixIcon: Icon(Icons.location_on_outlined)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _academicYearCtrl,
                        decoration: const InputDecoration(labelText: 'Tahun Ajaran / Periode', prefixIcon: Icon(Icons.date_range_outlined)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _sectionHeader(title: 'Tanda Tangan Pejabat & Pengurus (Ekspor PDF)', icon: Icons.draw_rounded, color: Colors.deepOrange),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kepala Sekolah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange)),
                const SizedBox(height: 6),
                TextField(
                  controller: _kepsekNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Kepala Sekolah Lengkap & Gelar', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _kepsekNipCtrl,
                  decoration: const InputDecoration(labelText: 'NIP Kepala Sekolah', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const Divider(height: 28),

                const Text('Pembina OSIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange)),
                const SizedBox(height: 6),
                TextField(
                  controller: _pembinaNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Pembina OSIS Lengkap', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pembinaNipCtrl,
                  decoration: const InputDecoration(labelText: 'NIP Pembina OSIS', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const Divider(height: 28),

                const Text('Ketua OSIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange)),
                const SizedBox(height: 6),
                TextField(
                  controller: _ketosNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Ketua OSIS', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ketosNisCtrl,
                  decoration: const InputDecoration(labelText: 'NIS Ketua OSIS', prefixIcon: Icon(Icons.badge_outlined)),
                ),
                const Divider(height: 28),

                const Text('Sekretaris OSIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepOrange)),
                const SizedBox(height: 6),
                TextField(
                  controller: _sekretarisNameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Sekretaris OSIS', prefixIcon: Icon(Icons.person_outline_rounded)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sekretarisNisCtrl,
                  decoration: const InputDecoration(labelText: 'NIS Sekretaris OSIS', prefixIcon: Icon(Icons.badge_outlined)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 4: KELOLA AKUN & HAK AKSES
  // ==========================================
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
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
      ],
    );
  }

  Widget _sectionHeader({required String title, required IconData icon, required Color color}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.0, color: color),
        ),
      ],
    );
  }
}
