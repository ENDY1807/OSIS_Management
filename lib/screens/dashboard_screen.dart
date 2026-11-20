import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/app_settings_service.dart';
import '../widgets/nusantara_decorations.dart';

class DashboardScreen extends StatefulWidget {
  final String username;
  final Function(int tabIndex)? onNavigateTab;

  const DashboardScreen({
    super.key,
    required this.username,
    this.onNavigateTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ProfilOsis _profil = ProfilOsis();
  List<AnggotaOsis> _anggotaList = [];
  List<Proker> _prokerList = [];
  List<AgendaOsis> _agendaList = [];
  List<KasOsisTransaksi> _transaksiList = [];
  List<PengumumanOsis> _pengumumanList = [];
  List<AktivitasPengguna> _aktivitasList = [];

  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  final _currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFmt = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (mounted) _loadDashboardData(silent: true);
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final p = await DataService.getProfilOsis();
      final ang = await DataService.getAnggotaOsis();
      final prk = await DataService.getProker();
      final agd = await DataService.getAgenda();
      final trx = await DataService.getKasTransaksi();
      final pgm = await DataService.getPengumuman();
      final akt = await DataService.getAktivitas();

      if (!mounted) return;
      setState(() {
        _profil = p;
        _anggotaList = ang;
        _prokerList = prk;
        _agendaList = agd;
        _transaksiList = trx;
        _pengumumanList = pgm;
        _aktivitasList = akt;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _saldoKas {
    int masuk = 0;
    int keluar = 0;
    for (final t in _transaksiList) {
      if (t.jenis.toLowerCase() == 'masuk') {
        masuk += t.nominal;
      } else {
        keluar += t.nominal;
      }
    }
    return masuk - keluar;
  }

  int get _prokerSelesai => _prokerList.where((p) => p.status.toLowerCase().contains('selesai')).length;
  int get _prokerBerjalan => _prokerList.where((p) => p.status.toLowerCase().contains('jalan') || p.status.toLowerCase().contains('proses')).length;
  double get _prokerPercent => _prokerList.isEmpty ? 0.0 : (_prokerSelesai / _prokerList.length);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    if (_loading && _prokerList.isEmpty && _anggotaList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        await SyncService.checkAndSync();
        await _loadDashboardData(silent: true);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Hero Organization Header Banner
            _buildHeroBanner(theme, isDark, primary),
            const SizedBox(height: 16),

            // 2. Stat Overview Grid
            _buildStatCards(theme, isDark, primary),
            const SizedBox(height: 16),

            // 3. Quick Action Shortcut Grid
            _buildQuickActions(theme, isDark, primary),
            const SizedBox(height: 20),

            // 4. Proker Progress & Upcoming Agenda in 2 Columns or Stack
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 750) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildProkerProgressCard(theme, isDark, primary)),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: _buildUpcomingAgendaCard(theme, isDark, primary)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildProkerProgressCard(theme, isDark, primary),
                      const SizedBox(height: 16),
                      _buildUpcomingAgendaCard(theme, isDark, primary),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // 5. Pinned / Latest Pengumuman OSIS
            _buildPengumumanSection(theme, isDark, primary),
            const SizedBox(height: 20),

            // 6. Recent Audit Activities Log
            _buildAktivitasSection(theme, isDark, primary),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(ThemeData theme, bool isDark, Color primary) {
    final userDisplay = AuthService.getDisplayName(widget.username);
    final userRole = AuthService.getRole(widget.username);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [primary, primary.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: primary.withAlpha(isDark ? 40 : 60),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          AppSettingsService.buildLogoWidget(width: 58, height: 58, fit: BoxFit.contain),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _profil.namaOrganisasi,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30, width: 0.8),
                      ),
                      child: Text(
                        _profil.masaBakti,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _profil.namaSekolah,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_circle, color: NusantaraColors.goldLight, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Login: $userDisplay',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: NusantaraColors.goldLight.withAlpha(50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          userRole,
                          style: const TextStyle(color: NusantaraColors.goldLight, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(ThemeData theme, bool isDark, Color primary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;
        final count = isNarrow ? 2 : 4;
        final cardWidth = (constraints.maxWidth - (count - 1) * 12) / count;

        final cards = [
          _buildMetricTile(
            title: 'Saldo Kas OSIS',
            value: _currencyFmt.format(_saldoKas),
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF10B981),
            subtitle: 'Transparansi Keuangan',
            isDark: isDark,
            onTap: () => widget.onNavigateTab?.call(4),
          ),
          _buildMetricTile(
            title: 'Total Pengurus',
            value: '${_anggotaList.length} Anggota',
            icon: Icons.groups_rounded,
            color: const Color(0xFF3B82F6),
            subtitle: '${_anggotaList.where((a) => a.aktif).length} Pengurus Aktif',
            isDark: isDark,
            onTap: () => widget.onNavigateTab?.call(1),
          ),
          _buildMetricTile(
            title: 'Program Kerja',
            value: '${_prokerSelesai} / ${_prokerList.length}',
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF8B5CF6),
            subtitle: '$_prokerBerjalan Sedang Berjalan',
            isDark: isDark,
            onTap: () => widget.onNavigateTab?.call(2),
          ),
          _buildMetricTile(
            title: 'Agenda Terdekat',
            value: '${_agendaList.where((a) => a.status != 'Selesai').length} Kegiatan',
            icon: Icons.event_available_rounded,
            color: const Color(0xFFF59E0B),
            subtitle: 'Kalender & Rapat OSIS',
            isDark: isDark,
            onTap: () => widget.onNavigateTab?.call(2),
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 30 : 6),
                blurRadius: 10,
                offset: const Offset(0, 3),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withAlpha(isDark ? 45 : 30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme, bool isDark, Color primary) {
    final actions = [
      (title: 'Profil OSIS', icon: Icons.badge_rounded, color: Colors.blueAccent, tab: 1),
      (title: 'Data Pengurus', icon: Icons.people_alt_rounded, color: Colors.teal, tab: 1),
      (title: 'Program Kerja', icon: Icons.assignment_rounded, color: Colors.indigoAccent, tab: 2),
      (title: 'Kalender Agenda', icon: Icons.calendar_month_rounded, color: Colors.deepOrange, tab: 2),
      (title: 'Administrasi', icon: Icons.folder_shared_rounded, color: Colors.purpleAccent, tab: 3),
      (title: 'Inventaris', icon: Icons.inventory_2_rounded, color: Colors.amber.shade800, tab: 3),
      (title: 'Kas OSIS', icon: Icons.account_balance_wallet_rounded, color: Colors.green, tab: 4),
      (title: 'Absensi OSIS', icon: Icons.how_to_reg_rounded, color: Colors.cyan, tab: 4),
      (title: 'Pengumuman', icon: Icons.campaign_rounded, color: Colors.redAccent, tab: 5),
      (title: 'Dokumentasi', icon: Icons.photo_library_rounded, color: Colors.pinkAccent, tab: 5),
      (title: 'Evaluasi & Rekap', icon: Icons.assessment_rounded, color: Colors.orange, tab: 6),
      (title: 'Karakter Siswa', icon: Icons.verified_user_rounded, color: Colors.blueGrey, tab: 7),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_rounded, size: 20, color: primary),
              const SizedBox(width: 8),
              Text(
                'Menu Utama & Layanan OSIS',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: actions.map((act) {
              return InkWell(
                onTap: () => widget.onNavigateTab?.call(act.tab),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 90,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: act.color.withAlpha(isDark ? 40 : 30)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: act.color.withAlpha(isDark ? 40 : 25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(act.icon, color: act.color, size: 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        act.title,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildProkerProgressCard(ThemeData theme, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.pie_chart_outline_rounded, color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Perkembangan Proker',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Text(
                '${(_prokerPercent * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _prokerPercent,
              minHeight: 10,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressChip('Selesai', '$_prokerSelesai', Colors.green, isDark),
              _buildProgressChip('Proses', '$_prokerBerjalan', Colors.blue, isDark),
              _buildProgressChip('Belum', '${_prokerList.length - _prokerSelesai - _prokerBerjalan}', Colors.orange, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressChip(String label, String count, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
        ),
      ],
    );
  }

  Widget _buildUpcomingAgendaCard(ThemeData theme, bool isDark, Color primary) {
    final upcoming = _agendaList.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Color(0xFFF59E0B), size: 19),
                  const SizedBox(width: 8),
                  Text(
                    'Agenda Terdekat',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onNavigateTab?.call(2),
                child: const Text('Lihat Semua', style: TextStyle(fontSize: 11.5, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'Belum ada agenda kegiatan mendatang.',
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12),
                ),
              ),
            )
          else
            ...upcoming.map((a) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A).withAlpha(120) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 0.8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          DateFormat('dd\nMMM').format(a.waktuMulai),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.judul,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${a.kategori} • ${a.lokasi}',
                            style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54),
                          ),
                        ],
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

  Widget _buildPengumumanSection(ThemeData theme, bool isDark, Color primary) {
    final pinned = _pengumumanList.where((p) => p.isPinned).toList();
    final latest = pinned.isNotEmpty ? pinned.first : (_pengumumanList.isNotEmpty ? _pengumumanList.first : null);

    if (latest == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF172554)]
              : [const Color(0xFFEFF6FF), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withAlpha(isDark ? 70 : 50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  latest.isPinned ? 'Pengumuman Penting OSIS' : 'Pengumuman Terbaru',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                ),
              ),
              Text(
                DateFormat('d MMM yyyy').format(latest.tanggal),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            latest.judul,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            latest.isi,
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF334155)),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dari: ${latest.pengirim} (${latest.rolePengirim})',
                style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
              InkWell(
                onTap: () => widget.onNavigateTab?.call(5),
                child: const Text('Buka Semua >', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAktivitasSection(ThemeData theme, bool isDark, Color primary) {
    final recent = _aktivitasList.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Riwayat Aktivitas Pengguna',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onNavigateTab?.call(6),
                child: const Text('Lihat Log', style: TextStyle(fontSize: 11.5, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Belum ada rekaman aktivitas pengguna.',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 12),
              ),
            )
          else
            ...recent.map((akt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                          children: [
                            TextSpan(
                              text: '${akt.displayName}: ',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: '${akt.aksi} di '),
                            TextSpan(
                              text: akt.modul,
                              style: TextStyle(color: primary, fontWeight: FontWeight.w600),
                            ),
                            if (akt.detail.isNotEmpty) TextSpan(text: ' (${akt.detail})'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(akt.waktu),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
