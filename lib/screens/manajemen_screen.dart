import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../app_theme.dart';

import 'admin_settings_screen.dart';

class ManajemenScreen extends StatefulWidget {
  const ManajemenScreen({super.key});
  @override
  State<ManajemenScreen> createState() => _ManajemenScreenState();
}

class _ManajemenScreenState extends State<ManajemenScreen> with SingleTickerProviderStateMixin {
  TabController? _tab;
  List<Siswa> _siswa = [];
  List<JenisPelanggaran> _jenis = [];
  String _username = '';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  StreamSubscription<String>? _dataSub;

  static const _superUsers = ['KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA'];
  bool get _isAdmin     => _username == 'ADMIN' || AuthService.getRole(_username) == 'ADMIN';
  bool get _isPembina   => _isAdmin || _username == 'PEMBINA' || _username == 'KESISWAAN' || AuthService.getRole(_username) == 'PEMBINA' || AuthService.getRole(_username) == 'KESISWAAN';
  bool get _isSuperUser => _isAdmin || _isPembina || _superUsers.contains(_username);
  bool get _canSeeJenis => _isSuperUser || _username == 'SEKBID2' || _isPembina;
  bool get _canEditJenis => _isSuperUser || _username == 'SEKBID2' || _isPembina;
  bool get _canSeeSiswa => _isSuperUser || _isPembina;
  bool get _canEditSiswa => _isSuperUser || _isPembina;
  // Semua role yang bisa akses manajemen bisa lihat Status Cloud
  bool get _canSeeCloud => _isSuperUser || _isPembina;
  int get _tabCount =>
      (_canSeeSiswa ? 1 : 0) +
      (_canSeeJenis ? 1 : 0) +
      (_canSeeCloud ? 1 : 0) +
      (_isPembina   ? 1 : 0);
  int get _siswaTabIndex => 0;
  int get _jenisTabIndex => _canSeeSiswa ? 1 : 0;

  List<Siswa> get _filteredSiswa {
    if (_searchQuery.isEmpty) return _siswa;
    final q = _searchQuery.toLowerCase();
    return _siswa.where((s) =>
      s.nama.toLowerCase().contains(q) ||
      s.nis.toLowerCase().contains(q) ||
      s.kelas.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'siswa' || table == 'jenis_pelanggaran' || table == 'file_riwayat' || table == 'all') {
        if (mounted) _load();
      }
    });
    AuthService.getUserName().then((v) {
      if (!mounted) return;
      setState(() {
        _username = v ?? '';
        _tab?.dispose();
        _tab = TabController(length: _tabCount, vsync: this)
          ..addListener(() => setState(() {}));
      });
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _tab?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await DataService.getSiswa();
    final j = await DataService.getJenis();
    if (!mounted) return;
    setState(() { _siswa = s; _jenis = j; });
  }

  Future<void> _importExcelSiswa() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null) return;
      final file = result.files.single;
      final bytes = await file.readAsBytes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mengimpor ke Supabase...'), duration: Duration(seconds: 30)));
      }
      final count = await DataService.importStudentsFromExcel(bytes, namaFile: file.name);
      if (count > 0) {
        await NotificationService.notifyUpdate(
          title: 'Import Data Siswa',
          message: '$count data siswa dari file "${file.name}" berhasil diimpor oleh $_username',
          category: 'manajemen',
          actor: _username,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(count > 0 ? '$count siswa berhasil diimpor ke Supabase' : 'Semua siswa sudah ada, tidak ada yang baru'),
          backgroundColor: count > 0 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 4),
        ));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal impor: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  Future<void> _showFileRiwayat() async {
    var riwayat = await DataService.getFileRiwayat();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Riwayat File', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
              const SizedBox(height: 4),
              const Text('Pilih file untuk hapus siswa atau naik kelas',
                  style: TextStyle(fontSize: 12, color: kTextMid)),
              const SizedBox(height: 16),
              if (riwayat.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('Belum ada file yang diupload', style: TextStyle(color: kTextMid))),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: riwayat.length,
                    itemBuilder: (_, i) {
                      final f = riwayat[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: kPrimary.withAlpha(80)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.insert_drive_file_outlined, color: kAccent),
                          title: Text(f.namaFile, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark)),
                          subtitle: Text(
                            '${f.nisList.length} siswa • ${f.tanggalUpload.day}/${f.tanggalUpload.month}/${f.tanggalUpload.year}',
                            style: const TextStyle(fontSize: 11, color: kTextMid),
                          ),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            // Naik kelas
                            IconButton(
                              tooltip: 'Naik Kelas',
                              icon: const Icon(Icons.arrow_upward, color: Colors.blue, size: 20),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: ctx,
                                  builder: (d) => AlertDialog(
                                    title: const Text('Naik Kelas?'),
                                    content: Text('Semua ${f.nisList.length} siswa di file "${f.namaFile}" akan dinaikkan kelasnya (X→XI, XI→XII). Lanjutkan?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                        child: const Text('Naik Kelas'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true || !ctx.mounted) return;
                                final count = await DataService.naikKelasFromFile(f);
                                await NotificationService.notifyUpdate(
                                  title: 'Kenaikan Kelas Siswa',
                                  message: '$count siswa dari file "${f.namaFile}" dinaikkan kelasnya oleh $_username',
                                  category: 'manajemen',
                                  actor: _username,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context) // ignore: use_build_context_synchronously
                                    .showSnackBar(SnackBar(
                                    content: Text('$count siswa berhasil dinaikkan kelasnya'),
                                    backgroundColor: Colors.blue,
                                    duration: const Duration(seconds: 3),
                                  ));
                                  _load();
                                }
                              },
                            ),
                            // Turun kelas
                            IconButton(
                              tooltip: 'Turun Kelas',
                              icon: const Icon(Icons.arrow_downward, color: Colors.orange, size: 20),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: ctx,
                                  builder: (d) => AlertDialog(
                                    title: const Text('Turun Kelas?'),
                                    content: Text('Semua ${f.nisList.length} siswa di file "${f.namaFile}" akan diturunkan kelasnya (XII→XI, XI→X). Lanjutkan?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                        child: const Text('Turun Kelas'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true || !ctx.mounted) return;
                                final count = await DataService.turunKelasFromFile(f);
                                await NotificationService.notifyUpdate(
                                  title: 'Penurunan Kelas Siswa',
                                  message: '$count siswa dari file "${f.namaFile}" diturunkan kelasnya oleh $_username',
                                  category: 'manajemen',
                                  actor: _username,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context) // ignore: use_build_context_synchronously
                                    .showSnackBar(SnackBar(
                                    content: Text('$count siswa berhasil diturunkan kelasnya'),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 3),
                                  ));
                                  _load();
                                }
                              },
                            ),
                            // Hapus file + siswa
                            IconButton(
                              tooltip: 'Hapus File & Siswa',
                              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.red, size: 20),
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: ctx,
                                  builder: (d) => AlertDialog(
                                    title: const Text('Hapus File & Siswa?'),
                                    content: Text('File "${f.namaFile}" dan semua ${f.nisList.length} siswa di dalamnya akan dihapus permanen.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(d, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok != true || !ctx.mounted) return;
                                // Hapus semua siswa sekaligus (batch) + hapus file riwayat
                                await Future.wait([
                                  DataService.deleteSiswaByNisList(f.nisList),
                                  DataService.deleteFileRiwayat(f.id),
                                ]);
                                await NotificationService.notifyUpdate(
                                  title: 'Data Siswa & Riwayat Dihapus',
                                  message: 'File "${f.namaFile}" dan ${f.nisList.length} data siswa di dalamnya telah dihapus oleh $_username',
                                  category: 'manajemen',
                                  actor: _username,
                                );
                                if (!ctx.mounted) return;
                                // Update UI modal langsung tanpa tutup
                                setS(() => riwayat = riwayat.where((r) => r.id != f.id).toList());
                                ScaffoldMessenger.of(context) // ignore: use_build_context_synchronously
                                  .showSnackBar(SnackBar(
                                  content: Text('File dan ${f.nisList.length} siswa berhasil dihapus'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 3),
                                ));
                                _load();
                              },
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSiswaForm([Siswa? existing]) {
    final namaC = TextEditingController(text: existing?.nama);
    final kelasC = TextEditingController(text: existing?.kelas);
    final nisC = TextEditingController(text: existing?.nis);
    _showBottomForm(
      title: existing == null ? 'Tambah Siswa' : 'Edit Siswa',
      fields: [
        TextField(controller: namaC, decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person_outline, color: kAccent))),
        const SizedBox(height: 12),
        TextField(controller: kelasC, decoration: const InputDecoration(labelText: 'Kelas', prefixIcon: Icon(Icons.class_outlined, color: kAccent))),
        const SizedBox(height: 12),
        TextField(controller: nisC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'NIS', prefixIcon: Icon(Icons.badge_outlined, color: kAccent))),
      ],
      onSave: () async {
        if (namaC.text.isEmpty) return false;
        if (existing != null) {
          await DataService.updateSiswa(Siswa(id: existing.id, nama: namaC.text, kelas: kelasC.text, nis: nisC.text));
          await NotificationService.notifyUpdate(
            title: 'Data Siswa Diperbarui',
            message: 'Data siswa "${namaC.text}" (${kelasC.text}) diperbarui oleh $_username',
            category: 'manajemen',
            actor: _username,
          );
        } else {
          await DataService.addSiswa(namaC.text, kelasC.text, nisC.text);
          await NotificationService.notifyUpdate(
            title: 'Data Siswa Ditambahkan',
            message: 'Siswa baru "${namaC.text}" (${kelasC.text} - NIS: ${nisC.text}) ditambahkan oleh $_username',
            category: 'manajemen',
            actor: _username,
          );
        }
        return true;
      },
    );
  }

  void _showJenisForm([JenisPelanggaran? existing]) {
    final namaC = TextEditingController(text: existing?.nama);
    List<int> selectedHari = List.from(existing?.hariAktif ?? []);
    const hariLabels = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat'];
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
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(existing == null ? 'Tambah Jenis Pelanggaran' : 'Edit Jenis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
              const SizedBox(height: 16),
              TextField(controller: namaC, decoration: const InputDecoration(
                labelText: 'Nama Pelanggaran', prefixIcon: Icon(Icons.warning_amber_outlined, color: kAccent))),
              const SizedBox(height: 16),
              Text('Aktif pada hari:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : kTextDark)),
              const SizedBox(height: 4),
              Text('Kosongkan = muncul setiap hari', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : kTextLight)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: List.generate(5, (i) {
                  final hari = i + 1;
                  final selected = selectedHari.contains(hari);
                  return FilterChip(
                    label: Text(hariLabels[i]),
                    selected: selected,
                    onSelected: (v) => setModal(() {
                      if (v) { selectedHari.add(hari); } else { selectedHari.remove(hari); }
                      selectedHari.sort();
                    }),
                    selectedColor: kAccent,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : kTextDark),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: isDark ? const Color(0xFF0E1626) : kPrimary.withAlpha(60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: isDark && !selected ? const BorderSide(color: Color(0xFF243452)) : BorderSide.none,
                    showCheckmark: false,
                  );
                }),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (namaC.text.trim().isEmpty) return;
                  if (existing == null) {
                    await DataService.addJenis(namaC.text.trim(), hariAktif: selectedHari);
                    await NotificationService.notifyUpdate(
                      title: 'Jenis Pelanggaran Baru',
                      message: 'Jenis pelanggaran "${namaC.text.trim()}" telah ditambahkan oleh $_username',
                      category: 'manajemen',
                      actor: _username,
                    );
                  } else {
                    await DataService.updateJenis(JenisPelanggaran(id: existing.id, nama: namaC.text.trim(), hariAktif: selectedHari));
                    await NotificationService.notifyUpdate(
                      title: 'Jenis Pelanggaran Diperbarui',
                      message: 'Jenis pelanggaran "${namaC.text.trim()}" telah diperbarui oleh $_username',
                      category: 'manajemen',
                      actor: _username,
                    );
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Tersimpan ke Supabase'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ));
                    _load();
                  }
                },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBottomForm({required String title, required List<Widget> fields, required Future<bool> Function() onSave}) {
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
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: isDark ? const Color(0xFF243452) : kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : kTextDark)),
            const SizedBox(height: 16),
            ...fields,
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  final ok = await onSave();
                  if (ok && ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Tersimpan ke Supabase'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ));
                    _load();
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Simpan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manajemen'),
        actions: [
          if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
              tooltip: 'Panel Super Admin',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
              ),
            ),
        ],
        bottom: _tab == null ? null : TabBar(
          controller: _tab!,
          tabs: [
            if (_canSeeSiswa) const Tab(text: 'Siswa'),
            if (_canSeeJenis) const Tab(text: 'Jenis Pelanggaran'),
            if (_canSeeCloud) const Tab(text: 'Status Cloud'),
            if (_isPembina)   const Tab(text: 'Konfigurasi Akun'),
          ],
        ),
      ),
      body: _tab == null
          ? Center(child: CircularProgressIndicator(color: primary))
          : TabBarView(
        controller: _tab!,
        children: [
          if (_canSeeSiswa) Column(children: [
            Container(
              color: isDark ? const Color(0xFF141D2E) : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Data Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textTitle)),
                      Text('${_filteredSiswa.length}${_searchQuery.isNotEmpty ? ' dari ${_siswa.length}' : ''} siswa', style: TextStyle(fontSize: 12, color: textSub)),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  // ── Search bar ──
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Cari nama, NIS, atau kelas...',
                      prefixIcon: Icon(Icons.search, color: primary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  if (_canEditSiswa) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _importExcelSiswa,
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Impor Excel', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showFileRiwayat,
                          icon: const Icon(Icons.folder_open_outlined, size: 16),
                          label: const Text('Kelola File', style: TextStyle(fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? primary : kAccent,
                            foregroundColor: isDark ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text('Format: kolom Nama, Kelas, NIS (baris pertama = header)',
                        style: TextStyle(fontSize: 10, color: textMuted)),
                  ],
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
            Expanded(
              child: _siswa.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline, size: 64, color: textMuted),
                      const SizedBox(height: 12),
                      Text('Belum ada data siswa', style: TextStyle(color: textSub, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Impor dari Excel atau tap + untuk tambah manual', style: TextStyle(color: textMuted, fontSize: 12)),
                    ]))
                  : _filteredSiswa.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.search_off, size: 48, color: textMuted),
                          const SizedBox(height: 12),
                          Text('Tidak ada siswa "$_searchQuery"', style: TextStyle(color: textSub)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          itemCount: _filteredSiswa.length,
                          itemBuilder: (_, i) {
                            final s = _filteredSiswa[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: cardBorder),
                                boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(60), blurRadius: 4)],
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isDark ? const Color(0xFF1A263D) : kPrimary,
                                  child: Text(s.nama.isNotEmpty ? s.nama.substring(0, 1).toUpperCase() : '?',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? primary : kTextDark))),
                                title: Text(s.nama, style: TextStyle(fontWeight: FontWeight.bold, color: textTitle)),
                                subtitle: Text('Kelas ${s.kelas} • NIS: ${s.nis}', style: TextStyle(color: textSub, fontSize: 12)),
                                trailing: _canEditSiswa ? Row(mainAxisSize: MainAxisSize.min, children: [
                                  IconButton(icon: Icon(Icons.edit_outlined, color: primary, size: 20), onPressed: () => _showSiswaForm(s)),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () async {
                                      await DataService.deleteSiswa(s.id);
                                      await NotificationService.notifyUpdate(
                                        title: 'Data Siswa Dihapus',
                                        message: 'Data siswa "${s.nama}" (${s.kelas}) telah dihapus oleh $_username',
                                        category: 'manajemen',
                                        actor: _username,
                                      );
                                      _load();
                                    },
                                  ),
                                ]) : null,
                              ),
                            );
                          },
                        ),
            ),
          ]),

          // ── Jenis Pelanggaran ──
          if (_canSeeJenis)
          _jenis.isEmpty
              ? Center(child: Text('Belum ada jenis pelanggaran', style: TextStyle(color: textSub)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  itemCount: _jenis.length,
                  itemBuilder: (_, i) {
                    final j = _jenis[i];
                    const hariLabels = ['', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum'];
                    final hariText = j.hariAktif.isEmpty
                        ? 'Semua hari'
                        : j.hariAktif.map((h) => hariLabels[h]).join(', ');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                        boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(60), blurRadius: 4)],
                      ),
                      child: ListTile(
                        leading: Icon(Icons.warning_amber_outlined, color: primary, size: 22),
                        title: Text(j.nama, style: TextStyle(fontWeight: FontWeight.bold, color: textTitle)),
                        subtitle: Text(hariText, style: TextStyle(fontSize: 11, color: textSub)),
                        trailing: _canEditJenis ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: Icon(Icons.edit_outlined, color: primary, size: 20), onPressed: () => _showJenisForm(j)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () async {
                              await DataService.deleteJenis(j.id);
                              await NotificationService.notifyUpdate(
                                title: 'Jenis Pelanggaran Dihapus',
                                message: 'Jenis pelanggaran "${j.nama}" telah dihapus oleh $_username',
                                category: 'manajemen',
                                actor: _username,
                              );
                              _load();
                            },
                          ),
                        ]) : null,
                      ),
                    );
                  },
                ),

          // ── Status Koneksi ──
          if (_canSeeCloud) const _CloudStatusTab(),
          // ── Konfigurasi Akun (Pembina only) ──
          if (_isPembina) const _KonfigurasiAkunTab(),
        ],
      ),
      floatingActionButton: (_canEditSiswa && _canSeeSiswa && (_tab?.index ?? 0) == _siswaTabIndex)
          ? FloatingActionButton(onPressed: _showSiswaForm, backgroundColor: primary, foregroundColor: isDark ? Colors.black : Colors.white, child: const Icon(Icons.add))
          : (_canEditJenis && _canSeeJenis && (_tab?.index ?? 0) == _jenisTabIndex)
              ? FloatingActionButton(onPressed: _showJenisForm, backgroundColor: primary, foregroundColor: isDark ? Colors.black : Colors.white, child: const Icon(Icons.add))
              : null,
    );
  }
}

class _CloudStatusTab extends StatefulWidget {
  const _CloudStatusTab();
  @override
  State<_CloudStatusTab> createState() => _CloudStatusTabState();
}

class _CloudStatusTabState extends State<_CloudStatusTab> {
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _isLoading = true);
    try {
      final connected = await DataService.checkConnection();
      setState(() { _isConnected = connected; _isLoading = false; });
    } catch (_) {
      setState(() { _isConnected = false; _isLoading = false; });
    }
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isLoading
                  ? [const Color(0xFF90A4AE), const Color(0xFFB0BEC5)]
                  : _isConnected
                      ? [const Color(0xFF00B09B), const Color(0xFF96C93D)]
                      : [const Color(0xFFF7971E), const Color(0xFFFFD200)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            if (_isLoading)
              const SizedBox(width: 40, height: 40,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
            else
              Icon(_isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                  color: Colors.white, size: 40),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _isLoading ? 'MENGHUBUNGKAN...' : _isConnected ? 'TERHUBUNG KE SUPABASE' : 'KONEKSI BERMASALAH',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                _isLoading
                    ? 'Sedang memeriksa koneksi...'
                    : _isConnected
                        ? 'Semua data otomatis tersimpan ke cloud'
                        : 'Periksa koneksi internet Anda',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.dns_outlined, size: 16, color: primary),
              const SizedBox(width: 8),
              Text('Supabase Project', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textTitle)),
            ]),
            const SizedBox(height: 10),
            Text('vvvrzxaxnumtstlgovqw.supabase.co',
                style: TextStyle(fontSize: 12, color: textSub, fontFamily: 'monospace')),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isConnected
                    ? (isDark ? Colors.green.withAlpha(40) : Colors.green.shade50)
                    : (isDark ? Colors.orange.withAlpha(40) : Colors.orange.shade50),
                borderRadius: BorderRadius.circular(6),
                border: isDark ? Border.all(color: _isConnected ? Colors.green.withAlpha(80) : Colors.orange.withAlpha(80)) : null,
              ),
              child: Text(
                _isConnected ? '● Auto-sync aktif — data langsung masuk cloud' : '● Offline — data tersimpan lokal sementara',
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: _isConnected ? (isDark ? Colors.green.shade400 : Colors.green.shade700) : (isDark ? Colors.orange.shade400 : Colors.orange.shade700),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline, size: 16, color: primary),
              const SizedBox(width: 8),
              Text('Cara Kerja', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textTitle)),
            ]),
            const SizedBox(height: 10),
            ..._infoItems([
              'Tambah / edit / hapus data → langsung tersimpan ke Supabase',
              'Tidak perlu pencet tombol sinkronisasi',
              'Jika offline, data tersimpan lokal dan akan sync otomatis saat online',
            ], isDark: isDark, primary: primary),
          ]),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _check,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Cek Koneksi Ulang'),
          style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: isDark ? const Color(0xFF243452) : primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  List<Widget> _infoItems(List<String> items, {bool isDark = false, Color primary = kAccent}) => items.map((t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.check_circle_outline, size: 14, color: primary),
      const SizedBox(width: 8),
      Expanded(child: Text(t, style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : kTextMid))),
    ]),
  )).toList();
}

class _KonfigurasiAkunTab extends StatefulWidget {
  const _KonfigurasiAkunTab();
  @override
  State<_KonfigurasiAkunTab> createState() => _KonfigurasiAkunTabState();
}

class _KonfigurasiAkunTabState extends State<_KonfigurasiAkunTab> {
  Map<String, String> _accounts = {};
  bool _isSyncing = false;
  StreamSubscription<String>? _sub;

  @override
  void initState() {
    super.initState();
    _accounts = Map.from(AuthService.accounts);
    _sub = DataService.onDataChanged.listen((t) {
      if (t == 'accounts' || t == 'all') {
        if (mounted) {
          setState(() => _accounts = Map.from(AuthService.accounts));
        }
      }
    });
    _syncAccounts();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _syncAccounts() async {
    setState(() => _isSyncing = true);
    await AuthService.syncWithSupabase();
    if (mounted) {
      setState(() {
        _accounts = Map.from(AuthService.accounts);
        _isSyncing = false;
      });
    }
  }

  void _showEditDialog(String username) {
    final passC = TextEditingController();
    bool obscure = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Ubah Password: $username'),
          content: TextField(
            controller: passC,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'Password Baru',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                onPressed: () => setD(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (passC.text.trim().isEmpty) return;
                final newPass = passC.text.trim();
                await AuthService.changePassword(username, newPass);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                setState(() => _accounts = Map.from(AuthService.accounts));
                ScaffoldMessenger.of(context).showSnackBar(// ignore: use_build_context_synchronously
                  SnackBar(content: Text('Password $username diperbarui & tersinkron ke Supabase'), backgroundColor: Colors.green));
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Semua Password?'),
        content: const Text('Semua password akan dikembalikan ke default dan disinkronkan ke Supabase. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await AuthService.resetAccounts();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              setState(() => _accounts = Map.from(AuthService.accounts));
              ScaffoldMessenger.of(context).showSnackBar(// ignore: use_build_context_synchronously
                const SnackBar(content: Text('Semua password direset ke default dan disinkronkan ke Supabase'), backgroundColor: Colors.orange));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
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
    final textMuted = isDark ? const Color(0xFF64748B) : kTextLight;

    final entries = _accounts.entries.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D2E) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF243452) : Colors.blue.shade200),
          ),
          child: Row(children: [
            Icon(Icons.cloud_sync_rounded, color: primary, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Akun tersinkronisasi otomatis dengan Supabase Cloud. Perubahan password langsung aktif di seluruh perangkat pengguna.',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : Colors.blue.shade700),
            )),
            if (_isSyncing)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: primary,
                tooltip: 'Sinkron Ulang Akun',
                onPressed: _syncAccounts,
              ),
          ]),
        ),
        const SizedBox(height: 16),
        ...entries.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cardBorder),
            boxShadow: isDark ? null : [BoxShadow(color: kPrimary.withAlpha(60), blurRadius: 4)],
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDark ? const Color(0xFF1A263D) : kPrimary,
              child: Text(e.key.substring(0, 1), style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? primary : kTextDark, fontSize: 13)),
            ),
            title: Text(e.key, style: TextStyle(fontWeight: FontWeight.bold, color: textTitle, fontSize: 14)),
            subtitle: Text('●' * e.value.length.clamp(0, 12), style: TextStyle(fontSize: 12, color: textMuted, letterSpacing: 2)),
            trailing: IconButton(
              icon: Icon(Icons.edit_outlined, color: primary, size: 20),
              onPressed: () => _showEditDialog(e.key),
            ),
          ),
        )),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showResetDialog,
          icon: const Icon(Icons.restore, size: 18),
          label: const Text('Reset Semua ke Default'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ]),
    );
  }
}
