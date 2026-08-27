import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../services/localization_service.dart';
import '../services/app_settings_service.dart';
import 'package:collection/collection.dart';
import '../app_theme.dart';

class RekapScreen extends StatefulWidget {
  const RekapScreen({super.key});
  @override
  State<RekapScreen> createState() => _RekapScreenState();
}

class _RekapScreenState extends State<RekapScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Siswa> _siswa = [];
  List<JenisPelanggaran> _jenis = [];
  List<Pelanggaran> _pelanggaran = [];
  String _searchKelas = '';
  String _filterPeriod = 'semua'; // semua, hari_ini, minggu, bulan, tahun, custom
  DateTimeRange? _customDateRange;
  StreamSubscription<String>? _dataSub;
  String _currentUser = '';

  bool get _isAdmin =>
      _currentUser == 'ADMIN' || AuthService.getRole(_currentUser) == 'ADMIN';
  bool get _isPembina =>
      _isAdmin ||
      _currentUser == 'PEMBINA' ||
      _currentUser == 'KESISWAAN' ||
      AuthService.getRole(_currentUser) == 'PEMBINA' ||
      AuthService.getRole(_currentUser) == 'KESISWAAN';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
    AuthService.getUserName().then((u) {
      if (mounted) setState(() => _currentUser = u ?? '');
    });
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'pelanggaran' || table == 'siswa' || table == 'jenis_pelanggaran' || table == 'app_settings' || table == 'all') {
        if (mounted) _load(showLoading: false);
      }
    });
  }

  Future<String?> _pickTtdImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final bytes = await file.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (_) {}
    return null;
  }

  void _showAdminConfigRekap() {
    final schoolNameCtrl = TextEditingController(text: AppSettingsService.schoolNameNotifier.value);
    final cityCtrl = TextEditingController(text: AppSettingsService.cityNotifier.value);
    final academicYearCtrl = TextEditingController(text: AppSettingsService.academicYearNotifier.value);
    final kepsekNameCtrl = TextEditingController(text: AppSettingsService.kepsekNameNotifier.value);
    final kepsekNipCtrl = TextEditingController(text: AppSettingsService.kepsekNipNotifier.value);
    final pembinaNameCtrl = TextEditingController(text: AppSettingsService.pembinaNameNotifier.value);
    final pembinaNipCtrl = TextEditingController(text: AppSettingsService.pembinaNipNotifier.value);
    final ketosNameCtrl = TextEditingController(text: AppSettingsService.ketosNameNotifier.value);
    final ketosNisCtrl = TextEditingController(text: AppSettingsService.ketosNisNotifier.value);
    final sekretarisNameCtrl = TextEditingController(text: AppSettingsService.sekretarisNameNotifier.value);
    final sekretarisNisCtrl = TextEditingController(text: AppSettingsService.sekretarisNisNotifier.value);

    String ttdKepsek = AppSettingsService.ttdKepsekNotifier.value;
    String ttdPembina = AppSettingsService.ttdPembinaNotifier.value;
    String ttdKetos = AppSettingsService.ttdKetosNotifier.value;
    String ttdSekretaris = AppSettingsService.ttdSekretarisNotifier.value;

    bool isSaving = false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          Widget buildTtdUploadTile(String label, String currentBase64, ValueChanged<String> onChanged) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0E1626) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 55,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141D2E) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.withAlpha(80)),
                    ),
                    child: currentBase64.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              base64Decode(currentBase64),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.draw_rounded, size: 20, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                        Text(currentBase64.isNotEmpty ? 'Foto TTD tersimpan' : 'Belum ada foto TTD', style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final picked = await _pickTtdImage();
                      if (picked != null) {
                        setM(() => onChanged(picked));
                      }
                    },
                    icon: const Icon(Icons.upload_file_rounded, size: 14),
                    label: const Text('Upload', style: TextStyle(fontSize: 11)),
                  ),
                  if (currentBase64.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                      tooltip: 'Hapus TTD',
                      onPressed: () => setM(() => onChanged('')),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            );
          }

          return Container(
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
                              'Konfigurasi Legalitas & TTD PDF (Admin)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark),
                            ),
                            Text(
                              'Data sekolah & foto TTD berlaku untuk semua cetakan PDF',
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Data Sekolah
                  TextField(
                    controller: schoolNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Sekolah',
                      prefixIcon: Icon(Icons.school_outlined),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(labelText: 'Kota', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: academicYearCtrl,
                          decoration: const InputDecoration(labelText: 'Tahun Ajaran', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Kepala Sekolah
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: kepsekNameCtrl,
                          decoration: const InputDecoration(labelText: 'Nama Kepala Sekolah', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: kepsekNipCtrl,
                          decoration: const InputDecoration(labelText: 'NIP Kepala Sekolah', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pembina OSIS
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: pembinaNameCtrl,
                          decoration: const InputDecoration(labelText: 'Nama Pembina OSIS', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: pembinaNipCtrl,
                          decoration: const InputDecoration(labelText: 'NIP Pembina OSIS', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Ketos & Sekretaris
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ketosNameCtrl,
                          decoration: const InputDecoration(labelText: 'Nama Ketua OSIS', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: ketosNisCtrl,
                          decoration: const InputDecoration(labelText: 'NIS Ketua OSIS', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sekretarisNameCtrl,
                          decoration: const InputDecoration(labelText: 'Nama Sekretaris OSIS', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: sekretarisNisCtrl,
                          decoration: const InputDecoration(labelText: 'NIS Sekretaris OSIS', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // FOTO TANDA TANGAN (TTD) DIGITAL
                  Text(
                    'UPLOAD FOTO TANDA TANGAN (TTD) DIGITAL',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF38BDF8) : kPrimary, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 12),

                  buildTtdUploadTile('TTD Pembina OSIS', ttdPembina, (val) => ttdPembina = val),
                  buildTtdUploadTile('TTD Ketua OSIS', ttdKetos, (val) => ttdKetos = val),
                  buildTtdUploadTile('TTD Kepala Sekolah', ttdKepsek, (val) => ttdKepsek = val),
                  buildTtdUploadTile('TTD Sekretaris OSIS', ttdSekretaris, (val) => ttdSekretaris = val),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: isSaving ? null : () async {
                      setM(() => isSaving = true);
                      await AppSettingsService.saveAdminConfigs(
                        schoolName: schoolNameCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        academicYear: academicYearCtrl.text.trim(),
                        kepsekName: kepsekNameCtrl.text.trim(),
                        kepsekNip: kepsekNipCtrl.text.trim(),
                        pembinaName: pembinaNameCtrl.text.trim(),
                        pembinaNip: pembinaNipCtrl.text.trim(),
                        ketosName: ketosNameCtrl.text.trim(),
                        ketosNis: ketosNisCtrl.text.trim(),
                        sekretarisName: sekretarisNameCtrl.text.trim(),
                        sekretarisNis: sekretarisNisCtrl.text.trim(),
                        ttdKepsek: ttdKepsek,
                        ttdPembina: ttdPembina,
                        ttdKetos: ttdKetos,
                        ttdSekretaris: ttdSekretaris,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white),
                                SizedBox(width: 10),
                                Expanded(child: Text('Data Legalitas & Foto TTD berhasil disinkronkan ke semua user!')),
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
                    label: Text(isSaving ? 'Menyimpan ke Cloud...' : 'Simpan Legalitas & TTD ke Semua User'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _tab.dispose();
    super.dispose();
  }

  bool _loading = false;

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && _pelanggaran.isEmpty && _siswa.isEmpty) setState(() => _loading = true);
    final s = await DataService.getSiswa();
    final j = await DataService.getJenis();
    final p = await DataService.getPelanggaran();
    if (!mounted) return;
    setState(() { _siswa = s; _jenis = j; _pelanggaran = p; _loading = false; });
  }

  Map<String, int> get _rekapPerKelas {
    final map = <String, int>{};
    for (final s in _siswa) {
      if (s.kelas.isNotEmpty) {
        map[s.kelas] = 0;
      }
    }
    for (final p in _filteredPelanggaran) {
      final siswa = _siswa.firstWhere((s) => s.id == p.siswaId,
          orElse: () => Siswa(id: '', nama: '', kelas: '', nis: ''));
      final kelas = siswa.kelas;
      if (kelas.isNotEmpty) {
        map[kelas] = (map[kelas] ?? 0) + 1;
      }
    }
    return map;
  }

  List<Pelanggaran> get _filteredPelanggaran {
    final now = DateTime.now();
    if (_filterPeriod == 'hari_ini') {
      return _pelanggaran.where((p) =>
        p.tanggal.year == now.year && p.tanggal.month == now.month && p.tanggal.day == now.day
      ).toList();
    }
    if (_filterPeriod == 'minggu') {
      return _pelanggaran.where((p) => p.tanggal.isAfter(now.subtract(const Duration(days: 7)))).toList();
    }
    if (_filterPeriod == 'bulan') {
      return _pelanggaran.where((p) => p.tanggal.year == now.year && p.tanggal.month == now.month).toList();
    }
    if (_filterPeriod == 'tahun') {
      return _pelanggaran.where((p) => p.tanggal.year == now.year).toList();
    }
    if (_filterPeriod == 'custom' && _customDateRange != null) {
      final start = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      final end = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
      return _pelanggaran.where((p) =>
        !p.tanggal.isBefore(start) && !p.tanggal.isAfter(end)
      ).toList();
    }
    return _pelanggaran;
  }

  String get _periodeLabel {
    final lang = LocalizationService.currentLocale.value.languageCode;
    if (_filterPeriod == 'hari_ini') return lang == 'en' ? 'Today (${DateFormat('dd MMM yyyy', lang).format(DateTime.now())})' : 'Hari Ini (${DateFormat('dd MMM yyyy', lang).format(DateTime.now())})';
    if (_filterPeriod == 'minggu') return lang == 'en' ? 'Last 7 Days Recap' : 'Rekap 7 Hari Terakhir';
    if (_filterPeriod == 'bulan') return lang == 'en' ? 'Month of ${DateFormat('MMMM yyyy', lang).format(DateTime.now())}' : 'Rekap Bulan ${DateFormat('MMMM yyyy', lang).format(DateTime.now())}';
    if (_filterPeriod == 'tahun') return lang == 'en' ? 'Year ${DateTime.now().year}' : 'Rekap Tahun ${DateTime.now().year}';
    if (_filterPeriod == 'custom' && _customDateRange != null) {
      final startStr = DateFormat('dd MMM yyyy', lang).format(_customDateRange!.start);
      final endStr = DateFormat('dd MMM yyyy', lang).format(_customDateRange!.end);
      return '$startStr - $endStr';
    }
    return lang == 'en' ? 'All Time' : 'Semua Waktu';
  }

  Map<String, int> get _rekapPerJenis {
    final map = <String, int>{};
    for (final p in _filteredPelanggaran) { map[p.jenisId] = (map[p.jenisId] ?? 0) + 1; }
    return map;
  }

  // map siswaId -> frekuensi
  Map<String, int> get _rekapPerSiswa {
    final map = <String, int>{};
    for (final p in _filteredPelanggaran) { map[p.siswaId] = (map[p.siswaId] ?? 0) + 1; }
    return map;
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      helpText: 'PILIH RENTANG TANGGAL REKAP',
      cancelText: 'BATAL',
      confirmText: 'TERAPKAN',
      saveText: 'PILIH',
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _filterPeriod = 'custom';
      });
    }
  }

  void _showExportPdfModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: isDark ? const Border(top: BorderSide(color: Color(0xFF243452), width: 1)) : null,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withAlpha(isDark ? 45 : 25), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Cetak Rekap PDF', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                Text('Periode: $_periodeLabel (${_filteredPelanggaran.length} data)',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : kTextMid)),
              ])),
            ]),
            const SizedBox(height: 16),
            Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            ListTile(
              leading: const Icon(Icons.category_outlined, color: kAccent),
              title: const Text('Rekap Berdasarkan Jenis Pelanggaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('Tabel total frekuensi per kategori jenis', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : null)),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.cetakRekap(siswa: _siswa, jenis: _jenis, pelanggaran: _filteredPelanggaran, perJenis: true, periodeLabel: _periodeLabel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: kAccent),
              title: const Text('Rekap Peringkat Siswa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('Peringkat siswa paling sering melanggar', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : null)),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.cetakRekap(siswa: _siswa, jenis: _jenis, pelanggaran: _filteredPelanggaran, perJenis: false, periodeLabel: _periodeLabel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_outlined, color: kAccent),
              title: const Text('Rekap Berdasarkan Kelas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('Distribusi jumlah pelanggaran per kelas', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : null)),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.cetakRekapKelas(siswa: _siswa, pelanggaran: _filteredPelanggaran, periodeLabel: _periodeLabel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined, color: Colors.indigoAccent),
              title: const Text('Rekap Lengkap (Semua)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigoAccent)),
              subtitle: Text('Gabungan jenis, kelas, dan peringkat siswa', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : null)),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.cetakRekapLengkap(siswa: _siswa, jenis: _jenis, pelanggaran: _filteredPelanggaran, periodeLabel: _periodeLabel);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cetakPdf(bool perJenis) async {
    _showExportPdfModal();
  }

  Future<void> _kirimWa(String siswaId, {List<Pelanggaran>? specificPelanggaran}) async {
    final siswa = _siswa.firstWhere((s) => s.id == siswaId);
    final pel = specificPelanggaran ?? _pelanggaran.where((p) => p.siswaId == siswaId).toList();

    final Map<String, int> freqJenis = {};
    for (final p in pel) { freqJenis[p.jenisId] = (freqJenis[p.jenisId] ?? 0) + 1; }

    final buffer = StringBuffer();
    buffer.writeln("Assalamu'alaikum Bapak/Ibu,");
    buffer.writeln('Izin menyampaikan rekap pelanggaran disiplin atas nama:');
    buffer.writeln('');
    buffer.writeln('Nama    : ${siswa.nama}');
    buffer.writeln('Kelas   : ${siswa.kelas}');
    buffer.writeln('NIS     : ${siswa.nis}');
    buffer.writeln('Periode : $_periodeLabel');
    buffer.writeln('');
    buffer.writeln('Rincian Pelanggaran:');
    int no = 1;
    for (final entry in freqJenis.entries) {
      final j = _jenis.firstWhere((e) => e.id == entry.key, orElse: () => JenisPelanggaran(id: '', nama: '-'));
      buffer.writeln('$no. ${j.nama} (${entry.value}x)');
      no++;
    }
    buffer.writeln('');
    buffer.writeln('Total: ${pel.length} pelanggaran');
    buffer.writeln('');
    buffer.writeln('Detail terlampir dalam file PDF.');
    buffer.writeln('Mohon bimbingannya. Terima kasih.');
    buffer.writeln('Hormat kami, Pengurus OSIS');

    final pdfBytes = await PdfService.generateRekapSiswaBytes(
      siswa: siswa, jenis: _jenis, pelanggaran: pel, periodeLabel: _periodeLabel);
    final dir = await getTemporaryDirectory();
    final safeName = siswa.nama.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    final file = File('${dir.path}/rekap_$safeName.pdf');
    await file.writeAsBytes(pdfBytes);

    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      text: buffer.toString(),
      subject: 'Rekap Pelanggaran - ${siswa.nama}',
    ));
  }

  void _showDetailJenis(JenisPelanggaran jenis) {
    final pelMatching = _filteredPelanggaran.where((p) => p.jenisId == jenis.id).toList();

    // Map kelas -> count untuk grafik per kelas
    final Map<String, int> freqKelas = {};
    for (final p in pelMatching) {
      final s = _siswa.firstWhere((e) => e.id == p.siswaId, orElse: () => Siswa(id: '', nama: '-', kelas: 'Lainnya', nis: ''));
      final k = s.kelas.isEmpty ? 'Lainnya' : s.kelas;
      freqKelas[k] = (freqKelas[k] ?? 0) + 1;
    }
    final sortedKelasList = freqKelas.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final double maxKelasY = sortedKelasList.isEmpty ? 5.0 : (sortedKelasList.first.value + 2).toDouble();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: isDark ? const Border(top: BorderSide(color: Color(0xFF243452), width: 1)) : null,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kAccent,
                child: const Icon(Icons.report_problem, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(jenis.nama, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                Text(_periodeLabel, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : kTextLight, fontSize: 11)),
              ])),
            ]),
            const SizedBox(height: 12),
            _statCard('${pelMatching.length}', 'Total Kejadian', Colors.red.shade50, Colors.red.shade700, isDark: isDark),
            const SizedBox(height: 16),

            if (sortedKelasList.isNotEmpty) ...[
              Text('Grafik Distribusi Kelas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
              const SizedBox(height: 8),
              Container(
                height: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E1626) : kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: isDark ? Border.all(color: const Color(0xFF243452)) : null,
                ),
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxKelasY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => kAccent,
                      getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                        'Kelas ${sortedKelasList[g.x.toInt()].key}\n${rod.toY.toInt()}x',
                        const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  barGroups: sortedKelasList.take(6).toList().asMap().entries.map((e) {
                    return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
                      toY: e.value.value.toDouble(),
                      gradient: const LinearGradient(colors: [kAccent, kPrimaryDark], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                      width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    )]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      final displayed = sortedKelasList.take(6).toList();
                      if (idx < 0 || idx >= displayed.length) return const SizedBox();
                      final kName = displayed[idx].key;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(kName.length > 5 ? kName.substring(0, 5) : kName, style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : kTextMid)),
                      );
                    })),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                )),
              ),
              const SizedBox(height: 16),
            ],

            Text('Rincian Siswa Melanggar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 8),
            pelMatching.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Tidak ada rincian data.', style: TextStyle(color: isDark ? const Color(0xFF64748B) : kTextLight))),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pelMatching.length,
                      separatorBuilder: (_, i) => Divider(height: 1, color: isDark ? const Color(0xFF243452) : kPrimary),
                      itemBuilder: (ctx, i) {
                        final p = pelMatching[i];
                        final s = _siswa.firstWhere((e) => e.id == p.siswaId, orElse: () => Siswa(id: '', nama: '-', kelas: '-', nis: '-'));
                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showDetailSiswa(s);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 10, top: 4),
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: kAccent)),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.nama, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : kTextDark)),
                                Text('Kelas ${s.kelas} • NIS ${s.nis} • ${DateFormat('dd MMM yyyy', 'id').format(p.tanggal)}',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : kTextLight)),
                                if (p.keterangan.isNotEmpty)
                                  Text(p.keterangan, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : kTextMid, fontStyle: FontStyle.italic)),
                              ])),
                              Icon(Icons.chevron_right, size: 18, color: isDark ? const Color(0xFF64748B) : kTextLight),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailKelas(String kelas) {
    final pelMatching = _filteredPelanggaran.where((p) {
      final s = _siswa.firstWhere((e) => e.id == p.siswaId, orElse: () => Siswa(id: '', nama: '', kelas: '', nis: ''));
      return s.kelas == kelas;
    }).toList();

    // Map jenisId -> count
    final Map<String, int> freqJenis = {};
    for (final p in pelMatching) {
      freqJenis[p.jenisId] = (freqJenis[p.jenisId] ?? 0) + 1;
    }
    final sortedJenisList = freqJenis.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final double maxJenisY = sortedJenisList.isEmpty ? 5.0 : (sortedJenisList.first.value + 2).toDouble();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: isDark ? const Border(top: BorderSide(color: Color(0xFF243452), width: 1)) : null,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kPrimaryDark,
                child: const Icon(Icons.school, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kelas $kelas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                Text(_periodeLabel, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : kTextLight, fontSize: 11)),
              ])),
            ]),
            const SizedBox(height: 12),
            _statCard('${pelMatching.length}', 'Total Pelanggaran Kelas', Colors.blue.shade50, Colors.blue.shade700, isDark: isDark),
            const SizedBox(height: 16),

            if (sortedJenisList.isNotEmpty) ...[
              Text('Grafik Jenis Pelanggaran di Kelas Ini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
              const SizedBox(height: 8),
              Container(
                height: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E1626) : kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: isDark ? Border.all(color: const Color(0xFF243452)) : null,
                ),
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxJenisY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => kAccent,
                      getTooltipItem: (g, gi, rod, ri) {
                        final jId = sortedJenisList[g.x.toInt()].key;
                        final jObj = _jenis.firstWhere((e) => e.id == jId, orElse: () => JenisPelanggaran(id: '', nama: '-'));
                        return BarTooltipItem(
                          '${jObj.nama}\n${rod.toY.toInt()}x',
                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  barGroups: sortedJenisList.take(6).toList().asMap().entries.map((e) {
                    return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
                      toY: e.value.value.toDouble(),
                      gradient: const LinearGradient(colors: [kPrimaryDark, kAccent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                      width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    )]);
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      final displayed = sortedJenisList.take(6).toList();
                      if (idx < 0 || idx >= displayed.length) return const SizedBox();
                      final jId = displayed[idx].key;
                      final jObj = _jenis.firstWhere((e) => e.id == jId, orElse: () => JenisPelanggaran(id: '', nama: '-'));
                      final jName = jObj.nama;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(jName.length > 5 ? jName.substring(0, 5) : jName, style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : kTextMid)),
                      );
                    })),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                )),
              ),
              const SizedBox(height: 16),
            ],

            Text('Rincian Siswa Melanggar di Kelas Ini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 8),
            pelMatching.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Tidak ada rincian data.', style: TextStyle(color: isDark ? const Color(0xFF64748B) : kTextLight))),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pelMatching.length,
                      separatorBuilder: (_, i) => Divider(height: 1, color: isDark ? const Color(0xFF243452) : kPrimary),
                      itemBuilder: (ctx, i) {
                        final p = pelMatching[i];
                        final s = _siswa.firstWhere((e) => e.id == p.siswaId, orElse: () => Siswa(id: '', nama: '-', kelas: '-', nis: '-'));
                        final j = _jenis.firstWhere((e) => e.id == p.jenisId, orElse: () => JenisPelanggaran(id: '', nama: '-'));
                        return InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showDetailSiswa(s);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 10, top: 4),
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: kAccent)),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s.nama, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : kTextDark)),
                                Text('${j.nama} • ${DateFormat('dd MMM yyyy', 'id').format(p.tanggal)}',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : kTextLight)),
                                if (p.keterangan.isNotEmpty)
                                  Text(p.keterangan, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : kTextMid, fontStyle: FontStyle.italic)),
                              ])),
                              Icon(Icons.chevron_right, size: 18, color: isDark ? const Color(0xFF64748B) : kTextLight),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Cetak PDF Kelas', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      PdfService.cetakRekapDetailKelas(
                        kelas: kelas,
                        siswa: _siswa,
                        jenis: _jenis,
                        pelanggaran: pelMatching,
                        periodeLabel: _periodeLabel,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : kTextDark,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSiswa(Siswa siswa) {
    final pelanggaranSiswa = _filteredPelanggaran.where((p) => p.siswaId == siswa.id).toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: isDark ? const Border(top: BorderSide(color: Color(0xFF243452), width: 1)) : null,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(radius: 26, backgroundColor: isDark ? const Color(0xFF1A263D) : kPrimary,
                child: Text(siswa.nama.isNotEmpty ? siswa.nama.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(siswa.nama, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                Text('Kelas ${siswa.kelas} • NIS ${siswa.nis}', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : kTextMid, fontSize: 13)),
                Text(_periodeLabel, style: TextStyle(color: isDark ? const Color(0xFF64748B) : kTextLight, fontSize: 11)),
              ])),
            ]),
            const SizedBox(height: 12),
            _statCard('${pelanggaranSiswa.length}', 'Total Pelanggaran', Colors.orange.shade50, Colors.orange.shade700, isDark: isDark),
            const SizedBox(height: 16),
            Text('Riwayat Pelanggaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 8),
            pelanggaranSiswa.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Tidak ada pelanggaran pada periode ini.', style: TextStyle(color: isDark ? const Color(0xFF64748B) : kTextLight))),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pelanggaranSiswa.length,
                      separatorBuilder: (_, i) => Divider(height: 1, color: isDark ? const Color(0xFF243452) : kPrimary),
                      itemBuilder: (ctx, i) {
                        final p = pelanggaranSiswa[i];
                        final j = _jenis.firstWhere((e) => e.id == p.jenisId, orElse: () => JenisPelanggaran(id: '', nama: '-'));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 10, top: 4),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: kAccent)),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(j.nama, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : kTextDark)),
                              Text(DateFormat('dd MMMM yyyy', 'id').format(p.tanggal),
                                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : kTextLight)),
                              if (p.keterangan.isNotEmpty)
                                Text(p.keterangan, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : kTextMid, fontStyle: FontStyle.italic)),
                            ])),
                          ]),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Kirim WA', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () { Navigator.pop(ctx); _kirimWa(siswa.id, specificPelanggaran: pelanggaranSiswa); },
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Cetak PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () { Navigator.pop(ctx); PdfService.cetakRekapSiswa(siswa: siswa, jenis: _jenis, pelanggaran: pelanggaranSiswa, periodeLabel: _periodeLabel); },
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String value, String label, Color bg, Color fg, {bool isDark = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: isDark ? fg.withAlpha(35) : bg,
      borderRadius: BorderRadius.circular(12),
      border: isDark ? Border.all(color: fg.withAlpha(70)) : null,
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : fg)),
      Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : fg, fontWeight: FontWeight.w500)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final rekapJenis = _rekapPerJenis;
    final rekapSiswa = _rekapPerSiswa;
    final rekapKelasMap = _rekapPerKelas;
    final sortedSiswa = rekapSiswa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedKelasList = rekapKelasMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final double maxY = rekapJenis.values.isEmpty ? 10.0 : (rekapJenis.values.reduce((a, b) => a > b ? a : b) + 2).toDouble();
    final double maxKelasY = sortedKelasList.isEmpty ? 10.0 : (sortedKelasList.first.value + 2).toDouble();

    final cardBg = isDark ? const Color(0xFF141D2E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0);
    final chartBg = isDark ? const Color(0xFF0E1626) : kBg;
    final textTitle = isDark ? Colors.white : kTextDark;
    final textSub = isDark ? const Color(0xFF94A3B8) : kTextMid;
    final textMuted = isDark ? const Color(0xFF64748B) : kTextLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(LocalizationService.tr('rekap_heading')),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: LocalizationService.currentLocale.value.languageCode == 'en' ? 'By Type' : 'Per Jenis'),
            Tab(text: LocalizationService.currentLocale.value.languageCode == 'en' ? 'By Student' : 'Per Siswa'),
            Tab(text: LocalizationService.currentLocale.value.languageCode == 'en' ? 'By Class' : 'Per Kelas'),
          ],
        ),
        actions: [
          if (_isAdmin || _isPembina) ...[
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.amber),
              onPressed: _showAdminConfigRekap,
              tooltip: 'Konfigurasi Legalitas & TTD PDF (Admin)',
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: LocalizationService.tr('btn_refresh'),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: () => _cetakPdf(_tab.index == 0),
            tooltip: LocalizationService.tr('btn_print'),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: isDark ? const Color(0xFF0D1424) : Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('semua', LocalizationService.tr('btn_all'), Icons.all_inclusive, isDark: isDark, primary: primary),
              const SizedBox(width: 8),
              _filterChip('hari_ini', LocalizationService.currentLocale.value.languageCode == 'en' ? 'Today' : 'Hari Ini', Icons.today, isDark: isDark, primary: primary),
              const SizedBox(width: 8),
              _filterChip('minggu', LocalizationService.currentLocale.value.languageCode == 'en' ? '7 Days' : '7 Hari', Icons.calendar_view_week, isDark: isDark, primary: primary),
              const SizedBox(width: 8),
              _filterChip('bulan', LocalizationService.currentLocale.value.languageCode == 'en' ? 'Monthly' : 'Bulanan', Icons.calendar_month, isDark: isDark, primary: primary),
              const SizedBox(width: 8),
              _filterChip('tahun', LocalizationService.currentLocale.value.languageCode == 'en' ? 'Yearly' : 'Tahunan', Icons.calendar_today, isDark: isDark, primary: primary),
              const SizedBox(width: 8),
              _customDateFilterChip(isDark: isDark, primary: primary),
            ]),
          ),
        ),
        if (_filterPeriod == 'custom' && _customDateRange != null)
          Container(
            color: isDark ? primary.withAlpha(35) : kAccent.withAlpha(25),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.date_range, size: 14, color: primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rentang: $_periodeLabel',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kPrimaryDark),
                  ),
                ),
                InkWell(
                  onTap: _pickCustomDateRange,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ubah', style: TextStyle(fontSize: 12, color: primary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 14, color: primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: primary))
              : TabBarView(controller: _tab, children: [
                  // Tab Per Jenis
                  _filteredPelanggaran.isEmpty
                      ? _emptyState('Belum ada data pelanggaran', isDark: isDark)
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Grafik Distribusi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textTitle)),
                                  Text('(Ketuk batang untuk detail)', style: TextStyle(fontSize: 11, color: textMuted, fontStyle: FontStyle.italic)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: cardBorder),
                                  boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 8)],
                                ),
                                child: SizedBox(
                                  height: 200,
                                  child: BarChart(BarChartData(
                                    alignment: BarChartAlignment.spaceAround,
                                    maxY: maxY,
                                    barTouchData: BarTouchData(
                                      touchCallback: (FlTouchEvent event, barTouchResponse) {
                                        if (event is FlTapUpEvent && barTouchResponse != null && barTouchResponse.spot != null) {
                                          final idx = barTouchResponse.spot!.touchedBarGroupIndex;
                                          if (idx >= 0 && idx < _jenis.length) {
                                            _showDetailJenis(_jenis[idx]);
                                          }
                                        }
                                      },
                                      touchTooltipData: BarTouchTooltipData(
                                        getTooltipColor: (_) => primary,
                                        getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
                                          '${_jenis[g.x.toInt()].nama}\n${rod.toY.toInt()} kali\n(Ketuk untuk detail)',
                                          const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    barGroups: _jenis.asMap().entries.map((e) {
                                      final count = rekapJenis[e.value.id] ?? 0;
                                      return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
                                        toY: count.toDouble(),
                                        gradient: LinearGradient(colors: isDark ? [primary.withAlpha(160), primary] : [kPrimaryDark, kAccent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                        width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: chartBg),
                                      )]);
                                    }).toList(),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                                        getTitlesWidget: (v, _) {
                                          final idx = v.toInt();
                                          if (idx < 0 || idx >= _jenis.length) return const SizedBox();
                                          final nm = _jenis[idx].nama;
                                          return Padding(padding: const EdgeInsets.only(top: 6),
                                              child: Text(nm.length > 7 ? '${nm.substring(0, 7)}..' : nm,
                                                  style: TextStyle(fontSize: 9, color: textSub, fontWeight: FontWeight.bold)));
                                        },
                                      )),
                                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                                        getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(fontSize: 9, color: textMuted)))),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(show: true, drawVerticalLine: false,
                                        getDrawingHorizontalLine: (_) => FlLine(color: isDark ? const Color(0xFF243452) : kPrimary, strokeWidth: 0.5)),
                                    borderData: FlBorderData(show: false),
                                  )),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text('Rincian per Jenis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textTitle)),
                              const SizedBox(height: 8),
                              ..._jenis.map((j) {
                                final count = rekapJenis[j.id] ?? 0;
                                return InkWell(
                                  onTap: () => _showDetailJenis(j),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: cardBorder),
                                      boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(50), blurRadius: 4)],
                                    ),
                                    child: Row(children: [
                                      Expanded(child: Text(j.nama, style: TextStyle(fontWeight: FontWeight.bold, color: textTitle, fontSize: 14))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: count > 0 ? primary : (isDark ? const Color(0xFF243452) : Colors.grey.shade300),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text('$count kali', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chevron_right, color: textMuted, size: 20),
                                    ]),
                                  ),
                                );
                              }),
                            ]),
                          ),
                        ),

                  // Tab Per Siswa
                  _filteredPelanggaran.isEmpty
                      ? _emptyState('Belum ada data pelanggaran', isDark: isDark)
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: primary,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            itemCount: sortedSiswa.length,
                            itemBuilder: (_, i) {
                              final entry = sortedSiswa[i];
                              final siswa = _siswa.firstWhere((s) => s.id == entry.key, orElse: () => Siswa(id: '', nama: '-', kelas: '', nis: ''));
                              final rank = i + 1;
                              return InkWell(
                                onTap: () => _showDetailSiswa(siswa),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: cardBorder),
                                    boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 6, offset: const Offset(0, 2))],
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: rank <= 3 ? [primary, kPrimaryDark, const Color(0xFFB2EBF2)][rank - 1] : (isDark ? const Color(0xFF1A263D) : kBg),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(child: Text('$rank',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                              color: rank <= 2 ? Colors.white : (isDark ? Colors.white : kTextDark)))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(siswa.nama, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textTitle)),
                                      Text('Kelas ${siswa.kelas} • NIS: ${siswa.nis}', style: TextStyle(fontSize: 12, color: textSub)),
                                      const SizedBox(height: 4),
                                      _badge('${entry.value}x pelanggaran', Colors.orange.shade700, Colors.orange.withAlpha(isDark ? 45 : 30)),
                                    ])),
                                    Icon(Icons.chevron_right, color: textMuted),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),

                  // Tab Per Kelas
                   RefreshIndicator(
                          onRefresh: _load,
                          color: primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Grafik Distribusi per Kelas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textTitle)),
                                    Text('(Ketuk untuk detail)', style: TextStyle(fontSize: 11, color: textMuted, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: cardBorder),
                                    boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 8)],
                                  ),
                                  child: SizedBox(
                                    height: 180,
                                    child: BarChart(BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: maxKelasY,
                                      barTouchData: BarTouchData(
                                        touchCallback: (FlTouchEvent event, barTouchResponse) {
                                          if (event is FlTapUpEvent && barTouchResponse != null && barTouchResponse.spot != null) {
                                            final idx = barTouchResponse.spot!.touchedBarGroupIndex;
                                            final displayed = sortedKelasList.take(8).toList();
                                            if (idx >= 0 && idx < displayed.length) {
                                              _showDetailKelas(displayed[idx].key);
                                            }
                                          }
                                        },
                                        touchTooltipData: BarTouchTooltipData(
                                          getTooltipColor: (_) => primary,
                                          getTooltipItem: (g, gi, rod, ri) {
                                            final displayed = sortedKelasList.take(8).toList();
                                            final kName = g.x.toInt() < displayed.length ? displayed[g.x.toInt()].key : '';
                                            return BarTooltipItem(
                                              'Kelas $kName\n${rod.toY.toInt()} pelanggaran',
                                              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            );
                                          },
                                        ),
                                      ),
                                      barGroups: sortedKelasList.take(8).toList().asMap().entries.map((e) {
                                        return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
                                          toY: e.value.value.toDouble(),
                                          gradient: LinearGradient(colors: isDark ? [primary.withAlpha(160), primary] : [kAccent, kPrimaryDark], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                          width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxKelasY, color: chartBg),
                                        )]);
                                      }).toList(),
                                      titlesData: FlTitlesData(
                                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                                          getTitlesWidget: (v, _) {
                                            final idx = v.toInt();
                                            final displayed = sortedKelasList.take(8).toList();
                                            if (idx < 0 || idx >= displayed.length) return const SizedBox();
                                            final kName = displayed[idx].key;
                                            return Padding(padding: const EdgeInsets.only(top: 6),
                                                child: Text(kName, style: TextStyle(fontSize: 10, color: textSub, fontWeight: FontWeight.bold)));
                                          },
                                        )),
                                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                                          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: TextStyle(fontSize: 9, color: textMuted)))),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      gridData: FlGridData(show: true, drawVerticalLine: false,
                                          getDrawingHorizontalLine: (_) => FlLine(color: isDark ? const Color(0xFF243452) : kPrimary, strokeWidth: 0.5)),
                                      borderData: FlBorderData(show: false),
                                    )),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text('Daftar Rekap Kelas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textTitle)),
                                const SizedBox(height: 10),
                                // Search bar for class filter
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Cari kelas...',
                                    prefixIcon: Icon(Icons.search, color: primary, size: 20),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  ),
                                  onChanged: (v) => setState(() => _searchKelas = v),
                                ),
                                const SizedBox(height: 12),
                                // List of classes
                                ...rekapKelasMap.entries
                                    .where((e) => _searchKelas.isEmpty || e.key.toLowerCase().contains(_searchKelas.toLowerCase()))
                                    .toList()
                                    .sorted((a, b) => b.value.compareTo(a.value))
                                    .map((entry) {
                                  final kelas = entry.key;
                                  final count = entry.value;
                                  return InkWell(
                                    onTap: () => _showDetailKelas(kelas),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: cardBorder),
                                        boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(50), blurRadius: 4)],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text('Kelas $kelas', style: TextStyle(fontWeight: FontWeight.bold, color: textTitle, fontSize: 14))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: primary,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text('$count pelanggaran', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.chevron_right, color: textMuted, size: 20),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                ]),
        ),
      ]),
    );
  }

  Widget _badge(String text, Color fg, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _filterChip(String value, String label, IconData icon, {bool isDark = false, Color primary = kAccent}) {
    final selected = _filterPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _filterPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary
              : (isDark ? const Color(0xFF141D2E) : kPrimary.withAlpha(60)),
          borderRadius: BorderRadius.circular(20),
          border: isDark && !selected ? Border.all(color: const Color(0xFF243452)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : kTextMid)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : kTextMid))),
        ]),
      ),
    );
  }

  Widget _customDateFilterChip({bool isDark = false, Color primary = kAccent}) {
    final isCustom = _filterPeriod == 'custom';
    return GestureDetector(
      onTap: () {
        _pickCustomDateRange();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isCustom
              ? (isDark ? primary : Colors.indigo)
              : (isDark ? const Color(0xFF141D2E) : kPrimary.withAlpha(60)),
          borderRadius: BorderRadius.circular(20),
          border: isDark && !isCustom ? Border.all(color: const Color(0xFF243452)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.date_range, size: 14, color: isCustom ? Colors.white : (isDark ? const Color(0xFF94A3B8) : kTextMid)),
          const SizedBox(width: 6),
          Text(
            _customDateRange != null && isCustom
                ? '${DateFormat('dd/MM', 'id').format(_customDateRange!.start)} - ${DateFormat('dd/MM', 'id').format(_customDateRange!.end)}'
                : 'Pilih Tanggal...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCustom ? Colors.white : (isDark ? const Color(0xFF94A3B8) : kTextMid),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState(String msg, {bool isDark = false}) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.bar_chart, size: 64, color: isDark ? const Color(0xFF64748B) : kTextLight),
    const SizedBox(height: 12),
    Text(msg, style: TextStyle(fontSize: 15, color: isDark ? const Color(0xFF94A3B8) : kTextMid)),
  ]));
}
