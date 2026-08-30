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

  // 1. Branding Controllers
  final _appNameCtrl = TextEditingController();
  final _appSubtitleCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  Color _selectedAccent = const Color(0xFF00B4D8);
  final _hexColorCtrl = TextEditingController();
  List<String> _selectedLanguages = ['id', 'en'];

  // 2. Tata Tertib & Poin Controllers
  final _sp1Ctrl = TextEditingController();
  final _sp2Ctrl = TextEditingController();
  final _sp3Ctrl = TextEditingController();
  final _skorsingCtrl = TextEditingController();

  // 3. Proker & Laporan Lists
  List<String> _sekbidList = [];
  List<String> _laporanCategories = [];
  List<String> _laporanFields = [];

  // 4. Arsip Controllers & Lists
  final _arsipMaxMbCtrl = TextEditingController();
  List<String> _arsipFolders = [];
  List<String> _arsipAllowedExts = [];

  // 5. Tata Tertib & Pelanggaran Lists
  List<String> _pelanggaranFields = [];

  // 6. Data Sekolah & Rekap Lists
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
  List<String> _rekapTypes = [];

  bool _saving = false;
  bool _isSyncing = false;
  StreamSubscription<String>? _dataSub;
  List<AppAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);

    _loadCurrentConfigs();
    _loadAccounts();

    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'accounts' || table == 'app_settings' || table == 'sekbid' || table == 'all') {
        if (mounted) {
          _loadCurrentConfigs();
          _loadAccounts();
        }
      }
    });
  }

  void _loadCurrentConfigs() {
    _appNameCtrl.text = AppSettingsService.appNameNotifier.value;
    _appSubtitleCtrl.text = AppSettingsService.appSubtitleNotifier.value;
    _logoUrlCtrl.text = AppSettingsService.logoUrlNotifier.value;
    _selectedAccent = AppSettingsService.accentColorNotifier.value;
    _hexColorCtrl.text = '#${_selectedAccent.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    _selectedLanguages = List<String>.from(AppSettingsService.enabledLanguagesNotifier.value);

    _sp1Ctrl.text = AppSettingsService.sp1ThresholdNotifier.value.toString();
    _sp2Ctrl.text = AppSettingsService.sp2ThresholdNotifier.value.toString();
    _sp3Ctrl.text = AppSettingsService.sp3ThresholdNotifier.value.toString();
    _skorsingCtrl.text = AppSettingsService.skorsingThresholdNotifier.value.toString();
    _pelanggaranFields = List<String>.from(AppSettingsService.pelanggaranFieldsNotifier.value);

    _sekbidList = List<String>.from(AppSettingsService.sekbidListNotifier.value);
    _laporanCategories = List<String>.from(AppSettingsService.laporanCategoriesNotifier.value);
    _laporanFields = List<String>.from(AppSettingsService.laporanFieldsNotifier.value);

    _arsipMaxMbCtrl.text = AppSettingsService.arsipMaxMbNotifier.value.toString();
    _arsipFolders = List<String>.from(AppSettingsService.arsipFoldersNotifier.value);
    _arsipAllowedExts = List<String>.from(AppSettingsService.arsipAllowedExtsNotifier.value);

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
    _rekapTypes = List<String>.from(AppSettingsService.rekapTypesNotifier.value);
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
    if (!mounted) return;
    setState(() => _accounts = AuthService.allAccounts);
  }

  void _onColorChanged(Color color) {
    setState(() {
      _selectedAccent = color;
      _hexColorCtrl.text = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
    });
    AppSettingsService.setAccentColor(color, syncCloud: true);
  }

  Future<void> _saveAllConfigs() async {
    setState(() => _saving = true);

    // 1. Simpan Branding
    await AppSettingsService.setAppBranding(
      name: _appNameCtrl.text.trim(),
      subtitle: _appSubtitleCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
      globalColor: _selectedAccent,
      enabledLanguages: _selectedLanguages.isEmpty ? ['id'] : _selectedLanguages,
    );

    // 2. Simpan Konfigurasi Lainnya
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
      sp1: int.tryParse(_sp1Ctrl.text.trim()),
      sp2: int.tryParse(_sp2Ctrl.text.trim()),
      sp3: int.tryParse(_sp3Ctrl.text.trim()),
      skorsing: int.tryParse(_skorsingCtrl.text.trim()),
      pelanggaranFields: _pelanggaranFields,
      arsipMaxMb: int.tryParse(_arsipMaxMbCtrl.text.trim()),
      arsipFolders: _arsipFolders,
      arsipAllowedExts: _arsipAllowedExts,
      sekbidList: _sekbidList,
      laporanCategories: _laporanCategories,
      laporanFields: _laporanFields,
      rekapTypes: _rekapTypes,
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

  void _showAddChipDialog(String title, ValueChanged<String> onAdd) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tambah $title'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Masukkan nama $title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(LocalizationService.tr('btn_cancel'))),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) {
                onAdd(text);
                Navigator.pop(ctx);
              }
            },
            child: Text(LocalizationService.tr('btn_save')),
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: EdgeInsets.zero,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          tabs: const [
            Tab(text: 'Branding & Warna', icon: Icon(Icons.palette_outlined, size: 18)),
            Tab(text: 'Konfigurasi Input', icon: Icon(Icons.tune_rounded, size: 18)),
            Tab(text: 'Tata Tertib', icon: Icon(Icons.warning_amber_rounded, size: 18)),
            Tab(text: 'Proker & Sekbid', icon: Icon(Icons.assignment_outlined, size: 18)),
            Tab(text: 'Arsip & Berkas', icon: Icon(Icons.folder_outlined, size: 18)),
            Tab(text: 'Sekolah & Legalitas', icon: Icon(Icons.school_outlined, size: 18)),
            Tab(text: 'Akun Pengguna', icon: Icon(Icons.manage_accounts_outlined, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildBrandingTab(theme, isDark, primary),
          _buildKonfigurasiInputTab(theme, isDark, primary),
          _buildTataTertibTab(theme, isDark, primary),
          _buildProkerLaporanTab(theme, isDark, primary),
          _buildArsipTab(theme, isDark, primary),
          _buildSekolahTab(theme, isDark, primary),
          _buildAccountsTab(theme, isDark, primary),
        ],
      ),
    );
  }

  Widget _buildBrandingTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              spacing: 10, runSpacing: 10,
              children: AppSettingsService.presets.map((p) {
                final isSel = _selectedAccent.toARGB32() == p.color.toARGB32();
                return InkWell(
                  onTap: () => _onColorChanged(p.color),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? p.color.withAlpha(45) : Colors.transparent,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: isSel ? p.color : (isDark ? Colors.white24 : Colors.grey.shade300), width: isSel ? 2 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 20, height: 20, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [p.color, p.darkColor]))),
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

  Widget _buildKonfigurasiInputTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141D2E) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF243452) : Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: isDark ? const Color(0xFF38BDF8) : Colors.blue.shade700, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pusat Konfigurasi Input Halaman (Admin)',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.blue.shade900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Atur kolom & opsi input untuk seluruh halaman aplikasi. Setiap perubahan langsung tersinkronkan ke semua pengguna.',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 1. Input Kolom Laporan Kegiatan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Kolom Input Laporan Kegiatan (${_laporanFields.length})', icon: Icons.article_outlined, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                tooltip: 'Tambah Kolom Laporan',
                onPressed: () => _showAddChipDialog('Kolom Input Laporan', (val) => setState(() => _laporanFields.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _laporanFields.map((lf) => Chip(
              label: Text(lf, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _laporanFields.remove(lf)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
          const SizedBox(height: 24),

          // 2. Input Kolom Catat Pelanggaran
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Kolom Input Catat Pelanggaran (${_pelanggaranFields.length})', icon: Icons.warning_amber_rounded, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                tooltip: 'Tambah Kolom Pelanggaran',
                onPressed: () => _showAddChipDialog('Kolom Input Pelanggaran', (val) => setState(() => _pelanggaranFields.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _pelanggaranFields.map((pf) => Chip(
              label: Text(pf, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _pelanggaranFields.remove(pf)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
          const SizedBox(height: 24),

          // 3. Input Dimensi Rekap
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Dimensi Rekap Disiplin Siswa (${_rekapTypes.length})', icon: Icons.bar_chart_rounded, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                tooltip: 'Tambah Dimensi Rekap',
                onPressed: () => _showAddChipDialog('Dimensi Rekap Baru', (val) => setState(() => _rekapTypes.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _rekapTypes.map((rt) => Chip(
              label: Text(rt, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _rekapTypes.remove(rt)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
          const SizedBox(height: 24),

          // 4. Folder & Ekstensi Arsip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Ekstensi File Arsip Diizinkan (${_arsipAllowedExts.length})', icon: Icons.extension_outlined, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                tooltip: 'Tambah Ekstensi File',
                onPressed: () => _showAddChipDialog('Ekstensi File (cth: pdf)', (val) => setState(() => _arsipAllowedExts.add(val.replaceAll('.', '').toLowerCase()))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _arsipAllowedExts.map((ext) => Chip(
              label: Text('.$ext', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onDeleted: () => setState(() => _arsipAllowedExts.remove(ext)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
          const SizedBox(height: 24),

          // 5. Sekbid & Unit Proker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Daftar Sekbid & Unit Proker (${_sekbidList.length})', icon: Icons.assignment_outlined, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                tooltip: 'Tambah Sekbid',
                onPressed: () => _showAddChipDialog('Sekbid / Unit Baru', (val) => setState(() => _sekbidList.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _sekbidList.map((s) => Chip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onDeleted: _sekbidList.length > 1 ? () => setState(() => _sekbidList.remove(s)) : null,
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTataTertibTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title: 'Batas Poin Surat Peringatan & Sanksi', icon: Icons.rule_rounded, color: _selectedAccent),
          const SizedBox(height: 12),
          TextField(
            controller: _sp1Ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Batas Poin SP 1 (Surat Peringatan 1)',
              prefixIcon: Icon(Icons.warning_amber_rounded, color: Colors.amber),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _sp2Ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Batas Poin SP 2 (Surat Peringatan 2)',
              prefixIcon: Icon(Icons.report_problem_outlined, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _sp3Ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Batas Poin SP 3 (Panggilan Orang Tua)',
              prefixIcon: Icon(Icons.error_outline_rounded, color: Colors.deepOrange),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _skorsingCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Batas Poin Tindakan Skorsing / Sidang',
              prefixIcon: Icon(Icons.gavel_rounded, color: Colors.red),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Kolom Input Catat Pelanggaran (${_pelanggaranFields.length})', icon: Icons.playlist_add_check_rounded, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                onPressed: () => _showAddChipDialog('Kolom Input Pelanggaran', (val) => setState(() => _pelanggaranFields.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _pelanggaranFields.map((pf) => Chip(
              label: Text(pf, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _pelanggaranFields.remove(pf)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProkerLaporanTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Daftar Divisi / Sekbid (${_sekbidList.length})', icon: Icons.groups_rounded, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                onPressed: () => _showAddChipDialog('Sekbid / Unit Baru', (val) => setState(() => _sekbidList.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _sekbidList.map((s) => Chip(
              label: Text(s, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _sekbidList.remove(s)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Kategori Laporan Kegiatan (${_laporanCategories.length})', icon: Icons.category_rounded, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                onPressed: () => _showAddChipDialog('Kategori Laporan Baru', (val) => setState(() => _laporanCategories.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _laporanCategories.map((c) => Chip(
              label: Text(c, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _laporanCategories.remove(c)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Kolom Input & Format Laporan (${_laporanFields.length})', icon: Icons.view_list_rounded, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                onPressed: () => _showAddChipDialog('Kolom Laporan Baru', (val) => setState(() => _laporanFields.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _laporanFields.map((lf) => Chip(
              label: Text(lf, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _laporanFields.remove(lf)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildArsipTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title: 'Batas Ukuran Berkas', icon: Icons.upload_file_rounded, color: _selectedAccent),
          const SizedBox(height: 12),
          TextField(
            controller: _arsipMaxMbCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Maksimal Ukuran Upload per Berkas (MB)',
              prefixIcon: Icon(Icons.sd_storage_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Folder Kategori Arsip (${_arsipFolders.length})', icon: Icons.folder_copy_rounded, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                onPressed: () => _showAddChipDialog('Folder Arsip Baru', (val) => setState(() => _arsipFolders.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _arsipFolders.map((f) => Chip(
              label: Text(f, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _arsipFolders.remove(f)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Ekstensi File Diizinkan (${_arsipAllowedExts.length})', icon: Icons.extension_rounded, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                onPressed: () => _showAddChipDialog('Ekstensi File (contoh: pdf)', (val) => setState(() => _arsipAllowedExts.add(val.replaceAll('.', '').toLowerCase()))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _arsipAllowedExts.map((ext) => Chip(
              label: Text('.$ext', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onDeleted: () => setState(() => _arsipAllowedExts.remove(ext)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSekolahTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(title: 'Identitas Sekolah & Tahun Ajaran', icon: Icons.domain_rounded, color: _selectedAccent),
          const SizedBox(height: 12),
          TextField(controller: _schoolNameCtrl, decoration: const InputDecoration(labelText: 'Nama Sekolah', prefixIcon: Icon(Icons.school_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'Kota / Wilayah', prefixIcon: Icon(Icons.location_city_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _academicYearCtrl, decoration: const InputDecoration(labelText: 'Tahun Ajaran / Periode', prefixIcon: Icon(Icons.calendar_today_outlined))),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(title: 'Dimensi Rekap Disiplin Siswa (${_rekapTypes.length})', icon: Icons.analytics_outlined, color: _selectedAccent),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.green),
                onPressed: () => _showAddChipDialog('Dimensi Rekap Baru', (val) => setState(() => _rekapTypes.add(val))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _rekapTypes.map((rt) => Chip(
              label: Text(rt, style: const TextStyle(fontSize: 12)),
              onDeleted: () => setState(() => _rekapTypes.remove(rt)),
              deleteIconColor: Colors.redAccent,
            )).toList(),
          ),
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
