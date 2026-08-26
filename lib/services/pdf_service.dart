import 'dart:typed_data';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'app_settings_service.dart';

class PdfService {
  static final _primaryColor = PdfColor.fromHex('#2F3E46');
  static final _secondaryColor = PdfColor.fromHex('#354F52');
  static final _headerBgColor = PdfColor.fromHex('#52796F');

  static pw.Widget _footer(pw.Context context) => pw.Column(children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Dokumen ini dihasilkan secara digital oleh ${AppSettingsService.appNameNotifier.value}.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ]);

  static pw.Widget _signatureBlock({required String tanggal}) {
    final city = AppSettingsService.cityNotifier.value;
    final kepsek = AppSettingsService.kepsekNameNotifier.value;
    final kepsekNip = AppSettingsService.kepsekNipNotifier.value;
    final pembina = AppSettingsService.pembinaNameNotifier.value;
    final pembinaNip = AppSettingsService.pembinaNipNotifier.value;
    final ketos = AppSettingsService.ketosNameNotifier.value;
    final ketosNis = AppSettingsService.ketosNisNotifier.value;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('$city, $tanggal', style: const pw.TextStyle(fontSize: 9)),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Mengetahui,\nPembina OSIS', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 38),
                pw.Text(pembina, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                pw.Text('NIP. $pembinaNip', style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Ketua OSIS', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 38),
                pw.Text(ketos, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                pw.Text('NIS. $ketosNis', style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('Menyetujui,\nKepala Sekolah', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5)),
                pw.SizedBox(height: 38),
                pw.Text(kepsek, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline)),
                pw.Text('NIP. $kepsekNip', style: const pw.TextStyle(fontSize: 7.5)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.TableBorder _tableBorder() => pw.TableBorder(
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        horizontalInside: const pw.BorderSide(color: PdfColors.grey300, width: 0.5),
      );

  static Future<void> cetakRekap({
    required List<Siswa> siswa,
    required List<JenisPelanggaran> jenis,
    required List<Pelanggaran> pelanggaran,
    required bool perJenis,
    String periodeLabel = 'Semua Waktu',
  }) async {
    final pdf = pw.Document();
    final tanggal = DateFormat('dd MMMM yyyy', 'id').format(DateTime.now());

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => pw.Column(children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('LAPORAN JURNAL OSIS & STAF SEKOLAH',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
              pw.Text('REKAP PELANGGARAN SISWA',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Tanggal Cetak: $tanggal', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Periode: $periodeLabel',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _headerBgColor)),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2.5, color: _primaryColor),
        pw.SizedBox(height: 16),
      ]),
      build: (ctx) => [
        if (perJenis) ...[
          pw.Text('Rekap Berdasarkan Jenis Pelanggaran',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            border: _tableBorder(),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
            headerDecoration: pw.BoxDecoration(
                color: _headerBgColor,
                borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['No', 'Jenis Pelanggaran', 'Frekuensi'],
            data: jenis.asMap().entries.map((e) {
              final count = pelanggaran.where((p) => p.jenisId == e.value.id).length;
              return ['${e.key + 1}', e.value.nama, '$count kali'];
            }).toList(),
          ),
        ] else ...[
          pw.Text('Rekap Berdasarkan Peringkat Pelanggaran Murid',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            border: _tableBorder(),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
            headerDecoration: pw.BoxDecoration(
                color: _headerBgColor,
                borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['No', 'Nama Siswa', 'Kelas', 'NIS', 'Frekuensi'],
            data: () {
              final List<Map<String, dynamic>> siswaData = [];
              for (final s in siswa) {
                final sPelanggaran = pelanggaran.where((p) => p.siswaId == s.id).toList();
                if (sPelanggaran.isEmpty) continue;
                siswaData.add({'siswa': s, 'count': sPelanggaran.length});
              }
              siswaData.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
              return siswaData.asMap().entries.map((e) {
                final s = e.value['siswa'] as Siswa;
                return ['${e.key + 1}', s.nama, s.kelas, s.nis, '${e.value['count']} kali'];
              }).toList();
            }(),
          ),
        ],
        pw.SizedBox(height: 32),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('Pengurus OSIS / Staf Kesiswaan', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 45),
              pw.Container(width: 120, height: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 2),
              pw.Text('Tim Penilai Disiplin Sekolah',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ]),
          ],
        ),
      ],
      footer: _footer,
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  static Future<void> cetakRekapKelas({
    required List<Siswa> siswa,
    required List<Pelanggaran> pelanggaran,
    String periodeLabel = 'Semua Waktu',
  }) async {
    final pdf = pw.Document();
    final tanggal = DateFormat('dd MMMM yyyy', 'id').format(DateTime.now());

    // Map kelas -> count
    final Map<String, int> kelasCount = {};
    for (final s in siswa) {
      if (s.kelas.isNotEmpty) {
        kelasCount[s.kelas] = 0;
      }
    }
    for (final p in pelanggaran) {
      final s = siswa.firstWhere((e) => e.id == p.siswaId, orElse: () => Siswa(id: '', nama: '', kelas: 'Lainnya', nis: ''));
      final k = s.kelas.isEmpty ? 'Lainnya' : s.kelas;
      kelasCount[k] = (kelasCount[k] ?? 0) + 1;
    }
    final sortedKelas = kelasCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => pw.Column(children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('LAPORAN JURNAL OSIS & STAF SEKOLAH',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
              pw.Text('REKAP PELANGGARAN PER KELAS',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Tanggal Cetak: $tanggal', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Periode: $periodeLabel',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _headerBgColor)),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2.5, color: _primaryColor),
        pw.SizedBox(height: 16),
      ]),
      build: (ctx) => [
        pw.Text('Distribusi Pelanggaran Siswa Berdasarkan Kelas',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          border: _tableBorder(),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
          headerDecoration: pw.BoxDecoration(
              color: _headerBgColor,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
          cellAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 9),
          headers: ['No', 'Kelas', 'Jumlah Pelanggaran', 'Status Tingkat Disiplin'],
          data: sortedKelas.asMap().entries.map((e) {
            final count = e.value.value;
            String status = 'Sangat Tertib';
            if (count > 15) {
              status = 'Perlu Perhatian Khusus';
            } else if (count > 8) {
              status = 'Perhatian Sedang';
            } else if (count > 0) {
              status = 'Cukup Baik';
            }
            return ['${e.key + 1}', 'Kelas ${e.value.key}', '$count kali', status];
          }).toList(),
        ),
        _signatureBlock(tanggal: tanggal),
      ],
      footer: _footer,
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  static Future<void> cetakRekapLengkap({
    required List<Siswa> siswa,
    required List<JenisPelanggaran> jenis,
    required List<Pelanggaran> pelanggaran,
    String periodeLabel = 'Semua Waktu',
  }) async {
    final pdf = pw.Document();
    final tanggal = DateFormat('dd MMMM yyyy', 'id').format(DateTime.now());

    // Map kelas
    final Map<String, int> kelasCount = {};
    for (final s in siswa) {
      if (s.kelas.isNotEmpty) kelasCount[s.kelas] = 0;
    }
    for (final p in pelanggaran) {
      final s = siswa.firstWhere((e) => e.id == p.siswaId, orElse: () => Siswa(id: '', nama: '', kelas: 'Lainnya', nis: ''));
      final k = s.kelas.isEmpty ? 'Lainnya' : s.kelas;
      kelasCount[k] = (kelasCount[k] ?? 0) + 1;
    }
    final sortedKelas = kelasCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    // Siswa ranking
    final List<Map<String, dynamic>> siswaData = [];
    for (final s in siswa) {
      final sPelanggaran = pelanggaran.where((p) => p.siswaId == s.id).toList();
      if (sPelanggaran.isEmpty) continue;
      siswaData.add({'siswa': s, 'count': sPelanggaran.length});
    }
    siswaData.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => pw.Column(children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('LAPORAN JURNAL OSIS & STAF SEKOLAH',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
              pw.Text('LAPORAN REKAP DISIPLIN LENGKAP',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Tanggal Cetak: $tanggal', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Periode: $periodeLabel',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _headerBgColor)),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2.5, color: _primaryColor),
        pw.SizedBox(height: 16),
      ]),
      build: (ctx) => [
        // Ringkasan Statistik Box
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Column(children: [
                pw.Text('${pelanggaran.length}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
                pw.Text('Total Kejadian', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ]),
              pw.Column(children: [
                pw.Text('${siswaData.length}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
                pw.Text('Siswa Melanggar', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ]),
              pw.Column(children: [
                pw.Text('${jenis.length}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
                pw.Text('Kategori Jenis', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 16),

        // Section 1: Per Jenis
        pw.Text('1. Rekap Berdasarkan Jenis Pelanggaran',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          border: _tableBorder(),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: _headerBgColor),
          cellAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          headers: ['No', 'Jenis Pelanggaran', 'Frekuensi'],
          data: jenis.asMap().entries.map((e) {
            final count = pelanggaran.where((p) => p.jenisId == e.value.id).length;
            return ['${e.key + 1}', e.value.nama, '$count kali'];
          }).toList(),
        ),
        pw.SizedBox(height: 20),

        // Section 2: Per Kelas
        pw.Text('2. Rekap Berdasarkan Kelas',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          border: _tableBorder(),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
          headerDecoration: pw.BoxDecoration(color: _headerBgColor),
          cellAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          headers: ['No', 'Kelas', 'Jumlah Pelanggaran'],
          data: sortedKelas.asMap().entries.map((e) => ['${e.key + 1}', 'Kelas ${e.value.key}', '${e.value.value} kali']).toList(),
        ),
        pw.SizedBox(height: 20),

        // Section 3: Peringkat Siswa
        pw.Text('3. Peringkat Pelanggaran Siswa',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
        pw.SizedBox(height: 6),
        if (siswaData.isEmpty)
          pw.Text('Tidak ada data pelanggaran siswa pada periode ini.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500))
        else
          pw.TableHelper.fromTextArray(
            border: _tableBorder(),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: _headerBgColor),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headers: ['No', 'Nama Siswa', 'Kelas', 'NIS', 'Frekuensi'],
            data: siswaData.asMap().entries.map((e) {
              final s = e.value['siswa'] as Siswa;
              return ['${e.key + 1}', s.nama, s.kelas, s.nis, '${e.value['count']} kali'];
            }).toList(),
          ),

        _signatureBlock(tanggal: tanggal),
      ],
      footer: _footer,
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  static Future<void> cetakRekapDetailKelas({
    required String kelas,
    required List<Siswa> siswa,
    required List<JenisPelanggaran> jenis,
    required List<Pelanggaran> pelanggaran,
    String periodeLabel = 'Semua Waktu',
  }) async {
    final pdf = pw.Document();
    final tanggal = DateFormat('dd MMMM yyyy', 'id').format(DateTime.now());
    String namaJenis(String id) =>
        jenis.firstWhere((j) => j.id == id, orElse: () => JenisPelanggaran(id: '', nama: '-')).nama;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => pw.Column(children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('LAPORAN JURNAL OSIS & STAF SEKOLAH',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
              pw.Text('REKAP DISIPLIN KELAS $kelas',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Tanggal Cetak: $tanggal', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Periode: $periodeLabel',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _headerBgColor)),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2.5, color: _primaryColor),
        pw.SizedBox(height: 16),
      ]),
      build: (ctx) => [
        pw.Text('Daftar Rincian Pelanggaran Siswa Kelas $kelas',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
        pw.SizedBox(height: 8),
        if (pelanggaran.isEmpty)
          pw.Text('Tidak ada catatan pelanggaran untuk kelas ini pada periode yang dipilih.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
        else
          pw.TableHelper.fromTextArray(
            border: _tableBorder(),
            headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
            headerDecoration: pw.BoxDecoration(color: _headerBgColor),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headers: ['No', 'Tanggal', 'Nama Siswa', 'NIS', 'Pelanggaran', 'Keterangan'],
            data: pelanggaran.asMap().entries.map((e) {
              final s = siswa.firstWhere((x) => x.id == e.value.siswaId, orElse: () => Siswa(id: '', nama: '-', kelas: kelas, nis: '-'));
              return [
                '${e.key + 1}',
                DateFormat('dd/MM/yyyy', 'id').format(e.value.tanggal),
                s.nama,
                s.nis,
                namaJenis(e.value.jenisId),
                e.value.keterangan.isNotEmpty ? e.value.keterangan : '-',
              ];
            }).toList(),
          ),
        pw.SizedBox(height: 32),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('Pengurus OSIS / Staf Kesiswaan', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 45),
              pw.Container(width: 120, height: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 2),
              pw.Text('Tim Penilai Disiplin Sekolah',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ]),
          ],
        ),
      ],
      footer: _footer,
    ));

    await Printing.layoutPdf(onLayout: (_) => pdf.save());
  }

  static Future<void> cetakRekapSiswa({
    required Siswa siswa,
    required List<JenisPelanggaran> jenis,
    required List<Pelanggaran> pelanggaran,
    String periodeLabel = 'Semua Waktu',
  }) async {
    final bytes = await generateRekapSiswaBytes(siswa: siswa, jenis: jenis, pelanggaran: pelanggaran, periodeLabel: periodeLabel);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<Uint8List> generateRekapSiswaBytes({
    required Siswa siswa,
    required List<JenisPelanggaran> jenis,
    required List<Pelanggaran> pelanggaran,
    String periodeLabel = 'Semua Waktu',
  }) async {
    final pdf = pw.Document();
    final tanggal = DateFormat('dd MMMM yyyy', 'id').format(DateTime.now());
    String namaJenis(String id) =>
        jenis.firstWhere((j) => j.id == id, orElse: () => JenisPelanggaran(id: '', nama: '-')).nama;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (context) => pw.Column(children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('LAPORAN JURNAL OSIS & STAF SEKOLAH',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
              pw.Text('REKAP PELANGGARAN INDIVIDUAL SISWA',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Tanggal Cetak: $tanggal', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Periode: $periodeLabel',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _headerBgColor)),
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 2.5, color: _primaryColor),
        pw.SizedBox(height: 16),
      ]),
      build: (ctx) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Nama Siswa : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.TextSpan(text: siswa.nama, style: const pw.TextStyle(fontSize: 10)),
            ])),
            pw.SizedBox(height: 4),
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'Kelas          : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.TextSpan(text: siswa.kelas, style: const pw.TextStyle(fontSize: 10)),
            ])),
            pw.SizedBox(height: 4),
            pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: 'NIS              : ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.TextSpan(text: siswa.nis, style: const pw.TextStyle(fontSize: 10)),
            ])),
          ]),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Detail Riwayat Pelanggaran Tercatat',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
        pw.SizedBox(height: 8),
        pw.TableHelper.fromTextArray(
          border: _tableBorder(),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
          headerDecoration: pw.BoxDecoration(
              color: _headerBgColor,
              borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
          cellAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 9),
          headers: ['No', 'Tanggal', 'Jenis Pelanggaran', 'Keterangan'],
          data: pelanggaran.asMap().entries.map((e) => [
                '${e.key + 1}',
                DateFormat('dd/MM/yyyy', 'id').format(e.value.tanggal),
                namaJenis(e.value.jenisId),
                e.value.keterangan.isNotEmpty ? e.value.keterangan : '-',
              ]).toList(),
        ),
      ],
      footer: _footer,
    ));
    return Uint8List.fromList(await pdf.save());
  }

  // ── Laporan Kegiatan PDF ─────────────────────────────────────────────────
  static Future<Uint8List> generateLaporanPdfBytes(LaporanKegiatan l) async {
    final pdf = pw.Document();
    final fmt = DateFormat('dd MMMM yyyy', 'id');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => pw.Column(children: [
        pw.Text('LAPORAN KEGIATAN OSIS',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _primaryColor)),
        pw.SizedBox(height: 4),
        pw.Container(height: 2, color: _primaryColor),
        pw.SizedBox(height: 12),
      ]),
      footer: _footer,
      build: (ctx) => [
        _lRow('Nama Kegiatan', l.judul),
        _lRow('Sekbid / Divisi', l.sekbid),
        _lRow('Penanggung Jawab', l.penanggungJawab),
        _lRow('Tanggal Kegiatan', fmt.format(l.tanggalKegiatan)),
        _lRow('Lokasi', l.lokasi.isNotEmpty ? l.lokasi : '-'),
        _lRow('Status', l.status),
        pw.SizedBox(height: 12),
        if (l.deskripsi.isNotEmpty) ...[
          _lSection('Deskripsi / Latar Belakang'),
          pw.Text(l.deskripsi, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
        ],
        if (l.hasilCapaian.isNotEmpty) ...[
          _lSection('Hasil & Capaian Kegiatan'),
          pw.Text(l.hasilCapaian, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
        ],
        if (l.kendalaSaran.isNotEmpty) ...[
          _lSection('Kendala & Saran'),
          pw.Text(l.kendalaSaran, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 10),
        ],
        if (l.peserta.isNotEmpty) ...[
          _lSection('Daftar Peserta (${l.peserta.length})'),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 8, runSpacing: 4,
            children: l.peserta.map((p) => pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(p, style: const pw.TextStyle(fontSize: 9)),
            )).toList(),
          ),
          pw.SizedBox(height: 10),
        ],
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('Dibuat oleh: ${l.pembuatId}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('Tanggal: ${fmt.format(l.tanggalBuat)}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 40),
              pw.Container(width: 120, height: 0.5, color: PdfColors.black),
              pw.SizedBox(height: 2),
              pw.Text(l.penanggungJawab,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ]),
          ],
        ),
      ],
    ));
    return Uint8List.fromList(await pdf.save());
  }

  static pw.Widget _lRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 130,
          child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
      pw.Text(': ', style: const pw.TextStyle(fontSize: 10)),
      pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 10))),
    ]),
  );

  static pw.Widget _lSection(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Text(title,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _secondaryColor)),
  );

  // ── Laporan Kegiatan DOCX ────────────────────────────────────────────────
  static Future<File> generateLaporanDocx(LaporanKegiatan l) async {
    final fmt = DateFormat('dd MMMM yyyy', 'id');

    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');

    String row(String label, String value) =>
        '<w:tr><w:tc><w:tcPr><w:tcW w:w="2500" w:type="dxa"/></w:tcPr>'
        '<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>${esc(label)}</w:t></w:r></w:p></w:tc>'
        '<w:tc><w:p><w:r><w:t>${esc(value)}</w:t></w:r></w:p></w:tc></w:tr>';

    String section(String title, String content) =>
        '<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr>'
        '<w:r><w:t>${esc(title)}</w:t></w:r></w:p>'
        '<w:p><w:r><w:t xml:space="preserve">${esc(content)}</w:t></w:r></w:p>';

    final pesertaXml = l.peserta.isEmpty ? '' :
        '<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>Daftar Peserta (${l.peserta.length})</w:t></w:r></w:p>${l.peserta.map((p) =>
            '<w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr>'
            '<w:r><w:t>${esc(p)}</w:t></w:r></w:p>').join()}';

    final docXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
<w:p><w:pPr><w:jc w:val="center"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="32"/></w:rPr><w:t>LAPORAN KEGIATAN OSIS</w:t></w:r>
</w:p>
<w:p><w:pPr><w:jc w:val="center"/></w:pPr>
  <w:r><w:rPr><w:b/><w:sz w:val="24"/></w:rPr><w:t>${esc(l.judul)}</w:t></w:r>
</w:p>
<w:p/>
<w:tbl>
  <w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="0" w:type="auto"/></w:tblPr>
  <w:tblGrid><w:gridCol w:w="2500"/><w:gridCol w:w="6500"/></w:tblGrid>
  ${row('Sekbid / Divisi', l.sekbid)}
  ${row('Penanggung Jawab', l.penanggungJawab)}
  ${row('Tanggal Kegiatan', fmt.format(l.tanggalKegiatan))}
  ${row('Lokasi', l.lokasi.isNotEmpty ? l.lokasi : '-')}
  ${row('Status', l.status)}
</w:tbl>
<w:p/>
${l.deskripsi.isNotEmpty ? section('Deskripsi / Latar Belakang', l.deskripsi) : ''}
${l.hasilCapaian.isNotEmpty ? section('Hasil & Capaian Kegiatan', l.hasilCapaian) : ''}
${l.kendalaSaran.isNotEmpty ? section('Kendala & Saran', l.kendalaSaran) : ''}
$pesertaXml
<w:p/>
<w:p><w:pPr><w:jc w:val="right"/></w:pPr>
  <w:r><w:t>Dibuat oleh: ${esc(l.pembuatId)}, ${esc(fmt.format(l.tanggalBuat))}</w:t></w:r>
</w:p>
<w:sectPr/>
</w:body>
</w:document>''';

    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    const wordRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    const stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:rPr><w:b/><w:sz w:val="24"/></w:rPr>
  </w:style>
  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:tblPr><w:tblBorders>
      <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
    </w:tblBorders></w:tblPr>
  </w:style>
</w:styles>''';

    encode(String s) => Uint8List.fromList(s.codeUnits);

    final archive = Archive()
      ..addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, encode(contentTypesXml)))
      ..addFile(ArchiveFile('_rels/.rels', relsXml.length, encode(relsXml)))
      ..addFile(ArchiveFile('word/document.xml', docXml.length, encode(docXml)))
      ..addFile(ArchiveFile('word/styles.xml', stylesXml.length, encode(stylesXml)))
      ..addFile(ArchiveFile('word/_rels/document.xml.rels', wordRelsXml.length, encode(wordRelsXml)));

    final zipBytes = ZipEncoder().encode(archive)!;
    final dir = await getTemporaryDirectory();
    final safeTitle = l.judul.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    final file = File('${dir.path}/laporan_$safeTitle.docx');
    await file.writeAsBytes(zipBytes);
    return file;
  }
}