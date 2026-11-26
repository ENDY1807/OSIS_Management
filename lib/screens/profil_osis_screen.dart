import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
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
              Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: 'Profil Organisasi'),
              Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Data Pengurus OSIS'),
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
      floatingActionButton: _tabCtrl.index == 1 && _canManage
          ? FloatingActionButton(
              tooltip: 'Tambah Pengurus OSIS',
              backgroundColor: primary,
              foregroundColor: ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              shape: const CircleBorder(),
              onPressed: () => _showAnggotaDialog(),
              child: const Icon(Icons.person_add_rounded, size: 26),
            )
          : null,
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

          // AD/ART Card Mandiri
          _buildAdArtCard(theme, isDark, primary),
          const SizedBox(height: 16),

          // GBHO Card Mandiri
          _buildGbhoCard(theme, isDark, primary),
          const SizedBox(height: 24),
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
        border: Border.all(color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
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
                  tooltip: 'Edit Identitas Organisasi',
                  onPressed: _showEditIdentitasDialog,
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
    Widget buildVisiSection() {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: primary.withAlpha(isDark ? 35 : 18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primary.withAlpha(isDark ? 100 : 60),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 8),
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
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: primary.withAlpha(160),
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  'VISI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: primary,
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _profil.visi,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                height: 1.55,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildMisiSection() {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 8),
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
                const SizedBox(width: 10),
                Text(
                  'MISI',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: primary,
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: primary.withAlpha(160),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._profil.misi.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final text = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$idx',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                          height: 1.4,
                        ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, color: primary, size: 22),
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
                  if (_canManage)
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent),
                      tooltip: 'Edit Visi & Misi',
                      onPressed: _showEditVisiMisiDialog,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildVisiSection()),
                    const SizedBox(width: 14),
                    Expanded(child: buildMisiSection()),
                  ],
                )
              else
                Column(
                  children: [
                    buildVisiSection(),
                    const SizedBox(height: 14),
                    buildMisiSection(),
                  ],
                ),
            ],
          ),
        );
      },
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
              Row(
                children: [
                  Text(
                    'Masa ${_profil.masaBakti}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (_canManage) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Colors.purpleAccent),
                      tooltip: 'Sesuaikan Pejabat Organisasi',
                      onPressed: _showEditStrukturOrganisasiDialog,
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Kepala Sekolah
          Center(
            child: _buildOrgCard(
              'Kepala Sekolah',
              _profil.namaKepsek.isEmpty ? '- Belum Diisi -' : _profil.namaKepsek,
              Colors.deepPurple,
              Icons.admin_panel_settings_rounded,
              isDark,
            ),
          ),
          const Center(child: Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.grey)),

          // 2. Pembina
          Center(
            child: _buildOrgCard(
              'Pembina',
              _profil.namaPembina.isEmpty ? '- Belum Diisi -' : _profil.namaPembina,
              Colors.purple,
              Icons.supervisor_account_rounded,
              isDark,
            ),
          ),
          const Center(child: Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.grey)),

          // 3. Ketua OSIS
          Center(
            child: _buildOrgCard(
              'Ketua OSIS',
              _profil.namaKetua.isEmpty ? '- Belum Diisi -' : _profil.namaKetua,
              Colors.indigo,
              Icons.workspace_premium_rounded,
              isDark,
            ),
          ),
          const Center(child: Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.grey)),

          // 4. Wakil Ketua OSIS 1 & Wakil Ketua OSIS 2
          Row(
            children: [
              Expanded(
                child: _buildOrgCard(
                  'Wakil Ketua OSIS 1',
                  _profil.namaWakil.isEmpty ? '- Belum Diisi -' : _profil.namaWakil,
                  Colors.blue,
                  Icons.military_tech_rounded,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOrgCard(
                  'Wakil Ketua OSIS 2',
                  _profil.namaWakil2.isEmpty ? '- Belum Diisi -' : _profil.namaWakil2,
                  Colors.lightBlue,
                  Icons.shield_rounded,
                  isDark,
                ),
              ),
            ],
          ),
          const Center(child: Icon(Icons.arrow_downward_rounded, size: 18, color: Colors.grey)),

          // 5. Sekretaris 1 & Bendahara 1
          Row(
            children: [
              Expanded(
                child: _buildOrgCard(
                  'Sekretaris 1',
                  _profil.namaSekretaris.isEmpty ? '- Belum Diisi -' : _profil.namaSekretaris,
                  Colors.teal,
                  Icons.history_edu_rounded,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOrgCard(
                  'Bendahara 1',
                  _profil.namaBendahara.isEmpty ? '- Belum Diisi -' : _profil.namaBendahara,
                  Colors.green,
                  Icons.account_balance_wallet_rounded,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 6. Sekretaris 2 & Bendahara 2
          Row(
            children: [
              Expanded(
                child: _buildOrgCard(
                  'Sekretaris 2',
                  _profil.namaSekretaris2.isEmpty ? '- Belum Diisi -' : _profil.namaSekretaris2,
                  Colors.teal.shade700,
                  Icons.rate_review_rounded,
                  isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOrgCard(
                  'Bendahara 2',
                  _profil.namaBendahara2.isEmpty ? '- Belum Diisi -' : _profil.namaBendahara2,
                  Colors.green.shade700,
                  Icons.monetization_on_rounded,
                  isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 7. Sekbid 1 - 10 Grid (Clickable)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SEKSI BIDANG (SEKBID 1 - 10):',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              Text(
                'Ketuk card untuk melihat struktur Sekbid',
                style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSekbidGrid(isDark),
        ],
      ),
    );
  }

  Widget _buildOrgCard(String title, String name, Color color, IconData icon, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12.5,
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
        mainAxisExtent: 82,
      ),
      itemBuilder: (context, i) {
        final s = sekbids[i];
        final sekbidData = _profil.sekbidDetails[s.id] ?? {};
        final ketua = sekbidData['ketua']?.toString() ?? '';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showSekbidDetailDialog(s),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ketua.isNotEmpty ? 'Ketua: $ketua' : s.deskripsi,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSekbidDetailDialog(SekbidItem s) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final details = _profil.sekbidDetails[s.id] ?? {};
    final ketua = details['ketua']?.toString() ?? '';
    final sekretaris = details['sekretaris']?.toString() ?? '';
    final anggotaStr = details['anggota']?.toString() ?? '';

    // Cari juga anggota terdaftar dari daftar AnggotaOsis
    final anggotaListSekbid = _anggotaList.where((a) {
      return a.bidang.toLowerCase().contains(s.name.toLowerCase()) ||
          a.jabatan.toLowerCase().contains(s.name.toLowerCase()) ||
          a.bidang.toLowerCase().replaceAll(' ', '') == s.id.toLowerCase();
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withAlpha(isDark ? 45 : 25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_rounded, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      s.deskripsi,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'STRUKTUR PENGURUS SEKBID',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

                  // Ketua Sekbid
                  _buildSekbidRoleTile(
                    role: 'Ketua Sekbid',
                    name: ketua.isNotEmpty ? ketua : '- Belum Ditentukan -',
                    icon: Icons.star_rounded,
                    color: Colors.indigo,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),

                  // Sekretaris Sekbid
                  _buildSekbidRoleTile(
                    role: 'Sekretaris Sekbid',
                    name: sekretaris.isNotEmpty ? sekretaris : '- Belum Ditentukan -',
                    icon: Icons.edit_note_rounded,
                    color: Colors.teal,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),

                  // Anggota Sekbid
                  _buildSekbidRoleTile(
                    role: 'Anggota Sekbid',
                    name: anggotaStr.isNotEmpty
                        ? anggotaStr
                        : (anggotaListSekbid.isNotEmpty
                            ? anggotaListSekbid.map((a) => a.nama).join(', ')
                            : '- Belum ada anggota terdaftar -'),
                    icon: Icons.groups_rounded,
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (_canManage)
              TextButton.icon(
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Edit Struktur Sekbid'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showEditSekbidDialog(s);
                },
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSekbidRoleTile({
    required String role,
    required String name,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSekbidDialog(SekbidItem s) {
    final details = _profil.sekbidDetails[s.id] ?? {};
    final ketuaCtrl = TextEditingController(text: details['ketua']?.toString() ?? '');
    final sekreCtrl = TextEditingController(text: details['sekretaris']?.toString() ?? '');
    final anggotaCtrl = TextEditingController(text: details['anggota']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Colors.blueAccent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Edit Struktur ${s.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ketuaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ketua Sekbid',
                    prefixIcon: Icon(Icons.star_rounded, color: Colors.indigo),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sekreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sekretaris Sekbid',
                    prefixIcon: Icon(Icons.edit_note_rounded, color: Colors.teal),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: anggotaCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Anggota Sekbid (pisahkan dengan koma)',
                    prefixIcon: Icon(Icons.groups_rounded, color: Colors.blue),
                    border: OutlineInputBorder(),
                    hintText: 'Contoh: Ahmad, Budi, Siti',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _profil.sekbidDetails[s.id] = {
                  'ketua': ketuaCtrl.text.trim(),
                  'sekretaris': sekreCtrl.text.trim(),
                  'anggota': anggotaCtrl.text.trim(),
                };
                _profil.updatedAt = DateTime.now();
              });
              await DataService.saveProfilOsis(_profil);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Struktur ${s.name} berhasil diperbarui')),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── 4. CARD AD / ART MANDIRI ───────────────────────────────────────────────
  Widget _buildAdArtCard(ThemeData theme, bool isDark, Color primary) {
    final hasContent = _profil.adArt.trim().isNotEmpty;
    final snippet = hasContent
        ? _profil.adArt.trim().split('\n').take(3).join(' ')
        : 'Belum ada dokumen AD/ART resmi yang dipasang.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(isDark ? 40 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.gavel_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AD / ART OSIS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'Anggaran Dasar & Anggaran Rumah Tangga',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              if (_canManage)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.amber, size: 22),
                  tooltip: 'Pasang / Edit AD & ART',
                  onPressed: () => _showEditDocumentDialog(
                    title: 'Edit AD / ART OSIS',
                    docType: 'AD/ART',
                    initialContent: _profil.adArt,
                    onSave: (val) async {
                      setState(() {
                        _profil.adArt = val;
                        _profil.updatedAt = DateTime.now();
                      });
                      await DataService.saveProfilOsis(_profil);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              snippet,
              style: TextStyle(
                fontSize: 12,
                fontStyle: hasContent ? FontStyle.normal : FontStyle.italic,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                height: 1.45,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chrome_reader_mode_rounded, size: 17),
                  label: const Text('Baca AD / ART Lengkap'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showDocumentDialog('AD / ART OSIS', _profil.adArt),
                ),
              ),
              if (_canManage) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_document, size: 17),
                  label: const Text('Ubah AD / ART'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showEditDocumentDialog(
                    title: 'Edit AD / ART OSIS',
                    docType: 'AD/ART',
                    initialContent: _profil.adArt,
                    onSave: (val) async {
                      setState(() {
                        _profil.adArt = val;
                        _profil.updatedAt = DateTime.now();
                      });
                      await DataService.saveProfilOsis(_profil);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. CARD GBHO MANDIRI ──────────────────────────────────────────────────
  Widget _buildGbhoCard(ThemeData theme, bool isDark, Color primary) {
    final hasContent = _profil.gbho.trim().isNotEmpty;
    final snippet = hasContent
        ? _profil.gbho.trim().split('\n').take(3).join(' ')
        : 'Belum ada dokumen GBHO resmi yang dipasang.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withAlpha(isDark ? 40 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.alt_route_rounded, color: Colors.cyan, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GBHO OSIS',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'Garis-Garis Besar Haluan Organisasi',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              if (_canManage)
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.cyan, size: 22),
                  tooltip: 'Pasang / Edit GBHO',
                  onPressed: () => _showEditDocumentDialog(
                    title: 'Edit GBHO OSIS',
                    docType: 'GBHO',
                    initialContent: _profil.gbho,
                    onSave: (val) async {
                      setState(() {
                        _profil.gbho = val;
                        _profil.updatedAt = DateTime.now();
                      });
                      await DataService.saveProfilOsis(_profil);
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              snippet,
              style: TextStyle(
                fontSize: 12,
                fontStyle: hasContent ? FontStyle.normal : FontStyle.italic,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
                height: 1.45,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chrome_reader_mode_rounded, size: 17),
                  label: const Text('Baca GBHO Lengkap'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showDocumentDialog('GBHO OSIS', _profil.gbho),
                ),
              ),
              if (_canManage) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.edit_document, size: 17),
                  label: const Text('Ubah GBHO'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _showEditDocumentDialog(
                    title: 'Edit GBHO OSIS',
                    docType: 'GBHO',
                    initialContent: _profil.gbho,
                    onSave: (val) async {
                      setState(() {
                        _profil.gbho = val;
                        _profil.updatedAt = DateTime.now();
                      });
                      await DataService.saveProfilOsis(_profil);
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showDocumentDialog(String title, String content) {
    final hasContent = content.trim().isNotEmpty;
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                title.contains('AD') ? Icons.gavel_rounded : Icons.alt_route_rounded,
                color: title.contains('AD') ? Colors.amber : Colors.cyan,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SizedBox(
            width: 650,
            child: SingleChildScrollView(
              child: hasContent
                  ? SelectableText(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Dokumen ini belum memiliki isi.\nPengurus dapat memasang isi dokumen melalui tombol Ubah Dokumen.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white38 : Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
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

  // ── DIALOG EDIT IDENTITAS ORGANISASI ───────────────────────────────────────
  void _showEditIdentitasDialog() {
    final masaCtrl = TextEditingController(text: _profil.masaBakti);
    final sekolahCtrl = TextEditingController(text: _profil.namaSekolah);
    final orgCtrl = TextEditingController(text: _profil.namaOrganisasi);
    final deskCtrl = TextEditingController(text: _profil.deskripsi);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: Colors.blueAccent, size: 22),
            SizedBox(width: 10),
            Text('Edit Identitas Organisasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: orgCtrl, decoration: const InputDecoration(labelText: 'Nama Organisasi', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: sekolahCtrl, decoration: const InputDecoration(labelText: 'Nama Sekolah', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: masaCtrl, decoration: const InputDecoration(labelText: 'Masa Bakti (Contoh: 2024 / 2025)', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: deskCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi Singkat Organisasi', border: OutlineInputBorder())),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _profil.namaOrganisasi = orgCtrl.text.trim();
                _profil.namaSekolah = sekolahCtrl.text.trim();
                _profil.masaBakti = masaCtrl.text.trim();
                _profil.deskripsi = deskCtrl.text.trim();
                _profil.updatedAt = DateTime.now();
              });
              await DataService.saveProfilOsis(_profil);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── DIALOG EDIT VISI & MISI INTERAKTIF ─────────────────────────────────────
  void _showEditVisiMisiDialog() {
    final visiCtrl = TextEditingController(text: _profil.visi);
    final List<TextEditingController> misiCtrls = _profil.misi.map((m) => TextEditingController(text: m)).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final primary = theme.colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.stars_rounded, color: primary, size: 22),
                  const SizedBox(width: 10),
                  const Text('Sesuaikan Visi & Misi OSIS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 580,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('VISI ORGANISASI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: visiCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan visi OSIS...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('BUTIR-BUTIR MISI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Tambah Butir Misi'),
                            onPressed: () {
                              setModalState(() {
                                misiCtrls.add(TextEditingController());
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (int i = 0; i < misiCtrls.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 10, right: 8),
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                controller: misiCtrls[i],
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'Butir misi ${i + 1}',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Hapus butir ini',
                              onPressed: () {
                                setModalState(() {
                                  misiCtrls.removeAt(i);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  final newMisi = misiCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                  setState(() {
                    _profil.visi = visiCtrl.text.trim();
                    _profil.misi = newMisi;
                    _profil.updatedAt = DateTime.now();
                  });
                  await DataService.saveProfilOsis(_profil);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      );
    },
  );
}

  // ── DIALOG EDIT STRUKTUR ORGANISASI & PEJABAT ──────────────────────────────
  void _showEditStrukturOrganisasiDialog() {
    final kepsekCtrl = TextEditingController(text: _profil.namaKepsek);
    final pembinaCtrl = TextEditingController(text: _profil.namaPembina);
    final ketuaCtrl = TextEditingController(text: _profil.namaKetua);
    final wakil1Ctrl = TextEditingController(text: _profil.namaWakil);
    final wakil2Ctrl = TextEditingController(text: _profil.namaWakil2);
    final sekre1Ctrl = TextEditingController(text: _profil.namaSekretaris);
    final benda1Ctrl = TextEditingController(text: _profil.namaBendahara);
    final sekre2Ctrl = TextEditingController(text: _profil.namaSekretaris2);
    final benda2Ctrl = TextEditingController(text: _profil.namaBendahara2);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_tree_rounded, color: Colors.purpleAccent, size: 22),
            SizedBox(width: 10),
            Text('Sesuaikan Pejabat Organisasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Urutan Hierarki: Kepala Sekolah -> Pembina -> Ketua -> Wakil 1 & 2 -> Sekretaris 1 & Bendahara 1 -> Sekretaris 2 & Bendahara 2.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: kepsekCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kepala Sekolah',
                    prefixIcon: Icon(Icons.admin_panel_settings_rounded, color: Colors.deepPurple),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pembinaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Pembina',
                    prefixIcon: Icon(Icons.supervisor_account_rounded, color: Colors.purple),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ketuaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ketua OSIS',
                    prefixIcon: Icon(Icons.workspace_premium_rounded, color: Colors.indigo),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: wakil1Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Wakil Ketua OSIS 1',
                          prefixIcon: Icon(Icons.military_tech_rounded, color: Colors.blue),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: wakil2Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Wakil Ketua OSIS 2',
                          prefixIcon: Icon(Icons.shield_rounded, color: Colors.lightBlue),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sekre1Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Sekretaris 1',
                          prefixIcon: Icon(Icons.history_edu_rounded, color: Colors.teal),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: benda1Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Bendahara 1',
                          prefixIcon: Icon(Icons.account_balance_wallet_rounded, color: Colors.green),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sekre2Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Sekretaris 2',
                          prefixIcon: Icon(Icons.rate_review_rounded, color: Colors.teal),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: benda2Ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Bendahara 2',
                          prefixIcon: Icon(Icons.monetization_on_rounded, color: Colors.green),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _profil.namaKepsek = kepsekCtrl.text.trim();
                _profil.namaPembina = pembinaCtrl.text.trim();
                _profil.namaKetua = ketuaCtrl.text.trim();
                _profil.namaWakil = wakil1Ctrl.text.trim();
                _profil.namaWakil2 = wakil2Ctrl.text.trim();
                _profil.namaSekretaris = sekre1Ctrl.text.trim();
                _profil.namaBendahara = benda1Ctrl.text.trim();
                _profil.namaSekretaris2 = sekre2Ctrl.text.trim();
                _profil.namaBendahara2 = benda2Ctrl.text.trim();
                _profil.updatedAt = DateTime.now();
              });
              await DataService.saveProfilOsis(_profil);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // Helper untuk membaca file dokumen Word (.docx), PDF, atau teks
  Future<void> _pickAndExtractDocument(TextEditingController textCtrl) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx', 'doc', 'pdf', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = await file.readAsBytes();
      final ext = file.extension?.toLowerCase();

      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Berkas file yang dipilih kosong')),
          );
        }
        return;
      }

      if (ext == 'docx') {
        try {
          final archive = ZipDecoder().decodeBytes(bytes);
          final docXml = archive.findFile('word/document.xml');
          if (docXml != null) {
            final xmlString = utf8.decode(docXml.content as List<int>);
            final regex = RegExp(r'<w:t[^>]*>(.*?)</w:t>');
            final matches = regex.allMatches(xmlString);
            final extracted = matches.map((m) => m.group(1) ?? '').join(' ');
            if (extracted.trim().isNotEmpty) {
              textCtrl.text = extracted;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Berhasil mengekstrak isi dokumen dari ${file.name}')),
                );
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('Error decoding docx: $e');
        }
      } else if (ext == 'txt') {
        final text = utf8.decode(bytes);
        textCtrl.text = text;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhasil memuat isi file ${file.name}')),
          );
        }
        return;
      }

      // Default fallback untuk PDF / DOC
      final summary = '[Dokumen Terlampir: ${file.name}]\n'
          'Ukuran Berkas: ${(file.size / 1024).toStringAsFixed(1)} KB\n'
          'Tanggal Unggah: ${DateFormat('d MMMM yyyy HH:mm', 'id_ID').format(DateTime.now())}\n\n'
          'Berkas ${file.name} telah berhasil diunggah ke sistem OSIS.';
      textCtrl.text = summary;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Berkas ${file.name} berhasil dimuat ke dokumen')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan saat memproses berkas: $e')),
        );
      }
    }
  }

  // ── DIALOG EDIT DOKUMEN AD/ART & GBHO DENGAN TEMPLATE RESMI ───────────────
  void _showEditDocumentDialog({
    required String title,
    required String docType,
    required String initialContent,
    required Function(String) onSave,
  }) {
    final textCtrl = TextEditingController(text: initialContent);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  docType == 'AD/ART' ? Icons.gavel_rounded : Icons.alt_route_rounded,
                  color: docType == 'AD/ART' ? Colors.amber : Colors.cyan,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: const Text('Unggah Berkas (Word/PDF)', style: TextStyle(fontSize: 11)),
              onPressed: () => _pickAndExtractDocument(textCtrl),
            ),
          ],
        ),
        content: SizedBox(
          width: 680,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                docType == 'AD/ART'
                    ? 'Susun Anggaran Dasar & Anggaran Rumah Tangga (AD/ART) OSIS melalui ketikan langsung atau unggah berkas Word/PDF.'
                    : 'Susun Garis-Garis Besar Haluan Organisasi (GBHO) sebagai panduan arah kebijakan melalui ketikan langsung atau unggah berkas Word/PDF.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: textCtrl,
                maxLines: 15,
                style: const TextStyle(fontSize: 12.5, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'Tuliskan teks dokumen resmi di sini...',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Theme.of(ctx).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              await onSave(textCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // Helper untuk impor data pengurus OSIS dari berkas CSV / Excel
  Future<void> _importPengurusFromFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt', 'xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;

      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();

      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File kosong atau tidak berisi data')),
          );
        }
        return;
      }

      int importedCount = 0;
      final newMembers = <AnggotaOsis>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        // Skip header jika baris pertama berisi kata nama/jabatan
        if (i == 0 && (line.toLowerCase().contains('nama') || line.toLowerCase().contains('jabatan'))) {
          continue;
        }

        // Split by delimiter: comma, semicolon, or tab
        List<String> cols;
        if (line.contains(';')) {
          cols = line.split(';');
        } else if (line.contains('\t')) {
          cols = line.split('\t');
        } else {
          cols = line.split(',');
        }

        cols = cols.map((c) => c.trim().replaceAll('"', '')).toList();
        if (cols.isEmpty || cols[0].isEmpty) continue;

        final nama = cols[0];
        final jabatan = cols.length > 1 && cols[1].isNotEmpty ? cols[1] : 'Anggota';
        final kelas = cols.length > 2 ? cols[2] : '';
        final nis = cols.length > 3 ? cols[3] : '';
        final nisn = cols.length > 4 ? cols[4] : '';
        final jurusan = cols.length > 5 ? cols[5] : '';
        final noHp = cols.length > 6 ? cols[6] : '';
        final alamat = cols.length > 7 ? cols[7] : '';
        final bidang = cols.length > 8 && cols[8].isNotEmpty ? cols[8] : (jabatan.startsWith('Sekbid') ? jabatan : 'Anggota');

        final member = AnggotaOsis(
          id: 'ang_${DateTime.now().millisecondsSinceEpoch}_$i',
          nama: nama,
          jabatan: jabatan,
          kelas: kelas,
          nis: nis,
          nisn: nisn,
          jurusan: jurusan,
          noHp: noHp,
          alamat: alamat,
          bidang: bidang,
          statusKeaktifan: 'Aktif',
          aktif: true,
        );
        newMembers.add(member);
        importedCount++;
      }

      if (newMembers.isNotEmpty) {
        final updatedList = List<AnggotaOsis>.from(_anggotaList)..addAll(newMembers);
        setState(() {
          _anggotaList = updatedList;
        });
        await DataService.saveAnggotaOsis(updatedList);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil mengimpor $importedCount pengurus OSIS dari ${file.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengimpor file: $e')),
        );
      }
    }
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
                    OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file_rounded, size: 18),
                      label: const Text('Impor File'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _importPengurusFromFile,
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
                          label: Text(
                            b,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? (ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
                                      ? Colors.white
                                      : Colors.black87)
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: primary,
                          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: isSelected ? primary : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            width: 1,
                          ),
                          showCheckmark: false,
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
                          label: Text(
                            st,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected
                                  ? (ThemeData.estimateBrightnessForColor(primary) == Brightness.dark
                                      ? Colors.white
                                      : Colors.black87)
                                  : (isDark ? Colors.white70 : const Color(0xFF334155)),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: primary,
                          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          side: BorderSide(
                            color: isSelected ? primary : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            width: 1,
                          ),
                          showCheckmark: false,
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
                if (ctx.mounted) Navigator.pop(ctx);
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
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
