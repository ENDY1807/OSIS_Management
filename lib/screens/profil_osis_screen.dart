import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/pdf_service.dart';
import '../services/app_settings_service.dart';

class ProfilOsisScreen extends StatefulWidget {
  final String username;
  final int initialSubTab;

  const ProfilOsisScreen({
    super.key,
    required this.username,
    this.initialSubTab = 0,
  });

  @override
  State<ProfilOsisScreen> createState() => _ProfilOsisScreenState();
}

class _ProfilOsisScreenState extends State<ProfilOsisScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  ProfilOsis _profil = ProfilOsis();
  List<AnggotaOsis> _anggotaList = [];
  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  String _searchQuery = '';
  String _filterBidang = 'Semua';
  String _filterStatus = 'Semua';
  final TextEditingController _searchCtrl = TextEditingController();

  bool get _canManage => AuthService.canManageOrganisasi(widget.username);

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
      if (table == 'profil_osis' || table == 'anggota_osis' || table == 'all') {
        if (mounted) _loadData(silent: true);
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
      final p = await DataService.getProfilOsis();
      final ang = await DataService.getAnggotaOsis();
      if (!mounted) return;
      setState(() {
        _profil = p;
        _anggotaList = ang;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AnggotaOsis> get _filteredAnggota {
    return _anggotaList.where((a) {
      final matchesSearch = _searchQuery.isEmpty ||
          a.nama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.jabatan.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.kelas.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.jurusan.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.nis.contains(_searchQuery) ||
          a.nisn.contains(_searchQuery);

      final matchesBidang = _filterBidang == 'Semua' ||
          a.bidang.toLowerCase() == _filterBidang.toLowerCase() ||
          a.jabatan.toLowerCase().contains(_filterBidang.toLowerCase());

      final matchesStatus = _filterStatus == 'Semua' ||
          a.statusKeaktifan.toLowerCase() == _filterStatus.toLowerCase();

      return matchesSearch && matchesBidang && matchesStatus;
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
              Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: '1. Profil Organisasi'),
              Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: '2. Data Pengurus OSIS'),
            ],
          ),
        ),
      ),
      body: _loading && _anggotaList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildProfilOrganisasiTab(theme, isDark, primary),
                _buildDataPengurusTab(theme, isDark, primary),
              ],
            ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: PROFIL ORGANISASI
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildProfilOrganisasiTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Logos & Title
          _buildProfilHeaderCard(theme, isDark, primary),
          const SizedBox(height: 16),

          // Visi & Misi Card
          _buildVisiMisiCard(theme, isDark, primary),
          const SizedBox(height: 16),

          // Struktur Organisasi Hierarki Card
          _buildStrukturOrganisasiCard(theme, isDark, primary),
          const SizedBox(height: 16),

          // AD/ART & GBHO Section
          _buildLegalDocumentsCard(theme, isDark, primary),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildProfilHeaderCard(ThemeData theme, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSettingsService.buildLogoWidget(width: 64, height: 64, fit: BoxFit.contain),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profil.namaOrganisasi,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _profil.namaSekolah,
                      style: TextStyle(fontSize: 13, color: primary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withAlpha(120), width: 0.8),
                      ),
                      child: Text(
                        'Masa Bakti: ${_profil.masaBakti}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                      ),
                    ),
                  ],
                ),
              ),
              if (_canManage)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
                  tooltip: 'Edit Profil Organisasi',
                  onPressed: _showEditProfilDialog,
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            _profil.deskripsi,
            style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF334155), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildVisiMisiCard(ThemeData theme, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.blueAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Visi & Misi OSIS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Visi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primary.withAlpha(isDark ? 25 : 15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VISI:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  _profil.visi,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Misi
          const Text(
            'MISI ORGANISASI:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          ..._profil.misi.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final text = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: primary.withAlpha(isDark ? 40 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$idx',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : const Color(0xFF334155), height: 1.3),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStrukturOrganisasiCard(ThemeData theme, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_rounded, color: Colors.purpleAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Struktur Organisasi OSIS',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                'Masa ${_profil.masaBakti}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pembina & Kepala Sekolah
          Center(
            child: _buildOrgCard('Pembina OSIS', _profil.namaPembina, Colors.purple, Icons.school_rounded, isDark),
          ),
          const Center(child: Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.grey)),

          // Ketua OSIS
          Center(
            child: _buildOrgCard('Ketua OSIS', _profil.namaKetua, Colors.indigo, Icons.stars_rounded, isDark),
          ),
          const Center(child: Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.grey)),

          // Wakil Ketua OSIS
          Center(
            child: _buildOrgCard('Wakil Ketua OSIS', _profil.namaWakil, Colors.blue, Icons.star_border_rounded, isDark),
          ),
          const Center(child: Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.grey)),

          // Sekretaris & Bendahara
          Row(
            children: [
              Expanded(child: _buildOrgCard('Sekretaris', _profil.namaSekretaris, Colors.teal, Icons.description_rounded, isDark)),
              const SizedBox(width: 12),
              Expanded(child: _buildOrgCard('Bendahara', _profil.namaBendahara, Colors.green, Icons.account_balance_wallet_rounded, isDark)),
            ],
          ),
          const SizedBox(height: 16),

          // Sekbid 1 - 10 Grid
          const Text(
            'KOORDINATOR SEKSI BIDANG (SEKBID 1 - 10):',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _buildSekbidGrid(isDark),
        ],
      ),
    );
  }

  Widget _buildOrgCard(String title, String name, Color color, IconData icon, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withAlpha(40), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSekbidGrid(bool isDark) {
    final sekbids = DataService.defaultSekbidItems();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sekbids.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 68,
      ),
      itemBuilder: (context, i) {
        final s = sekbids[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                s.name,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              const SizedBox(height: 2),
              Text(
                s.deskripsi,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegalDocumentsCard(ThemeData theme, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                'Landasan Hukum & Pedoman Organisasi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.gavel_rounded, size: 18),
                  label: const Text('Baca AD / ART OSIS'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showDocumentDialog('AD / ART OSIS', _profil.adArt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.alt_route_rounded, size: 18),
                  label: const Text('Baca GBHO OSIS'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showDocumentDialog('GBHO (Garis-Garis Besar Haluan Organisasi)', _profil.gbho),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDocumentDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfilDialog() {
    final visiCtrl = TextEditingController(text: _profil.visi);
    final masaCtrl = TextEditingController(text: _profil.masaBakti);
    final ketuaCtrl = TextEditingController(text: _profil.namaKetua);
    final wakilCtrl = TextEditingController(text: _profil.namaWakil);
    final pembinaCtrl = TextEditingController(text: _profil.namaPembina);
    final sekreCtrl = TextEditingController(text: _profil.namaSekretaris);
    final bendaCtrl = TextEditingController(text: _profil.namaBendahara);
    final deskCtrl = TextEditingController(text: _profil.deskripsi);
    final adArtCtrl = TextEditingController(text: _profil.adArt);
    final gbhoCtrl = TextEditingController(text: _profil.gbho);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Profil Organisasi OSIS', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: masaCtrl, decoration: const InputDecoration(labelText: 'Masa Bakti (e.g. 2026 / 2027)')),
                const SizedBox(height: 8),
                TextField(controller: pembinaCtrl, decoration: const InputDecoration(labelText: 'Nama Pembina OSIS')),
                const SizedBox(height: 8),
                TextField(controller: ketuaCtrl, decoration: const InputDecoration(labelText: 'Nama Ketua OSIS')),
                const SizedBox(height: 8),
                TextField(controller: wakilCtrl, decoration: const InputDecoration(labelText: 'Nama Wakil Ketua OSIS')),
                const SizedBox(height: 8),
                TextField(controller: sekreCtrl, decoration: const InputDecoration(labelText: 'Nama Sekretaris OSIS')),
                const SizedBox(height: 8),
                TextField(controller: bendaCtrl, decoration: const InputDecoration(labelText: 'Nama Bendahara OSIS')),
                const SizedBox(height: 8),
                TextField(controller: visiCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Visi OSIS')),
                const SizedBox(height: 8),
                TextField(controller: deskCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Deskripsi Singkat')),
                const SizedBox(height: 8),
                TextField(controller: adArtCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Teks AD / ART')),
                const SizedBox(height: 8),
                TextField(controller: gbhoCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Teks GBHO')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _profil.masaBakti = masaCtrl.text.trim();
                _profil.namaPembina = pembinaCtrl.text.trim();
                _profil.namaKetua = ketuaCtrl.text.trim();
                _profil.namaWakil = wakilCtrl.text.trim();
                _profil.namaSekretaris = sekreCtrl.text.trim();
                _profil.namaBendahara = bendaCtrl.text.trim();
                _profil.visi = visiCtrl.text.trim();
                _profil.deskripsi = deskCtrl.text.trim();
                _profil.adArt = adArtCtrl.text.trim();
                _profil.gbho = gbhoCtrl.text.trim();
                _profil.updatedAt = DateTime.now();
              });
              await DataService.saveProfilOsis(_profil);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: DATA PENGURUS OSIS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDataPengurusTab(ThemeData theme, bool isDark, Color primary) {
    final filtered = _filteredAnggota;

    return Column(
      children: [
        // Search & Filter Bar
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
                        hintText: 'Cari nama, jabatan, NIS/NISN, kelas, jurusan...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_canManage)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Tambah Pengurus'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showAnggotaDialog(),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                    tooltip: 'Cetak Daftar Pengurus (PDF)',
                    onPressed: () => PdfService.cetakDataPengurus(filtered),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const Text('Bidang: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ...['Semua', 'BPH', 'Sekbid 1', 'Sekbid 2', 'Sekbid 3', 'Sekbid 4', 'Sekbid 5', 'Sekbid 6', 'Sekbid 7', 'Sekbid 8', 'Sekbid 9', 'Sekbid 10'].map((b) {
                      final isSelected = _filterBidang.toLowerCase() == b.toLowerCase();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(b, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _filterBidang = b),
                        ),
                      );
                    }),
                    const SizedBox(width: 8),
                    const Text('Status: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ...['Semua', 'Aktif', 'Non-aktif', 'Alumni'].map((st) {
                      final isSelected = _filterStatus == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(st, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _filterStatus = st),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Member Count Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Menampilkan ${filtered.length} dari ${_anggotaList.length} Pengurus',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
              Text(
                'Aktif: ${_anggotaList.where((a) => a.aktif).length}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
        ),

        // Member List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Tidak ada pengurus dengan kata kunci "$_searchQuery"'
                            : 'Belum ada data pengurus OSIS.',
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
                    final a = filtered[i];
                    return _buildAnggotaCard(a, isDark, primary);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAnggotaCard(AnggotaOsis a, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: primary.withAlpha(isDark ? 50 : 30),
            child: Text(
              a.nama.isNotEmpty ? a.nama[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.nama,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusChip(a.statusKeaktifan),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${a.jabatan} • ${a.bidang}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kelas: ${a.kelas} ${a.jurusan}  |  NIS: ${a.nis.isNotEmpty ? a.nis : '-'}',
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
                if (a.alamat.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Alamat: ${a.alamat}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (a.noHp.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.green, size: 20),
                  tooltip: 'Chat WhatsApp (${a.noHp})',
                  onPressed: () => _openWhatsApp(a.noHp),
                ),
              if (_canManage) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 19, color: Colors.blueGrey),
                  tooltip: 'Edit Data',
                  onPressed: () => _showAnggotaDialog(existing: a),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.redAccent),
                  tooltip: 'Hapus',
                  onPressed: () => _confirmDeleteAnggota(a),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.green;
    if (status.toLowerCase().contains('non')) color = Colors.red;
    if (status.toLowerCase().contains('alumni')) color = Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(100), width: 0.8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Future<void> _openWhatsApp(String noHp) async {
    String clean = noHp.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = '62${clean.substring(1)}';
    final url = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showAnggotaDialog({AnggotaOsis? existing}) {
    final namaCtrl = TextEditingController(text: existing?.nama ?? '');
    final jabatanCtrl = TextEditingController(text: existing?.jabatan ?? 'Anggota OSIS');
    final bidangCtrl = TextEditingController(text: existing?.bidang ?? 'BPH');
    final kelasCtrl = TextEditingController(text: existing?.kelas ?? '');
    final jurusanCtrl = TextEditingController(text: existing?.jurusan ?? '');
    final nisCtrl = TextEditingController(text: existing?.nis ?? '');
    final nisnCtrl = TextEditingController(text: existing?.nisn ?? '');
    final noHpCtrl = TextEditingController(text: existing?.noHp ?? '');
    final alamatCtrl = TextEditingController(text: existing?.alamat ?? '');
    String status = existing?.statusKeaktifan ?? 'Aktif';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Tambah Pengurus OSIS' : 'Edit Data Pengurus', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: namaCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: jabatanCtrl, decoration: const InputDecoration(labelText: 'Jabatan OSIS *'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: bidangCtrl, decoration: const InputDecoration(labelText: 'Bidang / Sekbid'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: kelasCtrl, decoration: const InputDecoration(labelText: 'Kelas (e.g. X, XI, XII)'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: jurusanCtrl, decoration: const InputDecoration(labelText: 'Jurusan (e.g. RPL, TKJ)'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: nisCtrl, decoration: const InputDecoration(labelText: 'NIS'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: nisnCtrl, decoration: const InputDecoration(labelText: 'NISN'))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: noHpCtrl, decoration: const InputDecoration(labelText: 'Nomor WhatsApp (e.g. 08123456789)')),
                  const SizedBox(height: 8),
                  TextField(controller: alamatCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Alamat Domisili')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status Keaktifan'),
                    items: const [
                      DropdownMenuItem(value: 'Aktif', child: Text('Aktif')),
                      DropdownMenuItem(value: 'Non-aktif', child: Text('Non-aktif')),
                      DropdownMenuItem(value: 'Alumni', child: Text('Alumni')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDlg(() => status = v);
                    },
                  ),
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

                final item = AnggotaOsis(
                  id: existing?.id ?? 'ang-${DateTime.now().millisecondsSinceEpoch}',
                  nama: nama,
                  jabatan: jabatanCtrl.text.trim().isNotEmpty ? jabatanCtrl.text.trim() : 'Anggota OSIS',
                  bidang: bidangCtrl.text.trim().isNotEmpty ? bidangCtrl.text.trim() : 'BPH',
                  kelas: kelasCtrl.text.trim(),
                  jurusan: jurusanCtrl.text.trim(),
                  nis: nisCtrl.text.trim(),
                  nisn: nisnCtrl.text.trim(),
                  noHp: noHpCtrl.text.trim(),
                  alamat: alamatCtrl.text.trim(),
                  statusKeaktifan: status,
                  aktif: status == 'Aktif',
                );

                if (existing != null) {
                  await DataService.updateAnggotaOsis(item);
                } else {
                  await DataService.addAnggotaOsis(item);
                }
                if (mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAnggota(AnggotaOsis a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pengurus?'),
        content: Text('Yakin ingin menghapus ${a.nama} dari daftar pengurus OSIS?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await DataService.deleteAnggotaOsis(a.id);
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
