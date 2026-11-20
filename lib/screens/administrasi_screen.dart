import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import 'arsip_screen.dart';

class AdministrasiScreen extends StatefulWidget {
  final String username;
  final int initialSubTab;

  const AdministrasiScreen({
    super.key,
    required this.username,
    this.initialSubTab = 0,
  });

  @override
  State<AdministrasiScreen> createState() => AdministrasiScreenState();
}

class AdministrasiScreenState extends State<AdministrasiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<InventarisOsis> _inventarisList = [];
  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  String _searchInventaris = '';
  String _filterKondisi = 'Semua';
  String _filterKategori = 'Semua';
  final TextEditingController _searchCtrl = TextEditingController();

  final GlobalKey<ArsipScreenState> _arsipKey = GlobalKey<ArsipScreenState>();
  bool get canGoUp => _tabCtrl.index == 0 && _arsipKey.currentState?.canGoUp == true;
  void goUp() => _arsipKey.currentState?.goUp();

  bool get _canManage => AuthService.canManageAdministrasi(widget.username);

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

    _loadInventaris();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'inventaris_osis' || table == 'all') {
        if (mounted) _loadInventaris(silent: true);
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

  Future<void> _loadInventaris({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final list = await DataService.getInventaris();
      if (!mounted) return;
      setState(() {
        _inventarisList = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<InventarisOsis> get _filteredInventaris {
    return _inventarisList.where((item) {
      final matchesSearch = _searchInventaris.isEmpty ||
          item.namaBarang.toLowerCase().contains(_searchInventaris.toLowerCase()) ||
          item.kodeBarang.toLowerCase().contains(_searchInventaris.toLowerCase()) ||
          item.lokasiSimpan.toLowerCase().contains(_searchInventaris.toLowerCase()) ||
          item.peminjam.toLowerCase().contains(_searchInventaris.toLowerCase());

      final matchesKondisi = _filterKondisi == 'Semua' ||
          item.kondisi.toLowerCase() == _filterKondisi.toLowerCase();

      final matchesKategori = _filterKategori == 'Semua' ||
          item.kategori.toLowerCase() == _filterKategori.toLowerCase();

      return matchesSearch && matchesKondisi && matchesKategori;
    }).toList();
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
              Tab(icon: Icon(Icons.folder_shared_rounded, size: 18), text: 'Surat & Arsip Dokumen'),
              Tab(icon: Icon(Icons.inventory_2_rounded, size: 18), text: 'Daftar Inventaris OSIS'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          ArsipScreen(key: _arsipKey, username: widget.username),
          _buildInventarisTab(theme, isDark, primary),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: INVENTARIS OSIS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildInventarisTab(ThemeData theme, bool isDark, Color primary) {
    final filtered = _filteredInventaris;

    return Column(
      children: [
        // Controls Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Cari nama barang, kode, lokasi, peminjam...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchInventaris.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchInventaris = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (v) => setState(() => _searchInventaris = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_canManage)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text('Catat Barang'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showInventarisDialog(),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                    tooltip: 'Cetak Inventaris (PDF)',
                    onPressed: () => PdfService.cetakDaftarInventaris(filtered),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Kondisi: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ...['Semua', 'Baik', 'Rusak Ringan', 'Rusak Berat'].map((k) {
                      final isSelected = _filterKondisi == k;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(k, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _filterKondisi = k),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    const Text('Kategori: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ...['Semua', 'Elektronik', 'ATK & Kantor', 'Perlengkapan Acara', 'Olahraga & Seni', 'Lainnya'].map((cat) {
                      final isSelected = _filterKategori == cat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _filterKategori = cat),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Count Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total ${filtered.length} Jenis Barang',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              Text(
                'Kondisi Baik: ${_inventarisList.where((i) => i.kondisi == 'Baik').length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: _loading && _inventarisList.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            _searchInventaris.isNotEmpty
                                ? 'Tidak ada barang dengan kata kunci "$_searchInventaris"'
                                : 'Belum ada data barang inventaris OSIS.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        return _buildInventarisCard(item, isDark, primary);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildInventarisCard(InventarisOsis item, bool isDark, Color primary) {
    Color kondisiColor = Colors.green;
    if (item.kondisi.toLowerCase().contains('ringan')) kondisiColor = Colors.orange;
    if (item.kondisi.toLowerCase().contains('berat')) kondisiColor = Colors.red;

    final isDipinjam = item.statusPeminjaman.toLowerCase().contains('pinjam');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withAlpha(isDark ? 35 : 20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.kategori.toLowerCase().contains('elektronik')
                  ? Icons.electrical_services_rounded
                  : Icons.inventory_2_rounded,
              color: primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.namaBarang,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: kondisiColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kondisiColor.withAlpha(120), width: 0.8),
                      ),
                      child: Text(
                        item.kondisi,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kondisiColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (item.kodeBarang.isNotEmpty) ...[
                      Text(
                        item.kodeBarang,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                    ],
                    Text(
                      '${item.kategori}  |  Jumlah: ${item.jumlah} unit',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Lokasi: ${item.lokasiSimpan}${isDipinjam ? ' (Dipinjam: ${item.peminjam})' : ''}',
                  style: TextStyle(fontSize: 11, color: isDipinjam ? Colors.orange : (isDark ? Colors.white60 : Colors.black54)),
                ),
                if (item.keterangan.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.keterangan,
                      style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          if (_canManage) ...[
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
              onSelected: (val) {
                if (val == 'edit') {
                  _showInventarisDialog(existing: item);
                } else if (val == 'pinjam') {
                  _showPinjamDialog(item);
                } else if (val == 'delete') {
                  _confirmDeleteInventaris(item);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'pinjam',
                  child: Row(
                    children: [
                      Icon(isDipinjam ? Icons.keyboard_return_rounded : Icons.assignment_return_rounded, size: 18, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(isDipinjam ? 'Kembalikan Barang' : 'Pinjam Barang'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text('Edit Detail'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Hapus Barang'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showInventarisDialog({InventarisOsis? existing}) {
    final namaCtrl = TextEditingController(text: existing?.namaBarang ?? '');
    final kodeCtrl = TextEditingController(text: existing?.kodeBarang ?? '');
    final jmlCtrl = TextEditingController(text: '${existing?.jumlah ?? 1}');
    final lokasiCtrl = TextEditingController(text: existing?.lokasiSimpan ?? 'Ruang OSIS');
    final ketCtrl = TextEditingController(text: existing?.keterangan ?? '');
    String kategori = existing?.kategori ?? 'Perlengkapan Acara';
    String kondisi = existing?.kondisi ?? 'Baik';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Catat Barang Baru' : 'Edit Inventaris', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Barang *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: kodeCtrl, decoration: const InputDecoration(labelText: 'Kode Barang (e.g. INV-ELK-001)'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: jmlCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Unit'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: kategori,
                          decoration: const InputDecoration(labelText: 'Kategori'),
                          items: const [
                            DropdownMenuItem(value: 'Elektronik', child: Text('Elektronik')),
                            DropdownMenuItem(value: 'ATK & Kantor', child: Text('ATK & Kantor')),
                            DropdownMenuItem(value: 'Perlengkapan Acara', child: Text('Perlengkapan Acara')),
                            DropdownMenuItem(value: 'Olahraga & Seni', child: Text('Olahraga & Seni')),
                            DropdownMenuItem(value: 'Lainnya', child: Text('Lainnya')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlg(() => kategori = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: kondisi,
                          decoration: const InputDecoration(labelText: 'Kondisi'),
                          items: const [
                            DropdownMenuItem(value: 'Baik', child: Text('Baik')),
                            DropdownMenuItem(value: 'Rusak Ringan', child: Text('Rusak Ringan')),
                            DropdownMenuItem(value: 'Rusak Berat', child: Text('Rusak Berat')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlg(() => kondisi = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: lokasiCtrl, decoration: const InputDecoration(labelText: 'Lokasi Penyimpanan')),
                  const SizedBox(height: 8),
                  TextField(controller: ketCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Keterangan Tambahan')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final nama = namaCtrl.text.trim();
                if (nama.isEmpty) return;

                final item = InventarisOsis(
                  id: existing?.id ?? 'inv-${DateTime.now().millisecondsSinceEpoch}',
                  namaBarang: nama,
                  kodeBarang: kodeCtrl.text.trim(),
                  jumlah: int.tryParse(jmlCtrl.text.trim()) ?? 1,
                  kategori: kategori,
                  kondisi: kondisi,
                  lokasiSimpan: lokasiCtrl.text.trim().isNotEmpty ? lokasiCtrl.text.trim() : 'Ruang OSIS',
                  keterangan: ketCtrl.text.trim(),
                  statusPeminjaman: existing?.statusPeminjaman ?? 'Tersedia',
                  peminjam: existing?.peminjam ?? '',
                );

                await DataService.saveInventaris(item);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPinjamDialog(InventarisOsis item) {
    final isDipinjam = item.statusPeminjaman.toLowerCase().contains('pinjam');
    final peminjamCtrl = TextEditingController(text: item.peminjam);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isDipinjam ? 'Kembalikan Barang' : 'Catat Peminjaman Barang'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barang: ${item.namaBarang}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (isDipinjam)
              Text('Barang saat ini dipinjam oleh: ${item.peminjam}. Tandai sebagai sudah dikembalikan ke lokasi ${item.lokasiSimpan}?')
            else
              TextField(
                controller: peminjamCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Peminjam / Sekbid / Acara *',
                  hintText: 'Contoh: Sekbid 7 (Acara Futsal)',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (isDipinjam) {
                item.statusPeminjaman = 'Tersedia';
                item.peminjam = '';
              } else {
                final p = peminjamCtrl.text.trim();
                if (p.isEmpty) return;
                item.statusPeminjaman = 'Dipinjam';
                item.peminjam = p;
              }
              await DataService.saveInventaris(item);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(isDipinjam ? 'Sudah Kembali' : 'Simpan Peminjaman'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteInventaris(InventarisOsis item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Barang Inventaris?'),
        content: Text('Yakin ingin menghapus ${item.namaBarang} dari daftar inventaris?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await DataService.deleteInventaris(item.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
