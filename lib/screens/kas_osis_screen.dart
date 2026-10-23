import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
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

  bool get _canEdit =>
      !AuthService.isReadOnly(widget.username);

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

  void _tambahSesiKasBaru() {
    final judulCtrl = TextEditingController(
        text: 'Uang Kas OSIS - Minggu ke-${(_kasSessions.length + 1)}');
    final nominalCtrl = TextEditingController(text: '5000');
    final ketCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now();

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Buat Sesi Uang Kas Baru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Bendahara dapat menentukan nominal dan mencentang anggota yang membayar.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: judulCtrl,
                decoration: const InputDecoration(
                  labelText: 'Judul Sesi Kas *',
                  prefixIcon: Icon(Icons.bookmark_border_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nominalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal Wajib per Anggota (Rp) *',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ketCtrl,
                decoration: const InputDecoration(
                  labelText: 'Keterangan Tambahan (Opsional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  if (judulCtrl.text.trim().isEmpty) return;
                  final nominal = int.tryParse(nominalCtrl.text.trim()) ?? 5000;
                  final anggota = await DataService.getAnggotaOsis();

                  final newSession = KasOsisSession(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    tanggal: pickedDate,
                    judul: judulCtrl.text.trim(),
                    nominalWajib: nominal,
                    keterangan: ketCtrl.text.trim(),
                    petugas: widget.username,
                    items: anggota
                        .map((a) => KasOsisItem(
                              anggotaId: a.id,
                              nama: a.nama,
                              jabatan: a.jabatan,
                              kelas: a.kelas,
                              sudahBayar: false,
                              nominalBayar: nominal,
                            ))
                        .toList(),
                  );

                  await DataService.saveKasOsisSession(newSession);
                  await NotificationService.notifyUpdate(
                    title: 'Sesi Kas OSIS Baru',
                    message: 'Sesi kas "${newSession.judul}" dibuka oleh Bendahara (${widget.username})',
                    category: 'system',
                    actor: widget.username,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                },
                icon: const Icon(Icons.add_task_rounded, size: 20),
                label: const Text('Buat Sesi Kas'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: NusantaraColors.gold,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareRekapKas() {
    if (_selectedKasSession == null) return;
    final s = _selectedKasSession!;
    final sb = StringBuffer();
    sb.writeln('📋 REKAP UANG KAS OSIS - BAKTI NUSANTARA 666');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('Judul: ${s.judul}');
    sb.writeln('Tanggal: ${_dateFormat.format(s.tanggal)}');
    sb.writeln('Nominal per Anggota: ${_currencyFormat.format(s.nominalWajib)}');
    sb.writeln('Total Terkumpul: ${_currencyFormat.format(s.totalTerkumpul)}');
    sb.writeln('Sudah Bayar: ${s.jumlahSudahBayar} orang');
    sb.writeln('Belum Bayar: ${s.jumlahBelumBayar} orang');
    sb.writeln('Petugas: ${s.petugas}');
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('DAFTAR PEMBAYARAN:');
    for (int i = 0; i < s.items.length; i++) {
      final item = s.items[i];
      final status = item.sudahBayar ? '✅ Lunas' : '❌ Belum';
      sb.writeln('${i + 1}. ${item.nama} (${item.jabatan}) - $status');
    }
    sb.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    sb.writeln('Dicatat via OSIS Management System');

    Share.share(sb.toString(), subject: 'Rekap Kas OSIS - ${s.judul}');
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
                    'Absensi "${_selectedAbsensiSession!.namaKegiatan}" berhasil disimpan.',
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
          SnackBar(content: Text('Gagal menyimpan absensi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _tambahSesiAbsensiBaru() {
    final namaCtrl = TextEditingController(text: 'Rapat Pleno & Evaluasi Mingguan');
    final lokasiCtrl = TextEditingController(text: 'Ruang Sekretariat OSIS');
    final ketCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now();

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pasang Absensi Kegiatan OSIS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Catat presensi pengurus OSIS untuk rapat, apel, atau kegiatan lainnya.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: namaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Kegiatan / Rapat *',
                  prefixIcon: Icon(Icons.event_note_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lokasiCtrl,
                decoration: const InputDecoration(
                  labelText: 'Lokasi Pelaksanaan',
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ketCtrl,
                decoration: const InputDecoration(
                  labelText: 'Keterangan Agenda',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  if (namaCtrl.text.trim().isEmpty) return;
                  final anggota = await DataService.getAnggotaOsis();

                  final newSession = AbsensiOsisSession(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    tanggal: pickedDate,
                    namaKegiatan: namaCtrl.text.trim(),
                    lokasi: lokasiCtrl.text.trim(),
                    keterangan: ketCtrl.text.trim(),
                    petugas: widget.username,
                    items: anggota
                        .map((a) => AbsensiOsisItem(
                              anggotaId: a.id,
                              nama: a.nama,
                              jabatan: a.jabatan,
                              kelas: a.kelas,
                              status: 'Hadir',
                            ))
                        .toList(),
                  );

                  await DataService.saveAbsensiOsisSession(newSession);
                  await NotificationService.notifyUpdate(
                    title: 'Presensi OSIS Dibuka',
                    message: 'Presensi kegiatan "${newSession.namaKegiatan}" dibuka oleh ${widget.username}',
                    category: 'system',
                    actor: widget.username,
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                },
                icon: const Icon(Icons.how_to_reg_rounded, size: 20),
                label: const Text('Buat Sesi Absensi'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions Buku Kas Transaksi ─────────────────────────────────────────────

  void _tambahTransaksiKas() {
    final judulCtrl = TextEditingController();
    final nominalCtrl = TextEditingController();
    final pjCtrl = TextEditingController(text: widget.username);
    final ketCtrl = TextEditingController();
    String jenis = 'keluar'; // 'masuk' atau 'keluar'
    String kategori = 'Konsumsi Rapat';

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Catat Transaksi Kas Umum',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pengeluaran (-)')),
                      selected: jenis == 'keluar',
                      selectedColor: Colors.red.withAlpha(isDark ? 50 : 35),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: jenis == 'keluar' ? Colors.redAccent : Colors.grey,
                      ),
                      onSelected: (v) => setM(() => jenis = 'keluar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Pemasukan (+)')),
                      selected: jenis == 'masuk',
                      selectedColor: Colors.green.withAlpha(isDark ? 50 : 35),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: jenis == 'masuk' ? Colors.green : Colors.grey,
                      ),
                      onSelected: (v) => setM(() => jenis = 'masuk'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: judulCtrl,
                decoration: InputDecoration(
                  labelText: jenis == 'keluar' ? 'Keperluan Pengeluaran *' : 'Sumber Pemasukan *',
                  hintText: jenis == 'keluar' ? 'Contoh: Beli konsumsi rapat pleno' : 'Contoh: Iuran kegiatan LDKS',
                  prefixIcon: Icon(jenis == 'keluar' ? Icons.receipt_long_outlined : Icons.input_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nominalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp) *',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kategori,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Konsumsi Rapat', child: Text('Konsumsi Rapat')),
                  DropdownMenuItem(value: 'ATK & Fotokopi', child: Text('ATK & Fotokopi')),
                  DropdownMenuItem(value: 'Banner & Publikasi', child: Text('Banner & Publikasi')),
                  DropdownMenuItem(value: 'Transportasi & Logistik', child: Text('Transportasi & Logistik')),
                  DropdownMenuItem(value: 'Dana Proker Sekbid', child: Text('Dana Proker Sekbid')),
                  DropdownMenuItem(value: 'Sumbangan & Donasi', child: Text('Sumbangan & Donasi')),
                  DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                ],
                onChanged: (v) => setM(() => kategori = v ?? 'Lainnya'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pjCtrl,
                decoration: const InputDecoration(
                  labelText: 'Penanggung Jawab',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ketCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan / Nomor Nota',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (judulCtrl.text.trim().isEmpty) return;
                  final nominal = int.tryParse(nominalCtrl.text.trim()) ?? 0;
                  if (nominal <= 0) return;

                  final t = KasOsisTransaksi(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    tanggal: DateTime.now(),
                    jenis: jenis,
                    judul: judulCtrl.text.trim(),
                    nominal: nominal,
                    kategori: kategori,
                    penanggungJawab: pjCtrl.text.trim(),
                    keterangan: ketCtrl.text.trim(),
                  );

                  await DataService.addKasTransaksi(t);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: jenis == 'keluar' ? Colors.red.shade700 : Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('Simpan ${jenis == 'keluar' ? 'Pengeluaran' : 'Pemasukan'}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions Anggota OSIS ───────────────────────────────────────────────────

  void _showAnggotaForm([AnggotaOsis? existing]) {
    final namaCtrl = TextEditingController(text: existing?.nama);
    final jabatanCtrl = TextEditingController(text: existing?.jabatan ?? 'Anggota');
    final kelasCtrl = TextEditingController(text: existing?.kelas);
    final nisCtrl = TextEditingController(text: existing?.nis);
    final hpCtrl = TextEditingController(text: existing?.noHp);

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
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              existing == null ? 'Tambah Anggota OSIS' : 'Edit Anggota OSIS',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: namaCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap *',
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: jabatanCtrl,
              decoration: const InputDecoration(
                labelText: 'Jabatan di OSIS *',
                hintText: 'Contoh: Bendahara 2, Anggota Sekbid 1, dll',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: kelasCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kelas',
                      prefixIcon: Icon(Icons.class_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: nisCtrl,
                    decoration: const InputDecoration(
                      labelText: 'NIS',
                      prefixIcon: Icon(Icons.pin_rounded),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: hpCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor WhatsApp / HP',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (namaCtrl.text.trim().isEmpty) return;
                if (existing != null) {
                  existing.nama = namaCtrl.text.trim();
                  existing.jabatan = jabatanCtrl.text.trim();
                  existing.kelas = kelasCtrl.text.trim();
                  existing.nis = nisCtrl.text.trim();
                  existing.noHp = hpCtrl.text.trim();
                  await DataService.updateAnggotaOsis(existing);
                } else {
                  final a = AnggotaOsis(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    nama: namaCtrl.text.trim(),
                    jabatan: jabatanCtrl.text.trim(),
                    kelas: kelasCtrl.text.trim(),
                    nis: nisCtrl.text.trim(),
                    noHp: hpCtrl.text.trim(),
                  );
                  await DataService.addAnggotaOsis(a);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Simpan Data Anggota'),
            ),
          ],
        ),
      ),
    );
  }

  // ── BUILD UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kas & Absensi OSIS'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () => _loadData(),
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Bagikan Rekap',
            onPressed: _shareRekapKas,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: NusantaraColors.gold,
          indicatorWeight: 3,
          labelColor: isDark ? NusantaraColors.goldLight : Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.fact_check_rounded, size: 18),
              text: 'Ceklis Kas OSIS',
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
              icon: Icon(Icons.people_alt_rounded, size: 18),
              text: 'Anggota OSIS',
            ),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primary))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTabCeklisKas(theme, isDark, primary),
                _buildTabAbsensi(theme, isDark, primary),
                _buildTabBukuKas(theme, isDark, primary),
                _buildTabAnggotaOsis(theme, isDark, primary),
              ],
            ),
    );
  }

  // ── TAB 1: CEKLIS KAS OSIS (BENDAHARA) ──────────────────────────────────────

  Widget _buildTabCeklisKas(ThemeData theme, bool isDark, Color primary) {
    if (_selectedKasSession == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wallet_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Belum ada sesi uang kas OSIS'),
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
    final totalWajib = session.nominalWajib * items.length;
    final progress = items.isNotEmpty ? (session.jumlahSudahBayar / items.length) : 0.0;

    final filteredItems = items.where((i) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return i.nama.toLowerCase().contains(q) ||
          i.jabatan.toLowerCase().contains(q) ||
          i.kelas.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // Nusantara Header Banner
        NusantaraHeaderBanner(
          title: session.judul,
          subtitle: '${_dateFormat.format(session.tanggal)} • Petugas: ${session.petugas}',
          icon: Icons.account_balance_wallet_rounded,
          badgeText: 'Perbendaharaan OSIS',
          trailing: _isBendahara
              ? IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  tooltip: 'Buat Sesi Kas Baru',
                  onPressed: _tambahSesiKasBaru,
                )
              : null,
        ),

        // Sesi Selector & Quick Actions Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dropdown Sesi Kas
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: session.id,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_circle_outlined, size: 20),
                        items: _kasSessions.map((s) {
                          return DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(
                              '${s.judul} (${_currencyFormat.format(s.nominalWajib)})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            setState(() {
                              _selectedKasSession = _kasSessions.firstWhere((s) => s.id == id);
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Statistik Ringkasan Kas
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Terkumpul',
                      value: _currencyFormat.format(session.totalTerkumpul),
                      color: NusantaraColors.gold,
                      subtext: 'dari ${_currencyFormat.format(totalWajib)}',
                      isDark: isDark,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey.withAlpha(50)),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Lunas',
                      value: '${session.jumlahSudahBayar}/${items.length}',
                      color: const Color(0xFF10B981),
                      subtext: '${session.jumlahBelumBayar} belum bayar',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(NusantaraColors.gold),
                ),
              ),
              const SizedBox(height: 14),

              // ACTION BUTTONS (Centang Semua, Batal, & PASANG ABSENSI OSIS)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  if (_canEdit) ...[
                    OutlinedButton.icon(
                      onPressed: () => _centangSemuaKas(true),
                      icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Centang Semua (Lunas)', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        side: const BorderSide(color: Color(0xFF10B981), width: 1),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _centangSemuaKas(false),
                      icon: const Icon(Icons.clear_all_rounded, size: 16, color: Colors.grey),
                      label: const Text('Batal Semua', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],

                  // TOMBOL FITUR UNGGULAN: "Pasang Absensi OSIS"
                  ElevatedButton.icon(
                    onPressed: () {
                      _tabCtrl.animateTo(1); // Pindah ke tab Absensi OSIS
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Beralih ke mode Absensi Anggota OSIS'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                    label: const Text('Pasang Absensi OSIS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Search Bar Anggota
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Cari nama atau jabatan pengurus...',
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
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),

        // List Ceklis Anggota
        Expanded(
          child: filteredItems.isEmpty
              ? const Center(child: Text('Tidak ada anggota yang cocok dengan pencarian'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: filteredItems.length,
                  itemBuilder: (ctx, i) {
                    final item = filteredItems[i];
                    return _buildKasAnggotaCard(item, session, isDark, primary);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildKasAnggotaCard(
    KasOsisItem item,
    KasOsisSession session,
    bool isDark,
    Color primary,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141D2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.sudahBayar
              ? (isDark ? const Color(0xFF065F46) : const Color(0xFFA7F3D0))
              : (isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
          width: item.sudahBayar ? 1.4 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark
                  ? (item.sudahBayar ? const Color(0xFF064E3B) : const Color(0xFF1E293B))
                  : (item.sudahBayar ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9)),
              child: Text(
                item.nama.isNotEmpty ? item.nama[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: item.sudahBayar ? const Color(0xFF059669) : Colors.grey,
                ),
              ),
            ),
            if (item.sudahBayar)
              const CircleAvatar(
                radius: 7,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 6,
                  backgroundColor: Color(0xFF10B981),
                  child: Icon(Icons.check, size: 9, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          item.nama,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            decoration: item.sudahBayar ? null : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Row(
              children: [
                NusantaraBadge(
                  label: item.jabatan,
                  color: NusantaraColors.gold,
                ),
                if (item.kelas.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    item.kelas,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
            if (item.sudahBayar && item.tanggalBayar != null) ...[
              const SizedBox(height: 2),
              Text(
                'Lunas • ${_currencyFormat.format(item.nominalBayar > 0 ? item.nominalBayar : session.nominalWajib)}',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        trailing: _canEdit
            ? Transform.scale(
                scale: 1.15,
                child: Checkbox(
                  value: item.sudahBayar,
                  activeColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  onChanged: (val) {
                    setState(() {
                      item.sudahBayar = val ?? false;
                      if (item.sudahBayar) {
                        item.nominalBayar = session.nominalWajib;
                        item.tanggalBayar = DateTime.now();
                      } else {
                        item.nominalBayar = 0;
                        item.tanggalBayar = null;
                      }
                    });
                    _simpanKasSession(showToast: false);
                  },
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: item.sudahBayar ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.sudahBayar ? 'LUNAS' : 'BELUM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: item.sudahBayar ? Colors.green : Colors.red,
                  ),
                ),
              ),
      ),
    );
  }

  // ── TAB 2: ABSENSI OSIS (PRESENSI KEGIATAN) ────────────────────────────────

  Widget _buildTabAbsensi(ThemeData theme, bool isDark, Color primary) {
    if (_selectedAbsensiSession == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.how_to_reg_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Belum ada sesi absensi kegiatan OSIS'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _tambahSesiAbsensiBaru,
              icon: const Icon(Icons.add),
              label: const Text('Buat Sesi Absensi Pertama'),
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
          i.jabatan.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        NusantaraHeaderBanner(
          title: session.namaKegiatan,
          subtitle: '${_dateFormat.format(session.tanggal)} • Lokasi: ${session.lokasi}',
          icon: Icons.how_to_reg_rounded,
          badgeText: 'Presensi Rapat OSIS',
          trailing: _canEdit
              ? IconButton.filledTonal(
                  icon: const Icon(Icons.add_rounded, size: 20),
                  tooltip: 'Buat Sesi Absensi Baru',
                  onPressed: _tambahSesiAbsensiBaru,
                )
              : null,
        ),

        // Sesi Selector & Kehadiran Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector Sesi
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

              // Baris Ringkasan H, I, S, A
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildAbsenChip(label: 'Hadir', count: session.totalHadir, color: const Color(0xFF10B981)),
                  _buildAbsenChip(label: 'Izin', count: session.totalIzin, color: const Color(0xFF3B82F6)),
                  _buildAbsenChip(label: 'Sakit', count: session.totalSakit, color: const Color(0xFFF59E0B)),
                  _buildAbsenChip(label: 'Alpa', count: session.totalAlpa, color: const Color(0xFFEF4444)),
                ],
              ),
              const SizedBox(height: 14),

              // Action Buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  if (_canEdit)
                    OutlinedButton.icon(
                      onPressed: _semuaHadirAbsensi,
                      icon: const Icon(Icons.done_all_rounded, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Semua Hadir', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _tabCtrl.animateTo(0); // Kembali ke Tab Kas
                    },
                    icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
                    label: const Text('Beralih ke Kas OSIS', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: NusantaraColors.gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List Anggota dengan Pilihan H/I/S/A
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
            itemCount: filteredItems.length,
            itemBuilder: (ctx, i) {
              final item = filteredItems[i];
              return _buildAbsenAnggotaCard(item, session, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAbsenChip({required String label, required int count, required Color color}) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(120), width: 1.5),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAbsenAnggotaCard(
    AbsensiOsisItem item,
    AbsensiOsisSession session,
    bool isDark,
  ) {
    const statuses = ['Hadir', 'Izin', 'Sakit', 'Alpa'];
    final colors = {
      'Hadir': const Color(0xFF10B981),
      'Izin': const Color(0xFF3B82F6),
      'Sakit': const Color(0xFFF59E0B),
      'Alpa': const Color(0xFFEF4444),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141D2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: (colors[item.status] ?? Colors.grey).withAlpha(40),
                child: Text(
                  item.status[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colors[item.status] ?? Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${item.jabatan} • ${item.kelas}',
                        style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white60 : Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Pilihan Status H, I, S, A
          Row(
            children: statuses.map((st) {
              final isSel = item.status == st;
              final col = colors[st] ?? Colors.grey;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: _canEdit
                        ? () {
                            setState(() => item.status = st);
                            _simpanAbsensiSession(showToast: false);
                          }
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSel ? col : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSel ? col : Colors.grey.withAlpha(60),
                          width: isSel ? 1.5 : 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          st,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── TAB 3: BUKU KAS UMUM & SALDO ───────────────────────────────────────────

  Widget _buildTabBukuKas(ThemeData theme, bool isDark, Color primary) {
    int totalKasSesiMasuk = _kasSessions.fold(0, (sum, s) => sum + s.totalTerkumpul);
    int totalTrxMasuk = _transaksiList
        .where((t) => t.jenis == 'masuk')
        .fold(0, (sum, t) => sum + t.nominal);
    int totalTrxKeluar = _transaksiList
        .where((t) => t.jenis == 'keluar')
        .fold(0, (sum, t) => sum + t.nominal);

    int totalSemuaMasuk = totalKasSesiMasuk + totalTrxMasuk;
    int saldoBersih = totalSemuaMasuk - totalTrxKeluar;

    return Column(
      children: [
        NusantaraHeaderBanner(
          title: 'Buku Kas & Keuangan OSIS',
          subtitle: 'Laporan arus kas, saldo kas harian, dan mutasi keuangan',
          icon: Icons.account_balance_rounded,
          badgeText: 'Perbendaharaan OSIS',
          trailing: _isBendahara
              ? ElevatedButton.icon(
                  onPressed: _tambahTransaksiKas,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Catat', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NusantaraColors.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                )
              : null,
        ),

        // Card Saldo Nusantara
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [NusantaraColors.batikNavy, const Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 60 : 30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SALDO KAS OSIS SAAT INI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('SMK Baknus 666',
                        style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _currencyFormat.format(saldoBersih),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const Divider(color: Colors.white24, height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Kas Masuk (+)',
                            style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
                        const SizedBox(height: 2),
                        Text(_currencyFormat.format(totalSemuaMasuk),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Pengeluaran (-)',
                            style: TextStyle(fontSize: 11, color: Colors.orangeAccent)),
                        const SizedBox(height: 2),
                        Text(_currencyFormat.format(totalTrxKeluar),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Riwayat Mutasi Transaksi Kas',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // List Transaksi Mutasi
        Expanded(
          child: _transaksiList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 10),
                      const Text('Belum ada transaksi operasional kas dicatat'),
                      if (_isBendahara) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _tambahTransaksiKas,
                          icon: const Icon(Icons.add),
                          label: const Text('Catat Pengeluaran / Pemasukan'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: _transaksiList.length,
                  itemBuilder: (ctx, i) {
                    final t = _transaksiList[i];
                    final isKeluar = t.jenis == 'keluar';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141D2E) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isKeluar
                              ? Colors.red.withAlpha(isDark ? 40 : 25)
                              : Colors.green.withAlpha(isDark ? 40 : 25),
                          child: Icon(
                            isKeluar ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            color: isKeluar ? Colors.redAccent : Colors.green,
                          ),
                        ),
                        title: Text(t.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        subtitle: Text(
                          '${t.kategori} • ${DateFormat('d MMM yyyy, HH:mm').format(t.tanggal)}${t.penanggungJawab.isNotEmpty ? ' • Oleh: ${t.penanggungJawab}' : ''}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isKeluar ? '-' : '+'} ${_currencyFormat.format(t.nominal)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isKeluar ? Colors.redAccent : Colors.green,
                              ),
                            ),
                            if (_isBendahara)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                onPressed: () async {
                                  await DataService.deleteKasTransaksi(t.id);
                                  _loadData();
                                },
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

  // ── TAB 4: KELOLA ANGGOTA OSIS ─────────────────────────────────────────────

  Widget _buildTabAnggotaOsis(ThemeData theme, bool isDark, Color primary) {
    return Column(
      children: [
        NusantaraHeaderBanner(
          title: 'Daftar Pengurus & Anggota OSIS',
          subtitle: '${_anggotaList.length} pengurus terdaftar untuk kas & absensi',
          icon: Icons.groups_rounded,
          badgeText: 'Struktur Organisasi',
          trailing: _isBendahara
              ? ElevatedButton.icon(
                  onPressed: () => _showAnggotaForm(),
                  icon: const Icon(Icons.person_add_rounded, size: 16),
                  label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                )
              : null,
        ),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            itemCount: _anggotaList.length,
            itemBuilder: (ctx, i) {
              final a = _anggotaList[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141D2E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    child: Text(
                      a.nama.isNotEmpty ? a.nama[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.bold, color: primary),
                    ),
                  ),
                  title: Text(a.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${a.jabatan}${a.kelas.isNotEmpty ? ' • ${a.kelas}' : ''}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                  trailing: _isBendahara
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () => _showAnggotaForm(a),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              onPressed: () async {
                                await DataService.deleteAnggotaOsis(a.id);
                                _loadData();
                              },
                            ),
                          ],
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

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required String subtext,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 1),
        Text(subtext, style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.black45)),
      ],
    );
  }
}
