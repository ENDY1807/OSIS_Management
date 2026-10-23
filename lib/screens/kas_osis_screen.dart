import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/nusantara_decorations.dart';

class KasOsisScreen extends StatefulWidget {
  final String username;
  final int initialTab;

  const KasOsisScreen({
    super.key,
    required this.username,
    this.initialTab = 0,
  });

  @override
  State<KasOsisScreen> createState() => _KasOsisScreenState();
}

class _KasOsisScreenState extends State<KasOsisScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  StreamSubscription<String>? _dataSub;

  List<AnggotaOsis> _anggotaList = [];
  List<KasOsisSession> _kasSessions = [];
  List<KasOsisTransaksi> _transaksiList = [];
  List<AbsensiOsisSession> _absensiSessions = [];

  KasOsisSession? _selectedKasSession;
  AbsensiOsisSession? _selectedAbsensiSession;

  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

  bool get _canEdit => !AuthService.isReadOnly(widget.username);

  bool get _isBendahara =>
      widget.username == 'BENDAHARA' ||
      widget.username == 'ADMIN' ||
      widget.username == 'KETUA' ||
      widget.username == 'WAKIL' ||
      widget.username == 'PEMBINA';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });

    _loadData();

    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'kas_osis' ||
          table == 'absensi_osis' ||
          table == 'kas_transaksi' ||
          table == 'anggota_osis' ||
          table == 'all') {
        _loadData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _dataSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final anggota = await DataService.getAnggotaOsis();
      final kasList = await DataService.getKasOsisSessions();
      final trxList = await DataService.getKasTransaksi();
      final absensiList = await DataService.getAbsensiOsisSessions();

      if (!mounted) return;
      setState(() {
        _anggotaList = anggota;
        _kasSessions = kasList;
        _transaksiList = trxList;
        _absensiSessions = absensiList;

        if (_kasSessions.isNotEmpty) {
          if (_selectedKasSession == null) {
            _selectedKasSession = _kasSessions.first;
          } else {
            final idx = _kasSessions.indexWhere((s) => s.id == _selectedKasSession!.id);
            _selectedKasSession = idx != -1 ? _kasSessions[idx] : _kasSessions.first;
          }
        }

        if (_absensiSessions.isNotEmpty) {
          if (_selectedAbsensiSession == null) {
            _selectedAbsensiSession = _absensiSessions.first;
          } else {
            final idx = _absensiSessions.indexWhere((s) => s.id == _selectedAbsensiSession!.id);
            _selectedAbsensiSession = idx != -1 ? _absensiSessions[idx] : _absensiSessions.first;
          }
        }

        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Error loading Kas OSIS data: $e');
    }
  }

  // ── FITUR IMPOR EXCEL KHUSUS OSIS ──────────────────────────────────────────

  Future<void> _pickAndImportExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final rawBytes = await file.readAsBytes();

      if (rawBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File Excel kosong atau tidak terbaca.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (!mounted) return;
      _showImportOptionsSheet(rawBytes, file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan impor Excel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImportOptionsSheet(Uint8List bytes, String fileName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final namaKegiatanCtrl = TextEditingController(
      text: 'Presensi Rapat OSIS ${DateFormat('d MMM yyyy', 'id_ID').format(DateTime.now())}',
    );
    final lokasiCtrl = TextEditingController(text: 'Ruang OSIS');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NusantaraColors.gold.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NusantaraColors.gold.withAlpha(120)),
                    ),
                    child: const Icon(Icons.table_view_rounded, color: NusantaraColors.gold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Impor File Excel OSIS',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nama Kegiatan / Rapat Sesi Absensi:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: namaKegiatanCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Contoh: Rapat Pleno OSIS',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Lokasi Kegiatan:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: lokasiCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Contoh: Ruang OSIS / Aula',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Pilihan 1: Buat Sesi Absensi & Update Anggota
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _loading = true);
                  final session = await DataService.importAbsensiOsisFromExcel(
                    bytes,
                    namaKegiatan: namaKegiatanCtrl.text.trim().isNotEmpty
                        ? namaKegiatanCtrl.text.trim()
                        : 'Sesi Absensi OSIS',
                    lokasi: lokasiCtrl.text.trim().isNotEmpty ? lokasiCtrl.text.trim() : 'Ruang OSIS',
                  );
                  await _loadData();
                  if (session != null) {
                    setState(() {
                      _selectedAbsensiSession = session;
                      _tabCtrl.animateTo(1); // Langsung pindah ke tab Absensi
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Berhasil membuat sesi absensi dengan ${session.items.length} anggota OSIS dari Excel!',
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tidak ada data anggota yang terbaca di file Excel ini.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.white),
                label: const Text('Buat Sesi Absensi Baru dari Excel Ini',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),

              // Tombol Pilihan 2: Perbarui Daftar Anggota OSIS Saja
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _loading = true);
                  final imported = await DataService.importAnggotaOsisFromExcel(bytes);
                  await _loadData();
                  setState(() {
                    _tabCtrl.animateTo(3); // Pindah ke tab Anggota OSIS
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Berhasil mengimpor ${imported.length} anggota OSIS ke sistem!'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.people_outline_rounded),
                label: const Text('Perbarui Daftar Anggota OSIS Saja'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Actions Kas OSIS ────────────────────────────────────────────────────────

  void _centangSemuaKas(bool sudahBayar) {
    if (_selectedKasSession == null || !_canEdit) return;
    setState(() {
      for (final item in _selectedKasSession!.items) {
        item.sudahBayar = sudahBayar;
        if (sudahBayar) {
          item.nominalBayar = _selectedKasSession!.nominalWajib;
          item.tanggalBayar = DateTime.now();
        } else {
          item.nominalBayar = 0;
          item.tanggalBayar = null;
        }
      }
    });
    _simpanKasSession(showToast: false);
  }

  Future<void> _simpanKasSession({bool showToast = true}) async {
    if (_selectedKasSession == null) return;
    try {
      _selectedKasSession!.updatedAt = DateTime.now();
      await DataService.saveKasOsisSession(_selectedKasSession!);

      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Catatan Kas "${_selectedKasSession!.judul}" berhasil disimpan.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan kas: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toggleBayarItem(KasOsisItem item) {
    if (!_canEdit) return;
    setState(() {
      item.sudahBayar = !item.sudahBayar;
      if (item.sudahBayar) {
        item.nominalBayar = _selectedKasSession?.nominalWajib ?? 5000;
        item.tanggalBayar = DateTime.now();
      } else {
        item.nominalBayar = 0;
        item.tanggalBayar = null;
      }
    });
    _simpanKasSession(showToast: false);
  }

  void _tambahSesiKasBaru() {
    final judulCtrl = TextEditingController(
      text: 'Iuran Kas Bulan ${DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now())}',
    );
    final nominalCtrl = TextEditingController(text: '5000');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_card_rounded, color: NusantaraColors.gold),
            SizedBox(width: 10),
            Text('Buat Sesi Kas OSIS Baru', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Judul / Periode Kas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: judulCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Contoh: Kas OSIS Oktober 2026',
              ),
            ),
            const SizedBox(height: 14),
            const Text('Nominal Iuran Wajib per Anggota (Rp):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: nominalCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final judul = judulCtrl.text.trim();
              final nominal = int.tryParse(nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5000;
              if (judul.isEmpty) return;

              Navigator.pop(ctx);
              final newId = 'kas-${DateTime.now().millisecondsSinceEpoch}';
              final items = _anggotaList.map((a) {
                return KasOsisItem(
                  anggotaId: a.id,
                  nama: a.nama,
                  kelas: a.kelas,
                  jabatan: a.jabatan,
                  nominalBayar: 0,
                  sudahBayar: false,
                );
              }).toList();

              final newSession = KasOsisSession(
                id: newId,
                judul: judul,
                tanggal: DateTime.now(),
                nominalWajib: nominal,
                items: items,
                updatedAt: DateTime.now(),
              );

              await DataService.saveKasOsisSession(newSession);
              await _loadData();
              setState(() => _selectedKasSession = newSession);
            },
            child: const Text('Buat Sesi'),
          ),
        ],
      ),
    );
  }

  void _shareRekapKasWhatsApp() {
    if (_selectedKasSession == null) return;
    final s = _selectedKasSession!;
    final lunas = s.items.where((i) => i.sudahBayar).toList();
    final belum = s.items.where((i) => !i.sudahBayar).toList();

    final buffer = StringBuffer();
    buffer.writeln('[REKAP KAS OSIS - ${s.judul.toUpperCase()}]');
    buffer.writeln('Tanggal: ${_dateFormat.format(s.tanggal)}');
    buffer.writeln('Iuran Wajib: ${_currencyFormat.format(s.nominalWajib)} / anggota');
    buffer.writeln('Terkumpul: *${_currencyFormat.format(s.totalTerkumpul)}* dari target ${_currencyFormat.format(s.totalTarget)} (${s.persentaseBayar.toStringAsFixed(1)}%)\n');

    buffer.writeln('[DAFTAR ANGGOTA SUDAH LUNAS (${lunas.length}/${s.items.length})]:');
    if (lunas.isEmpty) {
      buffer.writeln('(Belum ada anggota yang membayar)');
    } else {
      for (int i = 0; i < lunas.length; i++) {
        buffer.writeln('${i + 1}. ${lunas[i].nama} (${lunas[i].kelas}) - [LUNAS]');
      }
    }

    buffer.writeln('\n[DAFTAR ANGGOTA BELUM MEMBAYAR (${belum.length})]:');
    if (belum.isEmpty) {
      buffer.writeln('(Semua anggota OSIS telah lunas)');
    } else {
      for (int i = 0; i < belum.length; i++) {
        buffer.writeln('${i + 1}. ${belum[i].nama} (${belum[i].kelas})');
      }
    }

    buffer.writeln('\n_Sistem Kas OSIS SMK Bakti Nusantara 666_');

    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Rekap Kas OSIS: ${s.judul}'));
  }

  // ── Actions Absensi OSIS ───────────────────────────────────────────────────

  void _semuaHadirAbsensi() {
    if (_selectedAbsensiSession == null || !_canEdit) return;
    setState(() {
      for (final item in _selectedAbsensiSession!.items) {
        item.status = 'Hadir';
      }
    });
    _simpanAbsensiSession(showToast: false);
  }

  Future<void> _simpanAbsensiSession({bool showToast = true}) async {
    if (_selectedAbsensiSession == null) return;
    try {
      _selectedAbsensiSession!.updatedAt = DateTime.now();
      await DataService.saveAbsensiOsisSession(_selectedAbsensiSession!);

      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Presensi "${_selectedAbsensiSession!.namaKegiatan}" berhasil disimpan.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan presensi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _tambahSesiAbsensiBaru() {
    final kegiatanCtrl = TextEditingController(
      text: 'Rapat Evaluasi OSIS ${DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now())}',
    );
    final lokasiCtrl = TextEditingController(text: 'Ruang OSIS');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.how_to_reg_rounded, color: NusantaraColors.pandanGreen),
            SizedBox(width: 10),
            Text('Buat Sesi Absensi OSIS', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nama Kegiatan / Rapat:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: kegiatanCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Contoh: Rapat Mingguan Pengurus OSIS',
              ),
            ),
            const SizedBox(height: 14),
            const Text('Lokasi Kegiatan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: lokasiCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Contoh: Ruang OSIS / Perpustakaan',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Akan memuat ${_anggotaList.length} anggota OSIS resmi.',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final kegiatan = kegiatanCtrl.text.trim();
              if (kegiatan.isEmpty) return;

              Navigator.pop(ctx);
              final newId = 'abs-${DateTime.now().millisecondsSinceEpoch}';
              final items = _anggotaList.map((a) {
                return AbsensiOsisItem(
                  anggotaId: a.id,
                  nama: a.nama,
                  kelas: a.kelas,
                  jabatan: a.jabatan,
                  status: 'Hadir',
                );
              }).toList();

              final newSession = AbsensiOsisSession(
                id: newId,
                namaKegiatan: kegiatan,
                tanggal: DateTime.now(),
                lokasi: lokasiCtrl.text.trim().isNotEmpty ? lokasiCtrl.text.trim() : 'Ruang OSIS',
                items: items,
                updatedAt: DateTime.now(),
              );

              await DataService.saveAbsensiOsisSession(newSession);
              await _loadData();
              setState(() => _selectedAbsensiSession = newSession);
            },
            child: const Text('Mulai Absensi'),
          ),
        ],
      ),
    );
  }

  void _shareRekapAbsensiWhatsApp() {
    if (_selectedAbsensiSession == null) return;
    final s = _selectedAbsensiSession!;
    final buffer = StringBuffer();
    buffer.writeln('[PRESENSI KEGIATAN OSIS]');
    buffer.writeln('Kegiatan: *${s.namaKegiatan}*');
    buffer.writeln('Tanggal: ${_dateFormat.format(s.tanggal)}');
    buffer.writeln('Lokasi: ${s.lokasi}');
    buffer.writeln('Tingkat Kehadiran: *${s.persentaseHadir.toStringAsFixed(1)}%* (Hadir: ${s.totalHadir}, Izin: ${s.totalIzin}, Sakit: ${s.totalSakit}, Alpa: ${s.totalAlpa})\n');

    buffer.writeln('[RINCIAN KEHADIRAN ANGGOTA]:');
    for (int i = 0; i < s.items.length; i++) {
      final it = s.items[i];
      buffer.writeln('${i + 1}. [${it.status.toUpperCase()}] ${it.nama} (${it.kelas} - ${it.jabatan})');
    }

    buffer.writeln('\n_Dicatat melalui Jurnal OSIS Digital SMK Bakti Nusantara 666_');
    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Presensi OSIS: ${s.namaKegiatan}'));
  }

  // ── Actions Buku Kas & Transaksi ───────────────────────────────────────────

  void _tambahTransaksiBaru() {
    final jenisCtrl = ValueNotifier<String>('MASUK');
    final nominalCtrl = TextEditingController();
    final ketCtrl = TextEditingController();
    final kategoriCtrl = TextEditingController(text: 'Iuran');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: NusantaraColors.terracotta),
            SizedBox(width: 10),
            Text('Catat Mutasi Kas', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: ValueListenableBuilder<String>(
          valueListenable: jenisCtrl,
          builder: (context, jenis, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Kas Masuk')),
                        selected: jenis == 'MASUK',
                        selectedColor: const Color(0xFF10B981).withAlpha(50),
                        labelStyle: TextStyle(
                          color: jenis == 'MASUK' ? const Color(0xFF059669) : null,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) jenisCtrl.value = 'MASUK';
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Kas Keluar')),
                        selected: jenis == 'KELUAR',
                        selectedColor: const Color(0xFFEF4444).withAlpha(50),
                        labelStyle: TextStyle(
                          color: jenis == 'KELUAR' ? const Color(0xFFDC2626) : null,
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (val) {
                          if (val) jenisCtrl.value = 'KELUAR';
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Nominal (Rp):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: nominalCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixText: 'Rp ',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Keterangan / Keperluan:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: ketCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'Contoh: Pembelian konsumsi rapat',
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final nom = int.tryParse(nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              final ket = ketCtrl.text.trim();
              if (nom <= 0 || ket.isEmpty) return;

              Navigator.pop(ctx);
              final trx = KasOsisTransaksi(
                id: 'trx-${DateTime.now().millisecondsSinceEpoch}',
                tanggal: DateTime.now(),
                jenis: jenisCtrl.value,
                judul: ket,
                nominal: nom,
                keterangan: ket,
                kategori: kategoriCtrl.text.trim(),
                penanggungJawab: widget.username,
              );

              await DataService.addKasTransaksi(trx);
              await _loadData();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── Actions Anggota OSIS ───────────────────────────────────────────────────

  void _tambahAnggotaManual() {
    final namaCtrl = TextEditingController();
    final kelasCtrl = TextEditingController(text: 'XI RPL 1');
    final nisCtrl = TextEditingController();
    final jabatanCtrl = TextEditingController(text: 'Anggota OSIS');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: NusantaraColors.batikNavy),
            SizedBox(width: 10),
            Text('Tambah Anggota OSIS', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nama Lengkap Siswa:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: namaCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Nama lengkap siswa',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kelas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: kelasCtrl,
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NIS:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: nisCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Jabatan / Sekbid:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: jabatanCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Contoh: Sekbid Kewirausahaan / Anggota',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final nama = namaCtrl.text.trim();
              if (nama.isEmpty) return;

              Navigator.pop(ctx);
              final newAnggota = AnggotaOsis(
                id: 'ang-${DateTime.now().millisecondsSinceEpoch}',
                nama: nama,
                kelas: kelasCtrl.text.trim(),
                nis: nisCtrl.text.trim(),
                jabatan: jabatanCtrl.text.trim(),
              );

              await DataService.addAnggotaOsis(newAnggota);
              await _loadData();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── BUILD UTAMA SCREEN ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Opacity(
                    opacity: isDark ? 0.06 : 0.08,
                    child: CustomPaint(
                      painter: ModernMegaMendungPainter(color: NusantaraColors.gold, scale: 75),
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabCtrl,
                  isScrollable: true,
                  indicatorColor: NusantaraColors.gold,
                  indicatorWeight: 3,
                  labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
                  unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.check_box_outlined, size: 18),
                      text: 'Ceklis Kas Bendahara',
                    ),
                    Tab(
                      icon: Icon(Icons.how_to_reg_rounded, size: 18),
                      text: 'Absensi OSIS',
                    ),
                    Tab(
                      icon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                      text: 'Buku Kas & Saldo',
                    ),
                    Tab(
                      icon: Icon(Icons.groups_rounded, size: 18),
                      text: 'Anggota OSIS',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTabKasChecklist(theme, isDark, primary),
                _buildTabAbsensi(theme, isDark, primary),
                _buildTabBukuKas(theme, isDark, primary),
                _buildTabAnggota(theme, isDark, primary),
              ],
            ),
    );
  }

  // ── TAB 1: CEKLIS KAS BENDAHARA (DENGAN TOMBOL ABSENSI) ─────────────────────

  Widget _buildTabKasChecklist(ThemeData theme, bool isDark, Color primary) {
    if (_selectedKasSession == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Belum ada sesi kas aktif.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _tambahSesiKasBaru,
              icon: const Icon(Icons.add),
              label: const Text('Buat Sesi Kas Pertama'),
            ),
          ],
        ),
      );
    }

    final session = _selectedKasSession!;
    final items = session.items;

    final filteredItems = items.where((i) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return i.nama.toLowerCase().contains(q) ||
          i.kelas.toLowerCase().contains(q) ||
          i.jabatan.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Header Banner Tradisional Elegan Mega Mendung
        MegaMendungHeroBanner(
          title: session.judul,
          subtitle: '${_currencyFormat.format(session.nominalWajib)} / anggota • ${_dateFormat.format(session.tanggal)}',
          icon: Icons.account_balance_wallet_rounded,
          badgeText: 'Kas Pengurus OSIS',
          trailing: Wrap(
            spacing: 6,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.upload_file_rounded, size: 20, color: NusantaraColors.gold),
                tooltip: 'Impor dari Excel',
                onPressed: _pickAndImportExcel,
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.share_rounded, size: 20),
                tooltip: 'Bagikan Rekap ke WA',
                onPressed: _shareRekapKasWhatsApp,
              ),
              if (_canEdit)
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  tooltip: 'Buat Sesi Baru',
                  onPressed: _tambahSesiKasBaru,
                ),
            ],
          ),
        ),

        // Quick Switcher: Tombol Langsung Pasang Absensi OSIS
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _tabCtrl.animateTo(1); // Pindah ke Tab Absensi
                  },
                  icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                  label: const Text(
                    'Buka Presensi OSIS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusantaraColors.batikNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickAndImportExcel,
                icon: const Icon(Icons.table_view_rounded, size: 18, color: NusantaraColors.gold),
                label: const Text('Excel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Ringkasan Keuangan Sesi Kas
        MegaMendungCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Uang Terkumpul',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(session.totalTerkumpul),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Target Keseluruhan',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Text(
                        _currencyFormat.format(session.totalTarget),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (session.persentaseBayar / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${session.totalLunas} dari ${session.items.length} anggota sudah bayar',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${session.persentaseBayar.toStringAsFixed(0)}% Lunas',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Action Toolbar (Centang Semua, Batal Semua, Search)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari nama anggota OSIS...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
              ),
              if (_canEdit) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _centangSemuaKas(true),
                  icon: const Icon(Icons.done_all, size: 16, color: Color(0xFF10B981)),
                  label: const Text('Lunas Semua', style: TextStyle(fontSize: 11.5)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                TextButton(
                  onPressed: () => _centangSemuaKas(false),
                  child: const Text('Batal Semua', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                ),
              ],
            ],
          ),
        ),

        // Daftar Anggota dengan Ceklis Kas
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: filteredItems.length,
            itemBuilder: (ctx, idx) {
              final item = filteredItems[idx];
              return _buildKasMemberCard(item, isDark, primary);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKasMemberCard(KasOsisItem item, bool isDark, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.sudahBayar
              ? const Color(0xFF10B981).withAlpha(120)
              : (isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0)),
          width: item.sudahBayar ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleBayarItem(item),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: item.sudahBayar
                      ? const Color(0xFF10B981).withAlpha(35)
                      : Colors.grey.withAlpha(25),
                  child: Icon(
                    item.sudahBayar ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: item.sudahBayar ? const Color(0xFF10B981) : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.nama,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              item.kelas,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: NusantaraColors.gold.withAlpha(isDark ? 35 : 20),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: NusantaraColors.gold.withAlpha(120),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              item.jabatan,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? NusantaraColors.goldLight : NusantaraColors.goldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
                  decoration: BoxDecoration(
                    color: item.sudahBayar
                        ? const Color(0xFF10B981).withAlpha(isDark ? 40 : 25)
                        : Colors.red.withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.sudahBayar
                          ? const Color(0xFF10B981).withAlpha(140)
                          : Colors.red.withAlpha(120),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.sudahBayar ? Icons.check_rounded : Icons.pending_outlined,
                        size: 13,
                        color: item.sudahBayar ? const Color(0xFF10B981) : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.sudahBayar ? 'Lunas' : 'Belum Bayar',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: item.sudahBayar ? const Color(0xFF10B981) : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── TAB 2: ABSENSI OSIS (PER NAMA SISWA ANGGOTA OSIS) ──────────────────────

  Widget _buildTabAbsensi(ThemeData theme, bool isDark, Color primary) {
    if (_selectedAbsensiSession == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.how_to_reg_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Belum ada sesi presensi rapat OSIS.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _tambahSesiAbsensiBaru,
                  icon: const Icon(Icons.add),
                  label: const Text('Buat Sesi Manual'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickAndImportExcel,
                  icon: const Icon(Icons.table_view_rounded, color: NusantaraColors.gold),
                  label: const Text('Impor dari Excel'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final session = _selectedAbsensiSession!;
    final items = session.items;

    final filteredItems = items.where((i) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return i.nama.toLowerCase().contains(q) ||
          i.kelas.toLowerCase().contains(q) ||
          i.jabatan.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Header Banner Presensi Rapat Mega Mendung
        MegaMendungHeroBanner(
          title: session.namaKegiatan,
          subtitle: '${_dateFormat.format(session.tanggal)} • Lokasi: ${session.lokasi}',
          icon: Icons.how_to_reg_rounded,
          badgeText: 'Presensi Anggota OSIS',
          trailing: Wrap(
            spacing: 6,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.upload_file_rounded, size: 20, color: NusantaraColors.gold),
                tooltip: 'Impor dari Excel',
                onPressed: _pickAndImportExcel,
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.share_rounded, size: 20),
                tooltip: 'Bagikan Rekap ke WA',
                onPressed: _shareRekapAbsensiWhatsApp,
              ),
              if (_canEdit)
                IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  tooltip: 'Buat Sesi Absensi Baru',
                  onPressed: _tambahSesiAbsensiBaru,
                ),
            ],
          ),
        ),

        // Quick Controls Bar (Pindah ke Kas & Impor Excel)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _tabCtrl.animateTo(0); // Kembali ke Tab Kas
                  },
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                  label: const Text(
                    'Beralih ke Ceklis Kas OSIS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusantaraColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickAndImportExcel,
                icon: const Icon(Icons.file_upload_outlined, size: 18, color: NusantaraColors.batikNavy),
                label: const Text('Impor Excel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),

        // Sesi Dropdown & Ringkasan Chip Kehadiran
        MegaMendungCard(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: session.id,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
                  items: _absensiSessions.map((s) {
                    return DropdownMenuItem<String>(
                      value: s.id,
                      child: Text(
                        '${s.namaKegiatan} (${s.tanggal.day}/${s.tanggal.month}/${s.tanggal.year})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      setState(() {
                        _selectedAbsensiSession = _absensiSessions.firstWhere((s) => s.id == id);
                      });
                    }
                  },
                ),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAbsenMetric('Hadir', session.totalHadir, const Color(0xFF10B981)),
                  _buildAbsenMetric('Izin', session.totalIzin, const Color(0xFF3B82F6)),
                  _buildAbsenMetric('Sakit', session.totalSakit, const Color(0xFFF59E0B)),
                  _buildAbsenMetric('Alpa', session.totalAlpa, const Color(0xFFEF4444)),
                ],
              ),
              if (_canEdit) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: _semuaHadirAbsensi,
                      icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Semua Hadir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _simpanAbsensiSession(),
                      icon: const Icon(Icons.save_rounded, size: 16),
                      label: const Text('Simpan Presensi', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Pencarian Nama Siswa
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari nama siswa anggota OSIS...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
        ),

        // Daftar Siswa Anggota OSIS untuk Presensi
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: filteredItems.length,
            itemBuilder: (ctx, idx) {
              final item = filteredItems[idx];
              return _buildAbsenStudentCard(item, session, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbsenMetric(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(120), width: 1.5),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAbsenStudentCard(
    AbsensiOsisItem item,
    AbsensiOsisSession session,
    bool isDark,
  ) {
    const statuses = ['Hadir', 'Izin', 'Sakit', 'Alpa'];
    final colors = {
      'Hadir': const Color(0xFF059669),
      'Izin': const Color(0xFF0284C7),
      'Sakit': const Color(0xFFD97706),
      'Alpa': const Color(0xFFDC2626),
    };
    final statusIcons = {
      'Hadir': Icons.check_rounded,
      'Izin': Icons.article_outlined,
      'Sakit': Icons.healing_outlined,
      'Alpa': Icons.close_rounded,
    };

    final activeColor = colors[item.status] ?? Colors.grey;
    final activeIcon = statusIcons[item.status] ?? Icons.help_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activeColor.withAlpha(120),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: NusantaraColors.batikNavy.withAlpha(isDark ? 50 : 25),
                  child: Text(
                    item.nama.isNotEmpty ? item.nama[0] : 'S',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: NusantaraColors.batikNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NAMA SISWA UTAMA
                      Text(
                        item.nama,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              item.kelas,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: NusantaraColors.gold.withAlpha(isDark ? 35 : 20),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: NusantaraColors.gold.withAlpha(120),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              item.jabatan,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? NusantaraColors.goldLight : NusantaraColors.goldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status Badge Aktif
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeColor.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: activeColor.withAlpha(130), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(activeIcon, size: 13, color: activeColor),
                      const SizedBox(width: 4),
                      Text(
                        item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: activeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segmented Status Selector: H, I, S, A
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: statuses.map((st) {
                  final isSelected = item.status == st;
                  final col = colors[st]!;
                  final icon = statusIcons[st]!;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: InkWell(
                        onTap: !_canEdit
                            ? null
                            : () {
                                setState(() {
                                  item.status = st;
                                });
                                _simpanAbsensiSession(showToast: false);
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? col : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: col.withAlpha(80),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                size: 13,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white60 : const Color(0xFF475569)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                st,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 3: BUKU KAS & SALDO KESELURUHAN ─────────────────────────────────────

  Widget _buildTabBukuKas(ThemeData theme, bool isDark, Color primary) {
    int totalMasuk = 0;
    int totalKeluar = 0;

    for (final s in _kasSessions) {
      totalMasuk += s.totalTerkumpul;
    }
    for (final t in _transaksiList) {
      if (t.jenis == 'MASUK') {
        totalMasuk += t.nominal;
      } else {
        totalKeluar += t.nominal;
      }
    }
    final saldoSaatIni = totalMasuk - totalKeluar;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Saldo Kas Utama
          MegaMendungCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_rounded, size: 20, color: NusantaraColors.gold),
                    SizedBox(width: 8),
                    Text(
                      'SALDO KAS OSIS SAAT INI',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(saldoSaatIni),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: saldoSaatIni >= 0 ? const Color(0xFF10B981) : Colors.red,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Kas Masuk', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormat.format(totalMasuk),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Kas Keluar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormat.format(totalKeluar),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Catat Mutasi
          if (_isBendahara)
            ElevatedButton.icon(
              onPressed: _tambahTransaksiBaru,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Catat Pengeluaran / Pemasukan Kas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NusantaraColors.batikNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          const SizedBox(height: 18),

          // Riwayat Transaksi Manual
          const Text('Riwayat Mutasi Transaksi:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_transaksiList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Belum ada catatan mutasi kas.', style: TextStyle(color: Colors.grey))),
            )
          else
            ..._transaksiList.map((t) {
              final isMasuk = t.jenis == 'MASUK';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isMasuk
                        ? const Color(0xFF10B981).withAlpha(30)
                        : Colors.red.withAlpha(30),
                    child: Icon(
                      isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: isMasuk ? const Color(0xFF10B981) : Colors.red,
                      size: 18,
                    ),
                  ),
                  title: Text(t.keterangan, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text(
                    '${_dateFormat.format(t.tanggal)} • PJ: ${t.penanggungJawab}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  trailing: Text(
                    '${isMasuk ? '+' : '-'} ${_currencyFormat.format(t.nominal)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isMasuk ? const Color(0xFF10B981) : Colors.red,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── TAB 4: ANGGOTA OSIS (DENGAN NAMA SISWA RESMI & IMPORT EXCEL) ───────────

  Widget _buildTabAnggota(ThemeData theme, bool isDark, Color primary) {
    return Column(
      children: [
        MegaMendungHeroBanner(
          title: 'Daftar Anggota & Pengurus OSIS',
          subtitle: 'Total ${_anggotaList.length} siswa resmi terdaftar dalam kepengurusan OSIS',
          icon: Icons.groups_rounded,
          badgeText: 'SMK Bakti Nusantara 666',
          trailing: Wrap(
            spacing: 6,
            children: [
              IconButton.filledTonal(
                icon: const Icon(Icons.upload_file_rounded, size: 20, color: NusantaraColors.gold),
                tooltip: 'Impor dari Excel',
                onPressed: _pickAndImportExcel,
              ),
              if (_canEdit)
                IconButton.filledTonal(
                  icon: const Icon(Icons.person_add_rounded, size: 20),
                  tooltip: 'Tambah Anggota Manual',
                  onPressed: _tambahAnggotaManual,
                ),
            ],
          ),
        ),

        // Quick Import Excel Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ElevatedButton.icon(
            onPressed: _pickAndImportExcel,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text(
              'Impor Anggota dari File Excel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: NusantaraColors.gold,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Cari nama atau jabatan anggota OSIS...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ),
          ),
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: _anggotaList.where((a) {
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return a.nama.toLowerCase().contains(q) ||
                  a.kelas.toLowerCase().contains(q) ||
                  a.jabatan.toLowerCase().contains(q);
            }).length,
            itemBuilder: (ctx, idx) {
              final filtered = _anggotaList.where((a) {
                if (_searchQuery.isEmpty) return true;
                final q = _searchQuery.toLowerCase();
                return a.nama.toLowerCase().contains(q) ||
                    a.kelas.toLowerCase().contains(q) ||
                    a.jabatan.toLowerCase().contains(q);
              }).toList();

              final item = filtered[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: NusantaraColors.batikNavy.withAlpha(35),
                    child: Text(
                      item.nama.isNotEmpty ? item.nama[0] : 'O',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: NusantaraColors.batikNavy),
                    ),
                  ),
                  title: Text(item.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  subtitle: Text('${item.kelas} • ${item.jabatan}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                  trailing: _canEdit
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: 'Hapus Anggota',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Hapus Anggota OSIS?'),
                                content: Text('Hapus ${item.nama} dari daftar anggota OSIS?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text('Hapus'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await DataService.deleteAnggotaOsis(item.id);
                              await _loadData();
                            }
                          },
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
