import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/pdf_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
    if (_filterPeriod == 'hari_ini') return 'Hari Ini (${DateFormat('dd MMM yyyy', 'id').format(DateTime.now())})';
    if (_filterPeriod == 'minggu') return 'Rekap 7 Hari Terakhir';
    if (_filterPeriod == 'bulan') return 'Rekap Bulan ${DateFormat('MMMM yyyy', 'id').format(DateTime.now())}';
    if (_filterPeriod == 'tahun') return 'Rekap Tahun ${DateTime.now().year}';
    if (_filterPeriod == 'custom' && _customDateRange != null) {
      final startStr = DateFormat('dd MMM yyyy', 'id').format(_customDateRange!.start);
      final endStr = DateFormat('dd MMM yyyy', 'id').format(_customDateRange!.end);
      return '$startStr s/d $endStr';
    }
    return 'Semua Waktu';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Cetak Rekap PDF', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextDark)),
                Text('Periode: $_periodeLabel (${_filteredPelanggaran.length} data)',
                    style: const TextStyle(fontSize: 12, color: kTextMid)),
              ])),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.category_outlined, color: kAccent),
              title: const Text('Rekap Berdasarkan Jenis Pelanggaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Tabel total frekuensi per kategori jenis', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.cetakRekap(siswa: _siswa, jenis: _jenis, pelanggaran: _filteredPelanggaran, perJenis: true, periodeLabel: _periodeLabel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline, color: kAccent),
              title: const Text('Rekap Peringkat Siswa', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Peringkat siswa paling sering melanggar', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.cetakRekap(siswa: _siswa, jenis: _jenis, pelanggaran: _filteredPelanggaran, perJenis: false, periodeLabel: _periodeLabel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_outlined, color: kAccent),
              title: const Text('Rekap Berdasarkan Kelas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Distribusi jumlah pelanggaran per kelas', style: TextStyle(fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.cetakRekapKelas(siswa: _siswa, pelanggaran: _filteredPelanggaran, periodeLabel: _periodeLabel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined, color: Colors.indigo),
              title: const Text('Rekap Lengkap (Semua)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.indigo)),
              subtitle: const Text('Gabungan jenis, kelas, dan peringkat siswa', style: TextStyle(fontSize: 11)),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kAccent,
                child: const Icon(Icons.report_problem, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(jenis.nama, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextDark)),
                Text(_periodeLabel, style: const TextStyle(color: kTextLight, fontSize: 11)),
              ])),
            ]),
            const SizedBox(height: 12),
            _statCard('${pelMatching.length}', 'Total Kejadian', Colors.red.shade50, Colors.red.shade700),
            const SizedBox(height: 16),

            if (sortedKelasList.isNotEmpty) ...[
              const Text('Grafik Distribusi Kelas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
              const SizedBox(height: 8),
              Container(
                height: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12)),
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
                      if (idx < 0 || idx >= sortedKelasList.take(6).length) return const SizedBox();
                      final kName = sortedKelasList[idx].key;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(kName.length > 5 ? kName.substring(0, 5) : kName, style: const TextStyle(fontSize: 9, color: kTextMid)),
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

            const Text('Rincian Siswa Melanggar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
            const SizedBox(height: 8),
            pelMatching.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Tidak ada rincian data.', style: TextStyle(color: kTextLight))),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pelMatching.length,
                      separatorBuilder: (_, i) => const Divider(height: 1, color: kPrimary),
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
                                Text(s.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark)),
                                Text('Kelas ${s.kelas} • NIS ${s.nis} • ${DateFormat('dd MMM yyyy', 'id').format(p.tanggal)}',
                                    style: const TextStyle(fontSize: 11, color: kTextLight)),
                                if (p.keterangan.isNotEmpty)
                                  Text(p.keterangan, style: const TextStyle(fontSize: 12, color: kTextMid, fontStyle: FontStyle.italic)),
                              ])),
                              const Icon(Icons.chevron_right, size: 18, color: kTextLight),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: Colors.white,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kPrimaryDark,
                child: const Icon(Icons.school, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kelas $kelas', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextDark)),
                Text(_periodeLabel, style: const TextStyle(color: kTextLight, fontSize: 11)),
              ])),
            ]),
            const SizedBox(height: 12),
            _statCard('${pelMatching.length}', 'Total Pelanggaran Kelas', Colors.blue.shade50, Colors.blue.shade700),
            const SizedBox(height: 16),

            if (sortedJenisList.isNotEmpty) ...[
              const Text('Grafik Jenis Pelanggaran di Kelas Ini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
              const SizedBox(height: 8),
              Container(
                height: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(12)),
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
                      if (idx < 0 || idx >= sortedJenisList.take(6).length) return const SizedBox();
                      final jId = sortedJenisList[idx].key;
                      final jObj = _jenis.firstWhere((e) => e.id == jId, orElse: () => JenisPelanggaran(id: '', nama: '-'));
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(jObj.nama.length > 5 ? '${jObj.nama.substring(0, 5)}..' : jObj.nama, style: const TextStyle(fontSize: 9, color: kTextMid)),
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

            const Text('Daftar Pelanggaran Siswa Kelas Ini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
            const SizedBox(height: 8),
            pelMatching.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Tidak ada pelanggaran pada periode ini.', style: TextStyle(color: kTextLight))),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pelMatching.length,
                      separatorBuilder: (_, i) => const Divider(height: 1, color: kPrimary),
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
                                Text(s.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark)),
                                Text('${j.nama} • ${DateFormat('dd MMM yyyy', 'id').format(p.tanggal)}',
                                    style: const TextStyle(fontSize: 11, color: kTextLight)),
                                if (p.keterangan.isNotEmpty)
                                  Text(p.keterangan, style: const TextStyle(fontSize: 12, color: kTextMid, fontStyle: FontStyle.italic)),
                              ])),
                              const Icon(Icons.chevron_right, size: 18, color: kTextLight),
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
                      foregroundColor: kTextDark,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(radius: 26, backgroundColor: kPrimary,
                child: Text(siswa.nama.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(siswa.nama, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextDark)),
                Text('Kelas ${siswa.kelas} • NIS ${siswa.nis}', style: const TextStyle(color: kTextMid, fontSize: 13)),
                Text(_periodeLabel, style: const TextStyle(color: kTextLight, fontSize: 11)),
              ])),
            ]),
            const SizedBox(height: 12),
            _statCard('${pelanggaranSiswa.length}', 'Total Pelanggaran', Colors.orange.shade50, Colors.orange.shade700),
            const SizedBox(height: 16),
            const Text('Riwayat Pelanggaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
            const SizedBox(height: 8),
            pelanggaranSiswa.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('Tidak ada pelanggaran pada periode ini.', style: TextStyle(color: kTextLight))),
                  )
                : ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pelanggaranSiswa.length,
                      separatorBuilder: (_, i) => const Divider(height: 1, color: kPrimary),
                      itemBuilder: (ctx, i) {
                        final p = pelanggaranSiswa[i];
                        final j = _jenis.firstWhere((e) => e.id == p.jenisId, orElse: () => JenisPelanggaran(id: '', nama: '-'));
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 10, top: 4),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: kAccent)),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(j.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark)),
                              Text(DateFormat('dd MMMM yyyy', 'id').format(p.tanggal),
                                  style: const TextStyle(fontSize: 11, color: kTextLight)),
                              if (p.keterangan.isNotEmpty)
                                Text(p.keterangan, style: const TextStyle(fontSize: 12, color: kTextMid, fontStyle: FontStyle.italic)),
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

  Widget _statCard(String value, String label, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fg)),
      Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final rekapJenis = _rekapPerJenis;
    final rekapSiswa = _rekapPerSiswa;
    final rekapKelasMap = _rekapPerKelas;
    final sortedSiswa = rekapSiswa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedKelasList = rekapKelasMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final double maxY = rekapJenis.values.isEmpty ? 10.0 : (rekapJenis.values.reduce((a, b) => a > b ? a : b) + 2).toDouble();
    final double maxKelasY = sortedKelasList.isEmpty ? 10.0 : (sortedKelasList.first.value + 2).toDouble();

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Rekap Pelanggaran'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Per Jenis'), Tab(text: 'Per Siswa'), Tab(text: 'Per Kelas')]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
            tooltip: 'Reload',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
            onPressed: () => _cetakPdf(_tab.index == 0),
            tooltip: 'Cetak PDF',
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filterChip('semua', 'Semua', Icons.all_inclusive),
              const SizedBox(width: 8),
              _filterChip('hari_ini', 'Hari Ini', Icons.today),
              const SizedBox(width: 8),
              _filterChip('minggu', '7 Hari', Icons.calendar_view_week),
              const SizedBox(width: 8),
              _filterChip('bulan', 'Bulanan', Icons.calendar_month),
              const SizedBox(width: 8),
              _filterChip('tahun', 'Tahunan', Icons.calendar_today),
              const SizedBox(width: 8),
              _customDateFilterChip(),
            ]),
          ),
        ),
        if (_filterPeriod == 'custom' && _customDateRange != null)
          Container(
            color: kAccent.withAlpha(25),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 14, color: kAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rentang: $_periodeLabel',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kPrimaryDark),
                  ),
                ),
                InkWell(
                  onTap: _pickCustomDateRange,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text('Ubah', style: TextStyle(fontSize: 12, color: kAccent, fontWeight: FontWeight.bold)),
                      SizedBox(width: 4),
                      Icon(Icons.edit_outlined, size: 14, color: kAccent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const Divider(height: 1, color: kPrimary),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(controller: _tab, children: [
                  // Tab Per Jenis
                  _filteredPelanggaran.isEmpty
                      ? _emptyState('Belum ada data pelanggaran')
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: kAccent,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Text('Grafik Distribusi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark)),
                                  Text('(Ketuk batang untuk detail)', style: TextStyle(fontSize: 11, color: kTextLight, fontStyle: FontStyle.italic)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 8)]),
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
                                        getTooltipColor: (_) => kAccent,
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
                                        gradient: const LinearGradient(colors: [kPrimaryDark, kAccent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                        width: 20, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                        backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: kBg),
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
                                                  style: const TextStyle(fontSize: 9, color: kTextMid, fontWeight: FontWeight.bold)));
                                        },
                                      )),
                                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                                        getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9, color: kTextLight)))),
                                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                    ),
                                    gridData: FlGridData(show: true, drawVerticalLine: false,
                                        getDrawingHorizontalLine: (_) => const FlLine(color: kPrimary, strokeWidth: 0.5)),
                                    borderData: FlBorderData(show: false),
                                  )),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text('Rincian per Jenis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark)),
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
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: count > 0 ? kPrimary : const Color(0xFFEEEEEE)),
                                      boxShadow: [BoxShadow(color: kPrimary.withAlpha(50), blurRadius: 4)],
                                    ),
                                    child: Row(children: [
                                      Expanded(child: Text(j.nama, style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark, fontSize: 14))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: count > 0 ? kAccent : Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text('$count kali', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right, color: kTextLight, size: 20),
                                    ]),
                                  ),
                                );
                              }),
                            ]),
                          ),
                        ),

                  // Tab Per Siswa
                  _filteredPelanggaran.isEmpty
                      ? _emptyState('Belum ada data pelanggaran')
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: kAccent,
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
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 6, offset: const Offset(0, 2))],
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: rank <= 3 ? [kAccent, kPrimaryDark, const Color(0xFFB2EBF2)][rank - 1] : kBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(child: Text('$rank',
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                                              color: rank <= 2 ? Colors.white : kTextDark))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(siswa.nama, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextDark)),
                                      Text('Kelas ${siswa.kelas} • NIS: ${siswa.nis}', style: const TextStyle(fontSize: 12, color: kTextLight)),
                                      const SizedBox(height: 4),
                                      _badge('${entry.value}x pelanggaran', Colors.orange.shade700, Colors.orange.shade50),
                                    ])),
                                    const Icon(Icons.chevron_right, color: kTextLight),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),

                  // Tab Per Kelas
                   RefreshIndicator(
                          onRefresh: _load,
                          color: kAccent,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    Text('Grafik Distribusi per Kelas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark)),
                                    Text('(Ketuk untuk detail)', style: TextStyle(fontSize: 11, color: kTextLight, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                                      boxShadow: [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 8)]),
                                  child: SizedBox(
                                    height: 180,
                                    child: BarChart(BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      maxY: maxKelasY,
                                      barTouchData: BarTouchData(
                                        touchCallback: (FlTouchEvent event, barTouchResponse) {
                                          if (event is FlTapUpEvent && barTouchResponse != null && barTouchResponse.spot != null) {
                                            final idx = barTouchResponse.spot!.touchedBarGroupIndex;
                                            final displayedKelas = sortedKelasList.take(8).toList();
                                            if (idx >= 0 && idx < displayedKelas.length) {
                                              _showDetailKelas(displayedKelas[idx].key);
                                            }
                                          }
                                        },
                                        touchTooltipData: BarTouchTooltipData(
                                          getTooltipColor: (_) => kAccent,
                                          getTooltipItem: (g, gi, rod, ri) {
                                            final displayedKelas = sortedKelasList.take(8).toList();
                                            final kName = displayedKelas[g.x.toInt()].key;
                                            return BarTooltipItem(
                                              'Kelas $kName\n${rod.toY.toInt()} pelanggaran\n(Ketuk untuk detail)',
                                              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            );
                                          },
                                        ),
                                      ),
                                      barGroups: sortedKelasList.take(8).toList().asMap().entries.map((e) {
                                        return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
                                          toY: e.value.value.toDouble(),
                                          gradient: const LinearGradient(colors: [kAccent, kPrimaryDark], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                          width: 18, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                          backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxKelasY, color: kBg),
                                        )]);
                                      }).toList(),
                                      titlesData: FlTitlesData(
                                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
                                          getTitlesWidget: (v, _) {
                                            final idx = v.toInt();
                                            final displayedKelas = sortedKelasList.take(8).toList();
                                            if (idx < 0 || idx >= displayedKelas.length) return const SizedBox();
                                            final nm = displayedKelas[idx].key;
                                            return Padding(padding: const EdgeInsets.only(top: 6),
                                                child: Text(nm.length > 6 ? '${nm.substring(0, 6)}..' : nm,
                                                    style: const TextStyle(fontSize: 9, color: kTextMid, fontWeight: FontWeight.bold)));
                                          },
                                        )),
                                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24,
                                          getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 9, color: kTextLight)))),
                                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                      ),
                                      gridData: FlGridData(show: true, drawVerticalLine: false,
                                          getDrawingHorizontalLine: (_) => const FlLine(color: kPrimary, strokeWidth: 0.5)),
                                      borderData: FlBorderData(show: false),
                                    )),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text('Daftar Rekap Kelas', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark)),
                                const SizedBox(height: 10),
                                // Search bar for class filter
                                TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Cari kelas...',
                                    prefixIcon: Icon(Icons.search, color: kAccent, size: 20),
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: kPrimary),
                                        boxShadow: [BoxShadow(color: kPrimary.withAlpha(50), blurRadius: 4)],
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(child: Text('Kelas $kelas', style: const TextStyle(fontWeight: FontWeight.bold, color: kTextDark, fontSize: 14))),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: kAccent,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text('$count pelanggaran', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.chevron_right, color: kTextLight, size: 20),
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

  Widget _filterChip(String value, String label, IconData icon) {
    final selected = _filterPeriod == value;
    return GestureDetector(
      onTap: () => setState(() => _filterPeriod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kAccent : kPrimary.withAlpha(60),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : kTextMid),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : kTextMid)),
        ]),
      ),
    );
  }

  Widget _customDateFilterChip() {
    final isCustom = _filterPeriod == 'custom';
    return GestureDetector(
      onTap: () {
        if (!isCustom) {
          _pickCustomDateRange();
        } else {
          _pickCustomDateRange();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isCustom ? Colors.indigo : kPrimary.withAlpha(60),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.date_range, size: 14, color: isCustom ? Colors.white : kTextMid),
          const SizedBox(width: 6),
          Text(
            _customDateRange != null && isCustom
                ? '${DateFormat('dd/MM', 'id').format(_customDateRange!.start)} - ${DateFormat('dd/MM', 'id').format(_customDateRange!.end)}'
                : 'Pilih Tanggal...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isCustom ? Colors.white : kTextMid,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState(String msg) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.bar_chart, size: 64, color: kTextLight),
    const SizedBox(height: 12),
    Text(msg, style: const TextStyle(fontSize: 15, color: kTextMid)),
  ]));
}
