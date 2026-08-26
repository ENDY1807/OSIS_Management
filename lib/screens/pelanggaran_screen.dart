import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/localization_service.dart';
import '../app_theme.dart';

List<JenisPelanggaran> _jenisUntukHari(List<JenisPelanggaran> jenis, int weekday) {
  return jenis.where((j) => j.hariAktif.contains(weekday)).toList();
}

class PelanggaranScreen extends StatefulWidget {
  final String username;
  const PelanggaranScreen({super.key, this.username = ''});
  @override
  State<PelanggaranScreen> createState() => _PelanggaranScreenState();
}

class _PelanggaranScreenState extends State<PelanggaranScreen> {
  List<Siswa> _siswa = [];
  List<JenisPelanggaran> _jenis = [];
  List<Pelanggaran> _pelanggaran = [];
  String? _filterSiswaId;
  bool _loading = true;
  DateTime _selectedDate = _today();
  StreamSubscription<String>? _dataSub;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday =>
      _selectedDate == _today();

  static const _superUsers = ['KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA'];
  bool get _canEdit =>
      widget.username == 'ADMIN' ||
      AuthService.getRole(widget.username) == 'ADMIN' ||
      _superUsers.contains(widget.username) ||
      widget.username == 'PEMBINA' ||
      widget.username == 'KESISWAAN' ||
      AuthService.getRole(widget.username) == 'PEMBINA' ||
      AuthService.getRole(widget.username) == 'KESISWAAN';

  final _filterCtrl = TextEditingController();
  final _filterFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _load();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'pelanggaran' || table == 'siswa' || table == 'jenis_pelanggaran' || table == 'all') {
        if (mounted) _load(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _filterCtrl.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && _pelanggaran.isEmpty) setState(() => _loading = true);
    try {
      final s = await DataService.getSiswa();
      final j = await DataService.getJenis();
      final p = await DataService.getPelanggaran();
      if (!mounted) return;
      setState(() {
        _siswa = s;
        _jenis = j;
        _pelanggaran = p..sort((a, b) => b.tanggal.compareTo(a.tanggal));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (showLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal load data: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: _today(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _filterSiswaId = null;
        _filterCtrl.clear();
      });
    }
  }

  void _showCeklis() {
    Siswa? selectedSiswa;
    final selectedTanggal = _selectedDate;
    final jenisHariIni = _jenisUntukHari(_jenis, selectedTanggal.weekday);
    final checkedJenis = <String>{};
    final ketC = TextEditingController();
    final siswaCtrl = TextEditingController();
    final siswaFocus = FocusNode();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
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
                Text(LocalizationService.tr('pelanggaran_add'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                const SizedBox(height: 16),

                // ── Pilih Siswa (Autocomplete) ──
                if (_siswa.isEmpty)
                  _warningBox(LocalizationService.currentLocale.value.languageCode == 'en' ? 'No student data. Add students in Management.' : 'Belum ada data siswa. Tambahkan di menu Manajemen.')
                else
                  RawAutocomplete<Siswa>(
                    textEditingController: siswaCtrl,
                    focusNode: siswaFocus,
                    displayStringForOption: (s) => '${s.nama} - ${s.kelas}',
                    optionsBuilder: (v) {
                      if (v.text.isEmpty) return _siswa;
                      final q = v.text.toLowerCase();
                      return _siswa.where((s) =>
                        s.nama.toLowerCase().contains(q) ||
                        s.nis.toLowerCase().contains(q) ||
                        s.kelas.toLowerCase().contains(q));
                    },
                    onSelected: (v) => setModal(() {
                      selectedSiswa = v;
                      siswaCtrl.text = '${v.nama} - ${v.kelas}';
                    }),
                    fieldViewBuilder: (_, ctrl, fn, onSubmit) => TextField(
                      controller: ctrl,
                      focusNode: fn,
                      onTapOutside: (_) => fn.unfocus(),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: LocalizationService.tr('pelanggaran_search_student'),
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                        prefixIcon: const Icon(Icons.person_search_outlined, color: kAccent),
                        suffixIcon: selectedSiswa != null
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : null,
                      ),
                    ),
                    optionsViewBuilder: (_, onSel, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200, maxWidth: 380),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: options.map((s) => ListTile(
                              dense: true,
                              title: Text(s.nama, style: const TextStyle(fontSize: 13)),
                              subtitle: Text('${s.kelas} • NIS: ${s.nis}',
                                  style: const TextStyle(fontSize: 11)),
                              onTap: () => onSel(s),
                            )).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (selectedSiswa != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${selectedSiswa!.nama} — ${selectedSiswa!.kelas}',
                            style: TextStyle(fontSize: 13, color: Colors.green.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // ── Tanggal (dari header) ──
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('pelanggaran_date'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.calendar_month_outlined, color: kAccent)),
                  child: Text(DateFormat('dd MMMM yyyy (EEEE)', LocalizationService.currentLocale.value.languageCode).format(selectedTanggal),
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : kTextDark)),
                ),

                const SizedBox(height: 16),
                Row(children: [
                  Text(LocalizationService.tr('pelanggaran_type'),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: kAccent.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      LocalizationService.formatDay(selectedTanggal.weekday),
                      style: const TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),

                if (_jenis.isEmpty)
                  _warningBox('Belum ada jenis pelanggaran. Tambahkan di menu Manajemen → Jenis Pelanggaran.')
                else if (jenisHariIni.isEmpty)
                  _warningBox('Tidak ada jenis pelanggaran untuk hari ${_namaHari(selectedTanggal.weekday)}.')
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${jenisHariIni.length} jenis pelanggaran untuk hari ${_namaHari(selectedTanggal.weekday)}',
                      style: const TextStyle(fontSize: 11, color: kAccent),
                    ),
                  ),
                  ...jenisHariIni.map((j) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: checkedJenis.contains(j.id)
                          ? (isDark ? kAccent.withAlpha(50) : kPrimary.withAlpha(80))
                          : (isDark ? const Color(0xFF1B2433) : kBg),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: checkedJenis.contains(j.id) ? kAccent : (isDark ? const Color(0xFF263348) : kPrimary)),
                    ),
                    child: CheckboxListTile(
                      title: Text(j.nama,
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : kTextDark)),
                      value: checkedJenis.contains(j.id),
                      activeColor: kAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onChanged: (v) => setModal(() {
                        if (v == true) { checkedJenis.add(j.id); } else { checkedJenis.remove(j.id); }
                      }),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  )),
                ],

                const SizedBox(height: 12),
                TextField(
                  controller: ketC,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Keterangan (opsional)',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.notes_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 20),

                if (selectedSiswa == null || checkedJenis.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text(
                          selectedSiswa == null
                              ? 'Pilih siswa terlebih dahulu'
                              : 'Pilih minimal 1 jenis pelanggaran',
                          style: const TextStyle(fontSize: 12, color: Colors.orange),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                ElevatedButton(
                  onPressed: (selectedSiswa == null || checkedJenis.isEmpty)
                      ? null
                      : () async {
                          try {
                            for (final jenisId in checkedJenis) {
                              await DataService.addPelanggaran(
                                selectedSiswa!.id, jenisId, ketC.text.trim(),
                                tanggal: selectedTanggal,
                              );
                            }
                            final actorName = widget.username.isNotEmpty ? widget.username : 'Sistem';
                            await NotificationService.notifyUpdate(
                              title: 'Catatan Pelanggaran Baru',
                              message: '${checkedJenis.length} catatan pelanggaran ditambahkan untuk ${selectedSiswa!.nama} (${selectedSiswa!.kelas}) oleh $actorName',
                              category: 'pelanggaran',
                              actor: actorName,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('${checkedJenis.length} pelanggaran tersimpan untuk ${selectedSiswa!.nama}')),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 3),
                              ));
                              _load();
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Gagal simpan: $e'), backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 5)));
                          }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    checkedJenis.isEmpty
                        ? 'Simpan Pelanggaran'
                        : 'Simpan ${checkedJenis.length} Pelanggaran',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _namaHari(int weekday) {
    const hari = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return hari[weekday];
  }

  Widget _warningBox(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Text(msg, style: const TextStyle(fontSize: 13, color: Colors.orange)),
  );

  List<Pelanggaran> get _filteredByDate => _pelanggaran.where((p) =>
      p.tanggal.year == _selectedDate.year &&
      p.tanggal.month == _selectedDate.month &&
      p.tanggal.day == _selectedDate.day).toList();

  List<Pelanggaran> get _filtered =>
      _filterSiswaId == null ? _filteredByDate : _filteredByDate.where((p) => p.siswaId == _filterSiswaId).toList();

  String _namaSiswa(String id) =>
      _siswa.firstWhere((s) => s.id == id, orElse: () => Siswa(id: '', nama: '(Siswa dihapus)', kelas: '', nis: '')).nama;
  String _kelasSiswa(String id) =>
      _siswa.firstWhere((s) => s.id == id, orElse: () => Siswa(id: '', nama: '-', kelas: '-', nis: '')).kelas;
  String _namaJenis(String id) =>
      _jenis.firstWhere((j) => j.id == id, orElse: () => JenisPelanggaran(id: '', nama: '(Jenis dihapus)')).nama;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final cardBg = isDark ? const Color(0xFF141D2E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0);
    final textTitle = isDark ? Colors.white : kTextDark;
    final textSub = isDark ? const Color(0xFF94A3B8) : kTextMid;
    final textMuted = isDark ? const Color(0xFF64748B) : kTextLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // ── Date picker header ──
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1424) : kPrimaryDark,
                  border: isDark ? const Border(bottom: BorderSide(color: Color(0xFF243452))) : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, dd MMMM yyyy', LocalizationService.currentLocale.value.languageCode).format(_selectedDate),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        _filterSiswaId = null;
                        _filterCtrl.clear();
                      }),
                      child: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: _isToday ? null : () => setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 1));
                        _filterSiswaId = null;
                        _filterCtrl.clear();
                      }),
                      child: Icon(Icons.chevron_right,
                          color: _isToday ? Colors.white38 : Colors.white),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _load,
                      child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                    ),
                  ]),
                ]),
              ),
            ),

            // ── Search filter siswa ──
            if (_filteredByDate.isNotEmpty)
              Container(
                color: isDark ? const Color(0xFF141D2E) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _siswa.isEmpty
                    ? const SizedBox.shrink()
                    : RawAutocomplete<Siswa>(
                        textEditingController: _filterCtrl,
                        focusNode: _filterFocus,
                        displayStringForOption: (s) => '${s.nama} - ${s.kelas}',
                        optionsBuilder: (v) {
                          final idsWithViolations = _filteredByDate.map((p) => p.siswaId).toSet();
                          final available = _siswa.where((s) => idsWithViolations.contains(s.id)).toList();
                          if (v.text.isEmpty) return available;
                          final q = v.text.toLowerCase();
                          return available.where((s) =>
                            s.nama.toLowerCase().contains(q) ||
                            s.nis.toLowerCase().contains(q) ||
                            s.kelas.toLowerCase().contains(q));
                        },
                        onSelected: (v) => setState(() => _filterSiswaId = v.id),
                        fieldViewBuilder: (_, ctrl, fn, onSubmit) => TextField(
                          controller: ctrl,
                          focusNode: fn,
                          onTapOutside: (_) => fn.unfocus(),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: LocalizationService.tr('pelanggaran_search_student'),
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black38),
                            prefixIcon: const Icon(Icons.search, size: 20, color: kAccent),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixIcon: _filterSiswaId != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => setState(() {
                                      _filterSiswaId = null;
                                      _filterCtrl.clear();
                                    }),
                                  )
                                : null,
                          ),
                        ),
                        optionsViewBuilder: (_, onSel, options) => Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 380),
                              child: ListView(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                children: options.map((s) => ListTile(
                                  dense: true,
                                  title: Text(s.nama, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text('${s.kelas} • NIS: ${s.nis}',
                                      style: const TextStyle(fontSize: 11)),
                                  onTap: () => onSel(s),
                                )).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

          // ── Summary bar ──
          if (_filtered.isNotEmpty)
            Container(
              color: isDark ? const Color(0xFF1A263D) : primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _filterSiswaId == null
                        ? '${_filtered.map((p) => p.siswaId).toSet().length} ${LocalizationService.tr('students')} • ${_filtered.length} ${LocalizationService.tr('records')}'
                        : '${_filtered.length} ${LocalizationService.tr('records')}',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ]),
            ),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primary))
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 72, color: textMuted),
                            const SizedBox(height: 16),
                            Text(LocalizationService.tr('pelanggaran_empty'),
                                style: TextStyle(fontSize: 16, color: textSub), textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          itemCount: _filtered.map((p) => p.siswaId).toSet().length,
                          itemBuilder: (_, i) {
                            final ids = _filtered.map((p) => p.siswaId).toSet().toList();
                            final siswaId = ids[i];
                            final pelSiswa = _filtered.where((p) => p.siswaId == siswaId).toList()
                              ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cardBorder),
                                boxShadow: isDark ? null : [BoxShadow(
                                    color: kPrimary.withAlpha(80), blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withAlpha(isDark ? 45 : 30),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.orange.withAlpha(100)),
                                        ),
                                        child: Center(
                                          child: Text('${pelSiswa.length}',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                                  color: Colors.orange.shade400)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_namaSiswa(siswaId),
                                                style: TextStyle(fontSize: 14,
                                                    fontWeight: FontWeight.bold, color: textTitle)),
                                            Text('Kelas ${_kelasSiswa(siswaId)} • ${pelSiswa.length} ${LocalizationService.tr('violations')}',
                                                style: TextStyle(fontSize: 11, color: textMuted)),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: LocalizationService.tr('btn_delete'),
                                        onPressed: !_canEdit ? null : () async {
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (d) => AlertDialog(
                                              title: Text(LocalizationService.tr('pelanggaran_delete_confirm')),
                                              content: Text('Hapus semua ${pelSiswa.length} catatan pelanggaran ${_namaSiswa(siswaId)}?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(d, false), child: Text(LocalizationService.tr('btn_cancel'))),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(d, true),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                  child: Text(LocalizationService.tr('btn_delete')),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (ok != true) return;
                                          for (final p in pelSiswa) { await DataService.deletePelanggaran(p.id); }
                                          final actorName = widget.username.isNotEmpty ? widget.username : 'Sistem';
                                          await NotificationService.notifyUpdate(
                                            title: 'Catatan Pelanggaran Dihapus',
                                            message: 'Semua catatan pelanggaran ${_namaSiswa(siswaId)} telah dihapus oleh $actorName',
                                            category: 'pelanggaran',
                                            actor: actorName,
                                          );
                                          _load();
                                        },
                                      ),
                                    ]),
                                    const SizedBox(height: 10),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    // ── List item pelanggaran (fix overflow) ──
                                    ...pelSiswa.map((p) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(children: [
                                        Container(
                                          width: 6, height: 6,
                                          margin: const EdgeInsets.only(right: 8, top: 2),
                                          decoration: const BoxDecoration(
                                              shape: BoxShape.circle, color: kAccent),
                                        ),
                                        Expanded(
                                          child: Text(_namaJenis(p.jenisId),
                                              style: const TextStyle(fontSize: 12, color: kTextMid),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(DateFormat('dd/MM/yy').format(p.tanggal),
                                            style: const TextStyle(fontSize: 10, color: kTextLight)),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: !_canEdit ? null : () async {
                                            await DataService.deletePelanggaran(p.id);
                                            final actorName = widget.username.isNotEmpty ? widget.username : 'Sistem';
                                            await NotificationService.notifyUpdate(
                                              title: 'Catatan Pelanggaran Dihapus',
                                              message: 'Pelanggaran "${_namaJenis(p.jenisId)}" untuk ${_namaSiswa(p.siswaId)} dihapus oleh $actorName',
                                              category: 'pelanggaran',
                                              actor: actorName,
                                            );
                                            _load();
                                          },
                                          child: Icon(Icons.close, size: 14, color: _canEdit ? kTextLight : Colors.transparent),
                                        ),
                                      ]),
                                    )),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showCeklis,
      backgroundColor: primary,
      foregroundColor: isDark ? Colors.black : Colors.white,
      icon: const Icon(Icons.add),
      label: Text(LocalizationService.tr('pelanggaran_add'), style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}
}
