import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';

class EvaluasiScreen extends StatefulWidget {
  final String username;
  final int initialSubTab;

  const EvaluasiScreen({
    super.key,
    required this.username,
    this.initialSubTab = 0,
  });

  @override
  State<EvaluasiScreen> createState() => _EvaluasiScreenState();
}

class _EvaluasiScreenState extends State<EvaluasiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<EvaluasiProker> _evaluasiList = [];
  List<Proker> _prokerList = [];
  List<AnggotaOsis> _anggotaList = [];
  List<AktivitasPengguna> _aktivitasList = [];

  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  bool get _canNilai => AuthService.canNilaiKinerja(widget.username);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialSubTab.clamp(0, 2),
    );
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });

    _loadData();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'evaluasi_proker' || table == 'proker' || table == 'aktivitas_pengguna' || table == 'all') {
        if (mounted) _loadData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _dataSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final evl = await DataService.getEvaluasi();
      final prk = await DataService.getProker();
      final ang = await DataService.getAnggotaOsis();
      final akt = await DataService.getAktivitas();

      if (!mounted) return;
      setState(() {
        _evaluasiList = evl;
        _prokerList = prk;
        _anggotaList = ang;
        _aktivitasList = akt;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: primary,
            indicatorWeight: 3,
            labelColor: primary,
            unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.rate_review_rounded, size: 18), text: '10. Evaluasi Proker'),
              Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Penilaian & Rekap Tahunan'),
              Tab(icon: Icon(Icons.history_edu_rounded, size: 18), text: 'Riwayat Aktivitas'),
            ],
          ),
        ),
      ),
      body: _loading && _evaluasiList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildEvaluasiProkerTab(theme, isDark, primary),
                _buildPenilaianRekapTab(theme, isDark, primary),
                _buildAktivitasAuditTab(theme, isDark, primary),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: EVALUASI PROGRAM KERJA
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEvaluasiProkerTab(ThemeData theme, bool isDark, Color primary) {
    return Column(
      children: [
        // Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total ${_evaluasiList.length} Evaluasi Proker',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              if (_canNilai)
                ElevatedButton.icon(
                  icon: const Icon(Icons.post_add_rounded, size: 18),
                  label: const Text('Buat Evaluasi'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showEvaluasiDialog(),
                ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: _evaluasiList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Belum ada evaluasi program kerja yang dicatat.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _evaluasiList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final e = _evaluasiList[i];
                    return _buildEvaluasiCard(e, isDark, primary);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEvaluasiCard(EvaluasiProker e, bool isDark, Color primary) {
    Color scoreColor = Colors.green;
    if (e.nilaiKinerja < 75) scoreColor = Colors.orange;
    if (e.nilaiKinerja < 60) scoreColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 5),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.namaProker,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bidang: ${e.sekbid} • Tanggal: ${DateFormat('d MMMM yyyy').format(e.tanggalEvaluasi)}',
                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withAlpha(isDark ? 40 : 25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scoreColor.withAlpha(120), width: 1),
                ),
                child: Column(
                  children: [
                    Text(
                      '${e.nilaiKinerja}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: scoreColor),
                    ),
                    Text(
                      'Skor Kinerja',
                      style: TextStyle(fontSize: 8.5, color: scoreColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Hasil Capaian
          _buildEvalSection('HASIL & CAPAIAN PROGRAM:', e.hasilCapaian, Colors.green, isDark),
          const SizedBox(height: 8),

          // Kendala Pelaksanaan
          _buildEvalSection('KENDALA & HAMBATAN:', e.kendala, Colors.redAccent, isDark),
          const SizedBox(height: 8),

          // Saran & Masukan
          _buildEvalSection('SARAN & SOLUSI PEMBINA:', e.saranMasukan, Colors.blueAccent, isDark),

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Penilai: ${e.penilai}',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
              if (_canNilai)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteEvaluasi(e),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvalSection(String title, String content, Color labelColor, bool isDark) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: labelColor),
        ),
        const SizedBox(height: 2),
        Text(
          content,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155), height: 1.3),
        ),
      ],
    );
  }

  void _showEvaluasiDialog({EvaluasiProker? existing}) {
    final prokerNamaCtrl = TextEditingController(text: existing?.namaProker ?? '');
    final sekbidCtrl = TextEditingController(text: existing?.sekbid ?? 'SEKBID1');
    final capaianCtrl = TextEditingController(text: existing?.hasilCapaian ?? '');
    final kendalaCtrl = TextEditingController(text: existing?.kendala ?? '');
    final saranCtrl = TextEditingController(text: existing?.saranMasukan ?? '');
    final nilaiCtrl = TextEditingController(text: '${existing?.nilaiKinerja ?? 85}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Catat Evaluasi Program Kerja' : 'Edit Evaluasi', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: prokerNamaCtrl, decoration: const InputDecoration(labelText: 'Nama Program Kerja *')),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: sekbidCtrl, decoration: const InputDecoration(labelText: 'Bidang / Sekbid Pelaksana'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: nilaiCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nilai Kinerja (1-100)'))),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: capaianCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Hasil Capaian Kegiatan')),
                const SizedBox(height: 8),
                TextField(controller: kendalaCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Kendala yang Dihadapi')),
                const SizedBox(height: 8),
                TextField(controller: saranCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Saran dan Rekomendasi Perbaikan')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final nama = prokerNamaCtrl.text.trim();
              if (nama.isEmpty) return;

              final currentName = await AuthService.getCurrentDisplayName();

              final item = EvaluasiProker(
                id: existing?.id ?? 'evl-${DateTime.now().millisecondsSinceEpoch}',
                prokerId: existing?.prokerId ?? '',
                namaProker: nama,
                sekbid: sekbidCtrl.text.trim(),
                hasilCapaian: capaianCtrl.text.trim(),
                kendala: kendalaCtrl.text.trim(),
                saranMasukan: saranCtrl.text.trim(),
                nilaiKinerja: int.tryParse(nilaiCtrl.text.trim()) ?? 85,
                penilai: currentName.isNotEmpty ? currentName : 'Pembina OSIS',
                tanggalEvaluasi: DateTime.now(),
              );

              await DataService.saveEvaluasi(item);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan Evaluasi'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteEvaluasi(EvaluasiProker e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Evaluasi?'),
        content: Text('Yakin ingin menghapus evaluasi untuk "${e.namaProker}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await DataService.deleteEvaluasi(e.id);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: PENILAIAN KINERJA & REKAP TAHUNAN
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPenilaianRekapTab(ThemeData theme, bool isDark, Color primary) {
    final prokerSelesai = _prokerList.where((p) => p.status.toLowerCase().contains('selesai')).length;
    final totalProker = _prokerList.length;
    final double pct = totalProker > 0 ? (prokerSelesai / totalProker) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Annual Summary Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                    : [primary, primary.withAlpha(210)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REKAPITULASI PROGRAM KERJA TAHUNAN',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tingkat Keberhasilan Proker: ${(pct * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 12,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(Colors.amberAccent),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Proker: $totalProker Program', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text('Terlaksana Selesai: $prokerSelesai', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Penilaian Kinerja Sekbid Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Evaluasi Kinerja Setiap Sekbid',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...DataService.defaultSekbidItems().map((s) {
                  final relatedProkers = _prokerList.where((p) => p.sekbid.toUpperCase() == s.id.toUpperCase()).toList();
                  final selesai = relatedProkers.where((p) => p.status.toLowerCase().contains('selesai')).length;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent)),
                              const SizedBox(height: 2),
                              Text(s.deskripsi, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF334155))),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$selesai / ${relatedProkers.length} Selesai',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: RIWAYAT AKTIVITAS PENGGUNA (AUDIT LOG)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAktivitasAuditTab(ThemeData theme, bool isDark, Color primary) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total ${_aktivitasList.length} Catatan Aktivitas Terakhir',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh Log',
                onPressed: () => _loadData(silent: true),
              ),
            ],
          ),
        ),
        Expanded(
          child: _aktivitasList.isEmpty
              ? const Center(child: Text('Belum ada riwayat aktivitas pengguna.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _aktivitasList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final akt = _aktivitasList[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primary.withAlpha(isDark ? 40 : 25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.history_toggle_off_rounded, size: 18, color: primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      akt.displayName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      DateFormat('dd/MM HH:mm').format(akt.waktu),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${akt.aksi} pada modul ${akt.modul}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                                ),
                                if (akt.detail.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    akt.detail,
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
