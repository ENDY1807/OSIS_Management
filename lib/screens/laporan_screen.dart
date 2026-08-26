import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/pdf_service.dart';
import '../services/notification_service.dart';
import '../app_theme.dart';

const _uuid = Uuid();

class LaporanScreen extends StatefulWidget {
  final String username;
  const LaporanScreen({super.key, this.username = ''});
  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  List<LaporanKegiatan> _laporan = [];
  String _filterStatus = 'Semua';
  StreamSubscription<String>? _dataSub;

  @override
  void initState() {
    super.initState();
    _load();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'laporan_kegiatan' || table == 'laporan' || table == 'all') {
        if (mounted) _load(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  bool _loading = false;

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && _laporan.isEmpty) setState(() => _loading = true);
    final l = await DataService.getLaporan();
    if (!mounted) return;
    setState(() {
      _laporan = l..sort((a, b) => b.tanggalKegiatan.compareTo(a.tanggalKegiatan));
      _loading = false;
    });
  }

  List<LaporanKegiatan> get _filtered => _filterStatus == 'Semua'
      ? _laporan
      : _laporan.where((l) => l.status == _filterStatus).toList();

  bool _isOwner(LaporanKegiatan l) =>
      l.pembuatId == widget.username ||
      widget.username == 'ADMIN' ||
      widget.username == 'PEMBINA' ||
      widget.username == 'KESISWAAN' ||
      AuthService.getRole(widget.username) == 'ADMIN' ||
      AuthService.getRole(widget.username) == 'PEMBINA' ||
      AuthService.getRole(widget.username) == 'KESISWAAN';

  void _showForm({LaporanKegiatan? existing}) async {
    final judulC = TextEditingController(text: existing?.judul ?? '');
    final lokasiC = TextEditingController(text: existing?.lokasi ?? '');
    final ketuplakC = TextEditingController(text: existing?.penanggungJawab ?? '');
    final deskC = TextEditingController(text: existing?.deskripsi ?? '');
    final hasilC = TextEditingController(text: existing?.hasilCapaian ?? '');
    final kendalaC = TextEditingController(text: existing?.kendalaSaran ?? '');
    final pesertaC = TextEditingController(text: existing?.peserta.join(', ') ?? '');
    String status = existing?.status ?? StatusLaporan.draft;
    DateTime tanggal = existing?.tanggalKegiatan ?? DateTime.now();
    final sekbid = widget.username;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                    decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(existing == null ? 'Buat Laporan Kegiatan' : 'Edit Laporan',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                const SizedBox(height: 16),
                TextField(controller: judulC,
                    decoration: const InputDecoration(labelText: 'Nama Kegiatan *',
                        prefixIcon: Icon(Icons.event_outlined, color: kAccent))),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: tanggal,
                      firstDate: DateTime(2020), lastDate: DateTime(2100),
                    );
                    if (picked != null) setModal(() => tanggal = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Tanggal Kegiatan',
                        prefixIcon: Icon(Icons.calendar_month_outlined, color: kAccent)),
                    child: Text(DateFormat('dd MMMM yyyy', 'id').format(tanggal),
                        style: const TextStyle(fontSize: 14, color: kTextDark)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: lokasiC,
                    decoration: const InputDecoration(labelText: 'Lokasi Kegiatan',
                        prefixIcon: Icon(Icons.location_on_outlined, color: kAccent))),
                const SizedBox(height: 12),
                TextField(controller: ketuplakC,
                    decoration: const InputDecoration(labelText: 'Ketuplak',
                        prefixIcon: Icon(Icons.person_outlined, color: kAccent))),
                const SizedBox(height: 12),
                TextField(controller: deskC, maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Deskripsi / Latar Belakang',
                        prefixIcon: Icon(Icons.description_outlined, color: kAccent))),
                const SizedBox(height: 12),
                TextField(controller: hasilC, maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Hasil & Capaian Kegiatan',
                        prefixIcon: Icon(Icons.check_circle_outline, color: kAccent))),
                const SizedBox(height: 12),
                TextField(controller: kendalaC, maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Kendala & Saran',
                        prefixIcon: Icon(Icons.warning_amber_outlined, color: kAccent))),
                const SizedBox(height: 12),
                TextField(controller: pesertaC,
                    decoration: const InputDecoration(
                        labelText: 'Peserta (pisahkan dengan koma)',
                        prefixIcon: Icon(Icons.group_outlined, color: kAccent))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status',
                      prefixIcon: Icon(Icons.flag_outlined, color: kAccent)),
                  items: StatusLaporan.all
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setModal(() => status = v!),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (judulC.text.trim().isEmpty) return;
                    final peserta = pesertaC.text.trim().isEmpty
                        ? <String>[]
                        : pesertaC.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    final l = LaporanKegiatan(
                      id: existing?.id ?? _uuid.v4(),
                      judul: judulC.text.trim(),
                      sekbid: sekbid,
                      penanggungJawab: ketuplakC.text.trim(),
                      tanggalKegiatan: tanggal,
                      lokasi: lokasiC.text.trim(),
                      deskripsi: deskC.text.trim(),
                      hasilCapaian: hasilC.text.trim(),
                      kendalaSaran: kendalaC.text.trim(),
                      status: status,
                      tanggalBuat: existing?.tanggalBuat ?? DateTime.now(),
                      peserta: peserta,
                      pembuatId: existing?.pembuatId ?? sekbid,
                    );
                    try {
                      if (existing == null) {
                        await DataService.addLaporan(l);
                        await NotificationService.notifyUpdate(
                          title: 'Laporan Keuplak Dibuat',
                          message: 'Laporan "${l.judul}" dibuat untuk ${l.sekbid} oleh ${widget.username}',
                          category: 'laporan',
                          actor: widget.username,
                        );
                      } else {
                        await DataService.updateLaporan(l);
                        await NotificationService.notifyUpdate(
                          title: 'Laporan Keuplak Diperbarui',
                          message: 'Laporan "${l.judul}" (${l.sekbid} - Status: ${l.status}) diperbarui oleh ${widget.username}',
                          category: 'laporan',
                          actor: widget.username,
                        );
                      }
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Laporan tersimpan'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                      }
                    }
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Text(existing == null ? 'Simpan Laporan' : 'Perbarui Laporan',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(LaporanKegiatan l) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                _statusBadge(l.status),
                const Spacer(),
                Text(DateFormat('dd MMM yyyy', 'id').format(l.tanggalKegiatan),
                    style: const TextStyle(fontSize: 12, color: kTextLight)),
              ]),
              const SizedBox(height: 10),
              Text(l.judul,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.group_outlined, size: 14, color: kTextLight),
                const SizedBox(width: 4),
                Text(l.sekbid, style: const TextStyle(fontSize: 12, color: kTextLight)),
                if (l.lokasi.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined, size: 14, color: kTextLight),
                  const SizedBox(width: 4),
                  Expanded(child: Text(l.lokasi, style: const TextStyle(fontSize: 12, color: kTextLight),
                      overflow: TextOverflow.ellipsis)),
                ],
              ]),
              const SizedBox(height: 16),
              if (l.deskripsi.isNotEmpty) ...[
                _sectionTitle('Deskripsi Kegiatan'),
                const SizedBox(height: 6),
                Text(l.deskripsi, style: const TextStyle(fontSize: 13, color: kTextMid, height: 1.5)),
                const SizedBox(height: 14),
              ],
              if (l.hasilCapaian.isNotEmpty) ...[
                _sectionTitle('Hasil & Capaian'),
                const SizedBox(height: 6),
                Text(l.hasilCapaian, style: const TextStyle(fontSize: 13, color: kTextMid, height: 1.5)),
                const SizedBox(height: 14),
              ],
              if (l.kendalaSaran.isNotEmpty) ...[
                _sectionTitle('Kendala & Saran'),
                const SizedBox(height: 6),
                Text(l.kendalaSaran, style: const TextStyle(fontSize: 13, color: kTextMid, height: 1.5)),
                const SizedBox(height: 14),
              ],
              if (l.peserta.isNotEmpty) ...[
                _sectionTitle('Peserta (${l.peserta.length})'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: l.peserta.map((p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: kPrimary.withAlpha(60), borderRadius: BorderRadius.circular(20)),
                    child: Text(p, style: const TextStyle(fontSize: 12, color: kTextDark)),
                  )).toList(),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 6),
              if (l.penanggungJawab.isNotEmpty)
                Text('Ketuplak: ${l.penanggungJawab}',
                    style: const TextStyle(fontSize: 11, color: kTextLight)),
              Text('Tanggal buat: ${DateFormat('dd MMM yyyy', 'id').format(l.tanggalBuat)}',
                  style: const TextStyle(fontSize: 11, color: kTextLight)),
              const SizedBox(height: 16),
              // Export buttons (semua bisa export)
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Export PDF'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    try {
                      final bytes = await PdfService.generateLaporanPdfBytes(l);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await Printing.layoutPdf(onLayout: (_) async => bytes);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Gagal export PDF: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('Export DOCX'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    try {
                      final file = await PdfService.generateLaporanDocx(l);
                      if (ctx.mounted) Navigator.pop(ctx);
                      await OpenFilex.open(file.path);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Gagal export DOCX: $e'), backgroundColor: Colors.red));
                      }
                    }
                  },
                )),
              ]),
              // Edit/Hapus hanya untuk pembuat
              if (_isOwner(l)) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: kAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () { Navigator.pop(ctx); _showForm(existing: l); },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Hapus'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      await DataService.deleteLaporan(l.id);
                      await NotificationService.notifyUpdate(
                        title: 'Laporan Keuplak Dihapus',
                        message: 'Laporan "${l.judul}" (${l.sekbid}) telah dihapus oleh ${widget.username}',
                        category: 'laporan',
                        actor: widget.username,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
                  )),
                ]),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextDark));

  Widget _statusBadge(String status) {
    final color = status == StatusLaporan.selesai ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(status == StatusLaporan.selesai ? Icons.check_circle_outline : Icons.edit_outlined,
            size: 12, color: color),
        const SizedBox(width: 4),
        Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            _filterBtn('Semua'),
            const SizedBox(width: 8),
            _filterBtn(StatusLaporan.draft),
            const SizedBox(width: 8),
            _filterBtn(StatusLaporan.selesai),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, color: kAccent),
              onPressed: _load,
              tooltip: 'Reload',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        if (filtered.isNotEmpty)
          Container(
            color: kAccent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Icon(Icons.summarize_outlined, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text('${filtered.length} laporan kegiatan',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.article_outlined, size: 72, color: kTextLight),
                  const SizedBox(height: 12),
                  const Text('Belum ada laporan', style: TextStyle(fontSize: 15, color: kTextMid)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: kAccent,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final l = filtered[i];
                      final isOwner = _isOwner(l);
                      return InkWell(
                        onTap: () => _showDetail(l),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              _statusBadge(l.status),
                              const Spacer(),
                              if (isOwner)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: kAccent.withAlpha(30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Milik saya',
                                      style: TextStyle(fontSize: 10, color: kAccent, fontWeight: FontWeight.w600)),
                                ),
                              const SizedBox(width: 6),
                              Text(DateFormat('dd/MM/yy').format(l.tanggalKegiatan),
                                  style: const TextStyle(fontSize: 11, color: kTextLight)),
                            ]),
                            const SizedBox(height: 8),
                            Text(l.judul,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kTextDark),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              if (l.sekbid.isNotEmpty) ...[
                                const Icon(Icons.group_outlined, size: 12, color: kTextLight),
                                const SizedBox(width: 4),
                                Text(l.sekbid, style: const TextStyle(fontSize: 11, color: kTextLight)),
                              ],
                              if (l.lokasi.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                const Icon(Icons.location_on_outlined, size: 12, color: kTextLight),
                                const SizedBox(width: 4),
                                Expanded(child: Text(l.lokasi,
                                    style: const TextStyle(fontSize: 11, color: kTextLight),
                                    overflow: TextOverflow.ellipsis)),
                              ],
                            ]),
                            if (l.deskripsi.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(l.deskripsi,
                                  style: const TextStyle(fontSize: 12, color: kTextMid),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            if (l.peserta.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('${l.peserta.length} peserta',
                                  style: const TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w600)),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterBtn(String label) {
    final selected = _filterStatus == label;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kAccent : kPrimary.withAlpha(60),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : kTextMid)),
      ),
    );
  }
}
