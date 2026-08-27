import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/localization_service.dart';
import '../services/app_settings_service.dart';
import '../app_theme.dart';
import 'package:uuid/uuid.dart';

class ProkerScreen extends StatefulWidget {
  final String username;
  const ProkerScreen({super.key, this.username = ''});
  @override
  State<ProkerScreen> createState() => _ProkerScreenState();
}

class _ProkerScreenState extends State<ProkerScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  StreamSubscription<String>? _dataSub;
  List<Proker> _proker = [];
  String _currentUser = '';
  String _filterSekbid = 'Semua';
  bool _userLoaded = false;
  bool get _isAdmin => _currentUser == 'ADMIN' || AuthService.getRole(_currentUser) == 'ADMIN';
  bool get _isSuperUser => _isAdmin || ['KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA'].contains(_currentUser);
  bool get _isPembina => _isAdmin || _currentUser == 'PEMBINA' || _currentUser == 'KESISWAAN' || AuthService.getRole(_currentUser) == 'PEMBINA' || AuthService.getRole(_currentUser) == 'KESISWAAN';
  bool get _isProkerUnit => AuthService.prokerUnits.contains(_currentUser);
  bool get _canEdit => _isSuperUser || _isPembina || _isProkerUnit;
  // Unit hanya bisa CRUD proker miliknya sendiri, kecuali SuperUser/Pembina
  bool _canEditProker(Proker p) => _isAdmin || _isPembina || p.sekbid == _currentUser || (_isSuperUser && ['KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA'].contains(p.sekbid));

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'proker' || table == 'app_settings' || table == 'all') {
        if (mounted) _load();
      }
    });
    AuthService.getUserName().then((v) {
      setState(() {
        _currentUser = widget.username.isNotEmpty ? widget.username : (v ?? '');
        _filterSekbid = (_isSuperUser || _isPembina) ? 'Semua' : _currentUser;
        _userLoaded = true;
      });
      _load();
    });
  }

  void _showAdminConfigProker() {
    final list = List<String>.from(AppSettingsService.sekbidListNotifier.value);
    final newSekbidCtrl = TextEditingController();
    bool isSaving = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDark ? const Border(top: BorderSide(color: Color(0xFF243452), width: 1)) : null,
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(isDark ? 50 : 30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konfigurasi Sekbid & Departemen (Admin)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark),
                          ),
                          Text(
                            'Perubahan sekbid akan berlaku di semua akun pengguna',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Tambah Sekbid Baru Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newSekbidCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Nama Sekbid/Unit baru...',
                          isDense: true,
                          prefixIcon: Icon(Icons.add_circle_outline, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final val = newSekbidCtrl.text.trim();
                        if (val.isNotEmpty && !list.contains(val)) {
                          setM(() {
                            list.add(val);
                            newSekbidCtrl.clear();
                          });
                        }
                      },
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Daftar Sekbid Chips
                Text(
                  'DAFTAR SEKBID / DIVISI AKTIF (${list.length})',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF38BDF8) : kPrimary, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: list.map((item) {
                    return Chip(
                      label: Text(item, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: list.length > 1
                          ? () => setM(() => list.remove(item))
                          : null,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: isSaving ? null : () async {
                    setM(() => isSaving = true);
                    await AppSettingsService.saveAdminConfigs(sekbidList: list);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white),
                              SizedBox(width: 10),
                              Expanded(child: Text('Daftar Sekbid berhasil disinkronkan ke semua user!')),
                            ],
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(isSaving ? 'Menyimpan ke Cloud...' : 'Simpan Perubahan ke Semua User'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DataService.getProker();
    if (!mounted) return;
    setState(() => _proker = data..sort((a, b) => a.tanggalRencana.compareTo(b.tanggalRencana)));
  }

  List<Proker> get _filtered {
    // Semua role lihat semua proker, tapi superUser/Pembina bisa filter per sekbid/unit
    List<Proker> list = _proker;
    if ((_isSuperUser || _isPembina) && _filterSekbid != 'Semua') {
      list = list.where((p) => p.sekbid == _filterSekbid).toList();
    }
    switch (_tab.index) {
      case 0: return list.where((p) => p.status == StatusProker.belum).toList();
      case 1: return list.where((p) => p.status == StatusProker.berjalan).toList();
      case 2: return list.where((p) => p.status == StatusProker.selesai).toList();
      default: return list;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case StatusProker.berjalan: return const Color(0xFF0097B2);
      case StatusProker.selesai: return const Color(0xFF2E7D32);
      default: return const Color(0xFF8D6E63);
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case StatusProker.berjalan: return Icons.timelapse_rounded;
      case StatusProker.selesai: return Icons.check_circle_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  void _showForm([Proker? existing]) async {
    final namaC = TextEditingController(text: existing?.nama);
    final deskC = TextEditingController(text: existing?.deskripsi);
    final pjC = TextEditingController(text: existing?.penanggungJawab ?? AuthService.getDisplayName(_currentUser));
    final ketC = TextEditingController(text: existing?.keterangan);
    String selectedSekbid = existing?.sekbid ?? ((_isSuperUser || _isPembina) ? (_currentUser.isNotEmpty && AuthService.prokerUnits.contains(_currentUser) ? _currentUser : AuthService.prokerUnits.first) : _currentUser);
    String selectedStatus = existing?.status ?? StatusProker.belum;
    DateTime tanggalRencana = existing?.tanggalRencana ?? DateTime.now();
    DateTime? tanggalRealisasi = existing?.tanggalRealisasi;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDark ? const Border(top: BorderSide(color: Color(0xFF243452), width: 1)) : null,
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(existing == null ? LocalizationService.tr('proker_add') : LocalizationService.tr('proker_edit'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                const SizedBox(height: 16),

                TextField(
                  controller: namaC,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('proker_name'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.assignment, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deskC,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('proker_desc'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.description, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),

                if (_isSuperUser || _isPembina)
                  DropdownButtonFormField<String>(
                    initialValue: selectedSekbid,
                    decoration: InputDecoration(
                      labelText: LocalizationService.tr('proker_sekbid'),
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      prefixIcon: const Icon(Icons.group, color: kAccent),
                    ),
                    items: AuthService.prokerUnits
                        .map((s) => DropdownMenuItem(value: s, child: Text(AuthService.getDisplayName(s))))
                        .toList(),
                    onChanged: (v) => setModal(() => selectedSekbid = v ?? selectedSekbid),
                  )
                else
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: LocalizationService.tr('proker_sekbid'),
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      prefixIcon: const Icon(Icons.group, color: kAccent),
                    ),
                    child: Text(AuthService.getDisplayName(selectedSekbid), style: TextStyle(fontSize: 14, color: isDark ? Colors.white : kTextDark)),
                  ),
                const SizedBox(height: 12),

                TextField(
                  controller: pjC,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('proker_pj'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.person, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),

                // Tanggal Rencana
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: tanggalRencana,
                      firstDate: DateTime(2020), lastDate: DateTime(2100),
                    );
                    if (picked != null) setModal(() => tanggalRencana = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: LocalizationService.tr('proker_plan_date'),
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      prefixIcon: const Icon(Icons.event, color: kAccent),
                    ),
                    child: Text(DateFormat('dd MMMM yyyy', LocalizationService.currentLocale.value.languageCode).format(tanggalRencana),
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : kTextDark)),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.flag, color: kAccent),
                  ),
                  items: StatusProker.all.map((s) => DropdownMenuItem(value: s, child: Text(LocalizationService.formatStatus(s)))).toList(),
                  onChanged: (v) => setModal(() => selectedStatus = v ?? selectedStatus),
                ),
                const SizedBox(height: 12),

                if (selectedStatus == StatusProker.selesai) ...[
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context, initialDate: tanggalRealisasi ?? DateTime.now(),
                        firstDate: DateTime(2020), lastDate: DateTime(2100),
                      );
                      if (picked != null) setModal(() => tanggalRealisasi = picked);
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: LocalizationService.tr('proker_real_date'),
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                        prefixIcon: const Icon(Icons.event_available, color: Colors.green),
                      ),
                      child: Text(
                        tanggalRealisasi != null
                            ? DateFormat('dd MMMM yyyy', LocalizationService.currentLocale.value.languageCode).format(tanggalRealisasi!)
                            : LocalizationService.tr('btn_choose_file'),
                        style: TextStyle(fontSize: 14, color: tanggalRealisasi != null ? (isDark ? Colors.white : kTextDark) : (isDark ? Colors.white60 : kTextLight)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                TextField(
                  controller: ketC,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('proker_notes'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.notes, color: kAccent),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () async {
                    if (namaC.text.isEmpty) return;
                    final p = Proker(
                      id: existing?.id ?? const Uuid().v4(),
                      nama: namaC.text,
                      deskripsi: deskC.text,
                      sekbid: selectedSekbid,
                      penanggungJawab: pjC.text,
                      tanggalRencana: tanggalRencana,
                      tanggalRealisasi: selectedStatus == StatusProker.selesai ? tanggalRealisasi : null,
                      status: selectedStatus,
                      keterangan: ketC.text,
                    );
                    if (existing == null) {
                      await DataService.addProker(p);
                      await NotificationService.notifyUpdate(
                        title: 'Program Kerja Baru Dibuat',
                        message: 'Proker "${p.nama}" dibuat oleh $_currentUser',
                        category: 'proker',
                        actor: _currentUser,
                      );
                    } else {
                      await DataService.updateProker(p);
                      await NotificationService.notifyUpdate(
                        title: 'Program Kerja Diperbarui',
                        message: 'Proker "${p.nama}" (${p.sekbid} - Status: ${p.status}) diperbarui oleh $_currentUser',
                        category: 'proker',
                        actor: _currentUser,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    LocalizationService.tr('btn_save'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProkerCard(Proker p) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _statusColor(p.status);
    final cardBg = isDark ? const Color(0xFF141D2E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0);
    final textTitle = isDark ? Colors.white : kTextDark;
    final textSub = isDark ? const Color(0xFF94A3B8) : kTextMid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(100), blurRadius: 8, offset: const Offset(0, 2))],
        border: isDark
            ? Border.all(color: cardBorder)
            : Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(p.nama, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textTitle)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: color.withAlpha(isDark ? 40 : 25), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon(p.status), size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(LocalizationService.formatStatus(p.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                  ]),
                ),
              ],
            ),
            if (p.deskripsi.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.deskripsi, style: TextStyle(fontSize: 13, color: textSub), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 6,
              children: [
                _chip(Icons.group_outlined, p.sekbid, isDark: isDark),
                _chip(Icons.person_outline, p.penanggungJawab, isDark: isDark),
                _chip(Icons.calendar_today_outlined, DateFormat('dd MMM yyyy', LocalizationService.currentLocale.value.languageCode).format(p.tanggalRencana), isDark: isDark),
                if (p.tanggalRealisasi != null)
                  _chip(Icons.event_available_outlined, DateFormat('dd MMM yyyy', LocalizationService.currentLocale.value.languageCode).format(p.tanggalRealisasi!), color: Colors.green, isDark: isDark),
              ],
            ),
            if (p.keterangan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E1626) : kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: isDark ? Border.all(color: const Color(0xFF243452)) : null,
                ),
                child: Text(p.keterangan, style: TextStyle(fontSize: 12, color: textSub, fontStyle: FontStyle.italic)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_canEditProker(p)) ...[
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(LocalizationService.tr('btn_edit'), style: const TextStyle(fontSize: 13)),
                  onPressed: () => _showForm(p),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: Text(LocalizationService.tr('btn_delete'), style: const TextStyle(fontSize: 13)),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(LocalizationService.tr('proker_delete_confirm')),
                        content: Text('${LocalizationService.tr('proker_delete_msg')}\n"${p.nama}"'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(LocalizationService.tr('btn_cancel'))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(LocalizationService.tr('btn_delete'), style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await DataService.deleteProker(p.id);
                      await NotificationService.cancelProkerReminder(
                        NotificationService.idFromString('proker_remind_${p.id}'));
                      await NotificationService.notifyUpdate(
                        title: 'Program Kerja Dihapus',
                        message: 'Proker "${p.nama}" (${p.sekbid}) telah dihapus oleh $_currentUser',
                        category: 'proker',
                        actor: _currentUser,
                      );
                      _load();
                    }
                  },
                ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {Color? color, bool isDark = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A263D) : kPrimary.withAlpha(60),
      borderRadius: BorderRadius.circular(6),
      border: isDark ? Border.all(color: const Color(0xFF243452)) : null,
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color ?? (isDark ? const Color(0xFF00B4D8) : kAccent)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color ?? (isDark ? const Color(0xFFF1F5F9) : kTextMid), fontWeight: FontWeight.w500)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final allSekbid = (_isSuperUser || _isPembina) ? [LocalizationService.tr('btn_all'), ...AuthService.prokerUnits] : [_currentUser];
    final totalBelum    = _proker.where((p) => p.status == StatusProker.belum).length;
    final totalBerjalan = _proker.where((p) => p.status == StatusProker.berjalan).length;
    final totalSelesai  = _proker.where((p) => p.status == StatusProker.selesai).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Stats header
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1424) : primary,
              border: isDark ? const Border(bottom: BorderSide(color: Color(0xFF243452))) : null,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                _statBox(LocalizationService.tr('status_draft'), totalBelum, const Color(0xFFBF8F00)),
                const SizedBox(width: 8),
                _statBox(LocalizationService.tr('status_running'), totalBerjalan, const Color(0xFF007A8E)),
                const SizedBox(width: 8),
                _statBox(LocalizationService.tr('status_done'), totalSelesai, const Color(0xFF2E7D32)),
                if (_isAdmin || _isPembina) ...[
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Konfigurasi Sekbid & Departemen (Admin)',
                    child: InkWell(
                      onTap: _showAdminConfigProker,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(isDark ? 40 : 50),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withAlpha(120)),
                        ),
                        child: const Center(
                          child: Icon(Icons.tune_rounded, color: Colors.amber, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_isSuperUser || _isPembina)
          Container(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allSekbid.map((s) {
                  final displayName = s == LocalizationService.tr('btn_all') ? s : AuthService.getDisplayName(s);
                  final selected = _filterSekbid == s || (_filterSekbid == 'Semua' && s == LocalizationService.tr('btn_all'));
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(displayName),
                      selected: selected,
                      onSelected: (_) => setState(() => _filterSekbid = (s == LocalizationService.tr('btn_all') ? 'Semua' : s)),
                      selectedColor: primary,
                      checkmarkColor: Colors.black,
                      labelStyle: TextStyle(
                        color: selected ? (isDark ? Colors.black : Colors.white) : (isDark ? const Color(0xFF94A3B8) : kTextDark),
                        fontWeight: FontWeight.w600, fontSize: 12,
                      ),
                      backgroundColor: isDark ? const Color(0xFF0E1626) : kPrimary.withAlpha(60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: isDark && !selected ? const BorderSide(color: Color(0xFF243452)) : BorderSide.none,
                      showCheckmark: false,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Tabs
          Container(
            color: isDark ? const Color(0xFF0D1424) : primary,
            child: TabBar(
              controller: _tab,
              tabs: [
                Tab(text: '${LocalizationService.tr('status_draft')} ($totalBelum)'),
                Tab(text: '${LocalizationService.tr('status_running')} ($totalBerjalan)'),
                Tab(text: '${LocalizationService.tr('status_done')} ($totalSelesai)'),
              ],
            ),
          ),

          // List
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: List.generate(3, (i) {
                final list = _filtered;
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined, size: 64, color: isDark ? const Color(0xFF64748B) : kTextLight),
                        const SizedBox(height: 12),
                        Text(LocalizationService.tr('proker_empty'), style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : kTextLight, fontSize: 15)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  color: primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildProkerCard(list[i]),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      floatingActionButton: (_userLoaded && (_canEdit || _isProkerUnit))
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: Text(LocalizationService.tr('proker_add'), style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _statBox(String label, int count, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    ),
  );
}
