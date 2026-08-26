import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../services/notification_service.dart';
import '../services/localization_service.dart';
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
                Text(existing == null ? LocalizationService.tr('laporan_add') : LocalizationService.tr('laporan_edit'),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                const SizedBox(height: 16),
                TextField(
                  controller: judulC,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('laporan_name'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.event_outlined, color: kAccent),
                  ),
                ),
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
                    decoration: InputDecoration(
                      labelText: LocalizationService.tr('laporan_date'),
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      prefixIcon: const Icon(Icons.calendar_month_outlined, color: kAccent),
                    ),
                    child: Text(DateFormat('dd MMMM yyyy', LocalizationService.currentLocale.value.languageCode).format(tanggal),
                        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : kTextDark)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lokasiC,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('laporan_location'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.location_on_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ketuplakC,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('laporan_leader'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.person_outlined, color: kAccent),
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
                    prefixIcon: const Icon(Icons.description_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hasilC,
                  maxLines: 3,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('laporan_result'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.check_circle_outline, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: kendalaC,
                  maxLines: 2,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('laporan_eval'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.warning_amber_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pesertaC,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: LocalizationService.tr('laporan_participants'),
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.group_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.flag_outlined, color: kAccent),
                  ),
                  items: StatusLaporan.all
                      .map((s) => DropdownMenuItem(value: s, child: Text(LocalizationService.formatStatus(s))))
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
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(LocalizationService.tr('msg_saved')),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('${LocalizationService.tr('msg_error')}: $e'), backgroundColor: Colors.red));
                      }
                    }
                    _load();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(LocalizationService.tr('btn_save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetail(LaporanKegiatan l) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.judul, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
                      const SizedBox(height: 4),
                      Text(DateFormat('dd MMMM yyyy', LocalizationService.currentLocale.value.languageCode).format(l.tanggalKegiatan),
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : kTextMid)),
                    ]),
                  ),
                  _statusBadge(l.status),
                ],
              ),
              const SizedBox(height: 16),
              if (l.sekbid.isNotEmpty) ...[
                _sectionTitle(LocalizationService.tr('proker_sekbid'), isDark: isDark),
                const SizedBox(height: 4),
                Text(l.sekbid, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : kTextMid)),
                const SizedBox(height: 12),
              ],
              if (l.penanggungJawab.isNotEmpty) ...[
                _sectionTitle(LocalizationService.tr('laporan_leader'), isDark: isDark),
                const SizedBox(height: 4),
                Text(l.penanggungJawab, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : kTextMid)),
                const SizedBox(height: 12),
              ],
              if (l.lokasi.isNotEmpty) ...[
                _sectionTitle(LocalizationService.tr('laporan_location'), isDark: isDark),
                const SizedBox(height: 4),
                Text(l.lokasi, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : kTextMid)),
                const SizedBox(height: 12),
              ],
              if (l.deskripsi.isNotEmpty) ...[
                _sectionTitle(LocalizationService.tr('proker_desc'), isDark: isDark),
                const SizedBox(height: 4),
                Text(l.deskripsi, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : kTextMid, height: 1.5)),
                const SizedBox(height: 12),
              ],
              if (l.hasilCapaian.isNotEmpty) ...[
                _sectionTitle(LocalizationService.tr('laporan_result'), isDark: isDark),
                const SizedBox(height: 4),
                Text(l.hasilCapaian, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : kTextMid, height: 1.5)),
                const SizedBox(height: 12),
              ],
              if (l.kendalaSaran.isNotEmpty) ...[
                _sectionTitle(LocalizationService.tr('laporan_eval'), isDark: isDark),
                const SizedBox(height: 4),
                Text(l.kendalaSaran, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : kTextMid, height: 1.5)),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                  label: const Text('Export PDF'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
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
                      foregroundColor: primary,
                      side: BorderSide(color: primary),
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
              if (_isOwner(l)) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: isDark ? primary : null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(LocalizationService.tr('btn_edit')),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showForm(existing: l);
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(LocalizationService.tr('btn_delete')),
                    onPressed: () async {
                      await DataService.deleteLaporan(l.id);
                      await NotificationService.notifyUpdate(
                        title: 'Laporan Kegiatan Dihapus',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, {bool isDark = false}) => Text(t,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark));

  Widget _statusBadge(String status) {
    final color = status == StatusLaporan.selesai ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(status == StatusLaporan.selesai ? Icons.check_circle_outline : Icons.edit_outlined,
            size: 12, color: color),
        const SizedBox(width: 4),
        Text(LocalizationService.formatStatus(status), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

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

    final filtered = _filtered;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(children: [
        Container(
          color: isDark ? const Color(0xFF141D2E) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            _filterBtn(LocalizationService.tr('btn_all'), isDark: isDark, primary: primary),
            const SizedBox(width: 8),
            _filterBtn(LocalizationService.tr('status_draft'), isDark: isDark, primary: primary),
            const SizedBox(width: 8),
            _filterBtn(LocalizationService.tr('status_done'), isDark: isDark, primary: primary),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh, color: primary),
              onPressed: _load,
              tooltip: LocalizationService.tr('btn_refresh'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
        if (filtered.isNotEmpty)
          Container(
            color: isDark ? const Color(0xFF1A263D) : primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              const Icon(Icons.summarize_outlined, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text('${filtered.length} ${LocalizationService.tr('nav_laporan').toLowerCase()}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ]),
          ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: primary))
              : filtered.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.article_outlined, size: 72, color: textMuted),
                  const SizedBox(height: 12),
                  Text(LocalizationService.tr('laporan_empty'), style: TextStyle(fontSize: 15, color: textSub)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: primary,
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
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                            boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(80), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              _statusBadge(l.status),
                              const Spacer(),
                              if (isOwner)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primary.withAlpha(isDark ? 45 : 30),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(LocalizationService.currentLocale.value.languageCode == 'en' ? 'My Report' : 'Milik saya',
                                      style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.w600)),
                                ),
                              const SizedBox(width: 6),
                              Text(DateFormat('dd/MM/yy').format(l.tanggalKegiatan),
                                  style: TextStyle(fontSize: 11, color: textMuted)),
                            ]),
                            const SizedBox(height: 8),
                            Text(l.judul,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textTitle),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              if (l.sekbid.isNotEmpty) ...[
                                Icon(Icons.group_outlined, size: 12, color: textMuted),
                                const SizedBox(width: 4),
                                Text(l.sekbid, style: TextStyle(fontSize: 11, color: textMuted)),
                              ],
                              if (l.lokasi.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Icon(Icons.location_on_outlined, size: 12, color: textMuted),
                                const SizedBox(width: 4),
                                Expanded(child: Text(l.lokasi,
                                    style: TextStyle(fontSize: 11, color: textMuted),
                                    overflow: TextOverflow.ellipsis)),
                              ],
                            ]),
                            if (l.deskripsi.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(l.deskripsi,
                                  style: TextStyle(fontSize: 12, color: textSub),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                            if (l.peserta.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('${l.peserta.length} ${LocalizationService.currentLocale.value.languageCode == 'en' ? 'participants' : 'peserta'}',
                                  style: TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w600)),
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
        backgroundColor: primary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _filterBtn(String label, {bool isDark = false, Color primary = kAccent}) {
    String actualFilter = label;
    if (label == LocalizationService.tr('btn_all') || label == 'Semua') {
      actualFilter = 'Semua';
    } else if (label == LocalizationService.tr('status_draft') || label == StatusLaporan.draft) {
      actualFilter = StatusLaporan.draft;
    } else if (label == LocalizationService.tr('status_done') || label == StatusLaporan.selesai) {
      actualFilter = StatusLaporan.selesai;
    }

    final selected = _filterStatus == actualFilter;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = actualFilter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary
              : (isDark ? const Color(0xFF0E1626) : kPrimary.withAlpha(60)),
          borderRadius: BorderRadius.circular(20),
          border: isDark && !selected ? Border.all(color: const Color(0xFF243452)) : null,
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: selected ? (isDark ? Colors.black : Colors.white) : (isDark ? const Color(0xFF94A3B8) : kTextMid))),
      ),
    );
  }
}
