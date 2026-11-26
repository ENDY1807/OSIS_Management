import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class InformasiDokumentasiScreen extends StatefulWidget {
  final String username;
  final int initialSubTab;

  const InformasiDokumentasiScreen({
    super.key,
    required this.username,
    this.initialSubTab = 0,
  });

  @override
  State<InformasiDokumentasiScreen> createState() => _InformasiDokumentasiScreenState();
}

class _InformasiDokumentasiScreenState extends State<InformasiDokumentasiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<PengumumanOsis> _pengumumanList = [];
  List<DokumentasiKegiatan> _dokumentasiList = [];
  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  String _filterPengumuman = 'Semua';
  String _filterDokumentasi = 'Semua';

  bool get _canPostPengumuman => AuthService.canPostPengumuman(widget.username);
  bool get _canManageDokumentasi => AuthService.canManageProker(widget.username);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialSubTab.clamp(0, 1),
    );
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });

    _loadData();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'pengumuman_osis' || table == 'dokumentasi_kegiatan' || table == 'all') {
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
      final pgm = await DataService.getPengumuman();
      final dok = await DataService.getDokumentasi();
      if (!mounted) return;
      setState(() {
        _pengumumanList = pgm;
        _dokumentasiList = dok;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PengumumanOsis> get _filteredPengumuman {
    if (_filterPengumuman == 'Semua') return _pengumumanList;
    return _pengumumanList.where((p) => p.kategori.toLowerCase() == _filterPengumuman.toLowerCase()).toList();
  }

  List<DokumentasiKegiatan> get _filteredDokumentasi {
    if (_filterDokumentasi == 'Semua') return _dokumentasiList;
    return _dokumentasiList.where((d) => d.kategori.toLowerCase() == _filterDokumentasi.toLowerCase()).toList();
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
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
            tabs: const [
              Tab(icon: Icon(Icons.campaign_rounded, size: 18), text: 'Informasi & Pengumuman'),
              Tab(icon: Icon(Icons.photo_library_rounded, size: 18), text: 'Dokumentasi Kegiatan'),
            ],
          ),
        ),
      ),
      body: _loading && _pengumumanList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPengumumanTab(theme, isDark, primary),
                _buildDokumentasiTab(theme, isDark, primary),
              ],
            ),
      floatingActionButton: Builder(
        builder: (context) {
          final isTab0 = _tabCtrl.index == 0;
          final canAdd = isTab0 ? _canPostPengumuman : _canManageDokumentasi;
          if (!canAdd) return const SizedBox.shrink();

          return FloatingActionButton(
            onPressed: () {
              if (isTab0) {
                _showPengumumanDialog();
              } else {
                _showDokumentasiDialog();
              }
            },
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: const CircleBorder(),
            tooltip: isTab0 ? 'Buat Pengumuman' : 'Unggah Dokumentasi',
            child: const Icon(Icons.add_rounded, size: 28),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: INFORMASI & PENGUMUMAN
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildPengumumanTab(ThemeData theme, bool isDark, Color primary) {
    final filtered = _filteredPengumuman;

    return Column(
      children: [
        // Filter & Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Kategori: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ...['Semua', 'Ketua OSIS', 'Pembina OSIS', 'Rapat', 'Kegiatan', 'Tugas Bidang', 'Umum'].map((cat) {
                        final isSelected = _filterPengumuman == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: primary,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(
                              color: isSelected
                                  ? primary
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            onSelected: (_) => setState(() => _filterPengumuman = cat),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Belum ada pengumuman untuk kategori ini.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return _buildPengumumanCard(item, isDark, primary);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPengumumanCard(PengumumanOsis p, bool isDark, Color primary) {
    Color badgeColor = Colors.blue;
    if (p.kategori.toLowerCase().contains('ketua')) badgeColor = Colors.indigoAccent;
    if (p.kategori.toLowerCase().contains('pembina')) badgeColor = Colors.purple;
    if (p.kategori.toLowerCase().contains('tugas')) badgeColor = Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p.isPinned
              ? Colors.amber.withAlpha(180)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: p.isPinned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (p.isPinned) ...[
                      const Icon(Icons.push_pin_rounded, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withAlpha(isDark ? 40 : 25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withAlpha(120), width: 0.8),
                        ),
                        child: Text(
                          p.kategori,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('dd MMM yyyy • HH:mm').format(p.tanggal),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (_canPostPengumuman)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'pin') {
                      p.isPinned = !p.isPinned;
                      DataService.savePengumuman(p);
                    } else if (val == 'edit') {
                      _showPengumumanDialog(existing: p);
                    } else if (val == 'delete') {
                      _confirmDeletePengumuman(p);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Text(p.isPinned ? 'Lepas Pin' : 'Sematkan (Pin)'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.judul,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            p.isi,
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pengirim: ${p.pengirim} (${p.rolePengirim})',
                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
              if (p.targetBidang != 'Semua')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Target: ${p.targetBidang}',
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPengumumanDialog({PengumumanOsis? existing}) {
    final judulCtrl = TextEditingController(text: existing?.judul ?? '');
    final isiCtrl = TextEditingController(text: existing?.isi ?? '');
    String kategori = existing?.kategori ?? 'Umum';
    String target = existing?.targetBidang ?? 'Semua';
    bool isPinned = existing?.isPinned ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Buat Pengumuman Baru' : 'Edit Pengumuman', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: judulCtrl, decoration: const InputDecoration(labelText: 'Judul Pengumuman *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: kategori,
                          decoration: const InputDecoration(labelText: 'Kategori'),
                          items: const [
                            DropdownMenuItem(value: 'Ketua OSIS', child: Text('Ketua OSIS')),
                            DropdownMenuItem(value: 'Pembina OSIS', child: Text('Pembina OSIS')),
                            DropdownMenuItem(value: 'Rapat', child: Text('Informasi Rapat')),
                            DropdownMenuItem(value: 'Kegiatan', child: Text('Informasi Kegiatan')),
                            DropdownMenuItem(value: 'Tugas Bidang', child: Text('Tugas Setiap Bidang')),
                            DropdownMenuItem(value: 'Umum', child: Text('Pengumuman Umum')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlg(() => kategori = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: target,
                          decoration: const InputDecoration(labelText: 'Target Sasaran'),
                          items: const [
                            DropdownMenuItem(value: 'Semua', child: Text('Semua Pengurus')),
                            DropdownMenuItem(value: 'BPH', child: Text('BPH (Inti)')),
                            DropdownMenuItem(value: 'SEKBID1', child: Text('Sekbid 1')),
                            DropdownMenuItem(value: 'SEKBID2', child: Text('Sekbid 2')),
                            DropdownMenuItem(value: 'SEKBID3', child: Text('Sekbid 3')),
                            DropdownMenuItem(value: 'SEKBID4', child: Text('Sekbid 4')),
                            DropdownMenuItem(value: 'SEKBID5', child: Text('Sekbid 5')),
                            DropdownMenuItem(value: 'SEKBID6', child: Text('Sekbid 6')),
                            DropdownMenuItem(value: 'SEKBID7', child: Text('Sekbid 7')),
                            DropdownMenuItem(value: 'SEKBID8', child: Text('Sekbid 8')),
                            DropdownMenuItem(value: 'SEKBID9', child: Text('Sekbid 9')),
                            DropdownMenuItem(value: 'SEKBID10', child: Text('Sekbid 10')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlg(() => target = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: isiCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Isi Pesan Pengumuman *'),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Sematkan di Atas (Pin Paling Atas)', style: TextStyle(fontSize: 13)),
                    value: isPinned,
                    onChanged: (v) => setDlg(() => isPinned = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final judul = judulCtrl.text.trim();
                final isi = isiCtrl.text.trim();
                if (judul.isEmpty || isi.isEmpty) return;

                final currentName = await AuthService.getCurrentDisplayName();
                final currentRole = AuthService.getRole(widget.username);

                final item = PengumumanOsis(
                  id: existing?.id ?? 'pgm-${DateTime.now().millisecondsSinceEpoch}',
                  judul: judul,
                  isi: isi,
                  pengirim: currentName.isNotEmpty ? currentName : AuthService.getDisplayName(widget.username),
                  rolePengirim: currentRole,
                  kategori: kategori,
                  targetBidang: target,
                  tanggal: DateTime.now(),
                  isPinned: isPinned,
                );

                await DataService.savePengumuman(item);

                // Kirim notifikasi sistem otomatis
                await NotificationService.notifyUpdate(
                  title: '📢 $judul',
                  message: isi.length > 80 ? '${isi.substring(0, 80)}...' : isi,
                  category: 'system',
                  actor: widget.username,
                );

                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Kirim Pengumuman'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePengumuman(PengumumanOsis p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengumuman?'),
        content: Text('Yakin ingin menghapus pengumuman "${p.judul}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await DataService.deletePengumuman(p.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: DOKUMENTASI KEGIATAN
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDokumentasiTab(ThemeData theme, bool isDark, Color primary) {
    final filtered = _filteredDokumentasi;

    return Column(
      children: [
        // Filter & Add Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Kategori: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ...['Semua', 'Rapat', 'Perlombaan', 'Kegiatan Sosial', 'Kegiatan Sekolah', 'Lainnya'].map((cat) {
                        final isSelected = _filterDokumentasi == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: primary,
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: BorderSide(
                              color: isSelected
                                  ? primary
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            onSelected: (_) => setState(() => _filterDokumentasi = cat),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Grid View
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('Belum ada album dokumentasi untuk kategori ini.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 270,
                  ),
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    return _buildDokumentasiCard(item, isDark, primary);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDokumentasiCard(DokumentasiKegiatan item, bool isDark, Color primary) {
    final hasPhoto = item.fotoUrls.isNotEmpty;
    final photoUrl = hasPhoto ? item.fotoUrls.first : '';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image / Video Banner
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 130,
              width: double.infinity,
              child: hasPhoto && photoUrl.startsWith('http')
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.blueGrey.withAlpha(40),
                        child: const Center(child: Icon(Icons.photo_rounded, size: 36, color: Colors.grey)),
                      ),
                    )
                  : Container(
                      color: primary.withAlpha(isDark ? 40 : 25),
                      child: Center(
                        child: Icon(
                          item.videoUrl.isNotEmpty ? Icons.play_circle_fill_rounded : Icons.photo_camera_rounded,
                          size: 42,
                          color: primary,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.kategori,
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('d MMM yyyy').format(item.tanggal),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.judul,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  item.deskripsi,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (item.videoUrl.isNotEmpty)
                      InkWell(
                        onTap: () => launchUrl(Uri.parse(item.videoUrl), mode: LaunchMode.externalApplication),
                        child: const Row(
                          children: [
                            Icon(Icons.video_collection_rounded, size: 14, color: Colors.redAccent),
                            SizedBox(width: 4),
                            Text('Tonton Video', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_canManageDokumentasi)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        onPressed: () => _confirmDeleteDokumentasi(item),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDokumentasiDialog({DokumentasiKegiatan? existing}) {
    final judulCtrl = TextEditingController(text: existing?.judul ?? '');
    final deskCtrl = TextEditingController(text: existing?.deskripsi ?? '');
    final fotoCtrl = TextEditingController(text: existing?.fotoUrls.join(', ') ?? '');
    final videoCtrl = TextEditingController(text: existing?.videoUrl ?? '');
    final pjCtrl = TextEditingController(text: existing?.penanggungJawab ?? '');
    String kategori = existing?.kategori ?? 'Kegiatan Sekolah';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Tambah Dokumentasi Kegiatan' : 'Edit Dokumentasi', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: judulCtrl, decoration: const InputDecoration(labelText: 'Nama / Judul Kegiatan *')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: kategori,
                  decoration: const InputDecoration(labelText: 'Kategori Kegiatan'),
                  items: const [
                    DropdownMenuItem(value: 'Rapat', child: Text('Dokumentasi Rapat')),
                    DropdownMenuItem(value: 'Perlombaan', child: Text('Dokumentasi Perlombaan')),
                    DropdownMenuItem(value: 'Kegiatan Sosial', child: Text('Dokumentasi Kegiatan Sosial')),
                    DropdownMenuItem(value: 'Kegiatan Sekolah', child: Text('Dokumentasi Kegiatan Sekolah')),
                    DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                  ],
                  onChanged: (v) {
                    if (v != null) kategori = v;
                  },
                ),
                const SizedBox(height: 8),
                TextField(controller: fotoCtrl, decoration: const InputDecoration(labelText: 'Link URL Foto (bisa pisahkan dengan koma)')),
                const SizedBox(height: 8),
                TextField(controller: videoCtrl, decoration: const InputDecoration(labelText: 'Link Video Kegiatan (YouTube / Google Drive)')),
                const SizedBox(height: 8),
                TextField(controller: pjCtrl, decoration: const InputDecoration(labelText: 'Penanggung Jawab / Sekbid')),
                const SizedBox(height: 8),
                TextField(controller: deskCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi / Uraian Dokumentasi')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final judul = judulCtrl.text.trim();
              if (judul.isEmpty) return;

              final rawFotos = fotoCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

              final item = DokumentasiKegiatan(
                id: existing?.id ?? 'dok-${DateTime.now().millisecondsSinceEpoch}',
                judul: judul,
                kategori: kategori,
                tanggal: DateTime.now(),
                deskripsi: deskCtrl.text.trim(),
                fotoUrls: rawFotos,
                videoUrl: videoCtrl.text.trim(),
                penanggungJawab: pjCtrl.text.trim(),
              );

              await DataService.saveDokumentasi(item);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDokumentasi(DokumentasiKegiatan item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Dokumentasi?'),
        content: Text('Yakin ingin menghapus dokumentasi "${item.judul}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await DataService.deleteDokumentasi(item.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
