import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/sync_service.dart';

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

  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  final _currencyFmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

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

      if (!mounted) return;
      setState(() {
        _profil = p;
        _anggotaList = ang;
        _prokerList = prk;
        _agendaList = agd;
        _transaksiList = trx;
        _pengumumanList = pgm;
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
            // 1. Stat Overview Cards (Clean, modern KPI grid)
            _buildStatCards(theme, isDark, primary),
            const SizedBox(height: 20),

            // 2. Perkembangan Proker (Modern Chart) & Kalender Agenda Terdekat
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 850) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildProkerChartCard(theme, isDark, primary)),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: _buildCalendarAgendaCard(theme, isDark, primary)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildProkerChartCard(theme, isDark, primary),
                      const SizedBox(height: 16),
                      _buildCalendarAgendaCard(theme, isDark, primary),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 20),

            // 3. Pengumuman OSIS (jika ada)
            _buildPengumumanSection(theme, isDark, primary),
            const SizedBox(height: 30),
          ],
        ),
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
            value: '$_prokerSelesai / ${_prokerList.length}',
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

  // Modern Area Chart for Proker Progress (Matching reference style)
  Widget _buildProkerChartCard(ThemeData theme, bool isDark, Color primary) {
    final total = _prokerList.length;
    final selesai = _prokerSelesai;
    final proses = _prokerBerjalan;

    // Hitung data per bulan (Jan - Des: 1..12)
    final rencanaPerBulan = List<double>.filled(12, 0);
    final realisasiPerBulan = List<double>.filled(12, 0);

    for (final p in _prokerList) {
      final rBulan = (p.tanggalRencana.month - 1).clamp(0, 11);
      rencanaPerBulan[rBulan] += 1;

      if (p.status.toLowerCase().contains('selesai')) {
        final realBulan = ((p.tanggalRealisasi ?? p.tanggalRencana).month - 1).clamp(0, 11);
        realisasiPerBulan[realBulan] += 1;
      }
    }

    // Jika data kosong, tampilkan garis 0 yang rapi
    double maxVal = 0;
    for (int i = 0; i < 12; i++) {
      if (rencanaPerBulan[i] > maxVal) maxVal = rencanaPerBulan[i];
      if (realisasiPerBulan[i] > maxVal) maxVal = realisasiPerBulan[i];
    }
    final double maxY = maxVal <= 4 ? 5 : (maxVal * 1.25).ceilToDouble();
    final double intervalY = maxY <= 6 ? 1 : (maxY / 4).ceilToDouble();

    final rencanaSpots = List.generate(12, (i) => FlSpot(i + 1.0, rencanaPerBulan[i]));
    final realisasiSpots = List.generate(12, (i) => FlSpot(i + 1.0, realisasiPerBulan[i]));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Judul Tengah & Tombol Menu Sisi Kanan (Sesuai Referensi Gambar)
          Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Tren Program Kerja OSIS - Area Chart',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => widget.onNavigateTab?.call(2),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Legend: Ditengah horizontal di bawah judul (Sesuai Referensi Gambar)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Target Rencana ($total)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 18,
                    height: 2.2,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34D399),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Realisasi Selesai ($selesai)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Area Chart Widget
          SizedBox(
            height: 230,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      const months = [
                        'January', 'February', 'March', 'April', 'May', 'June',
                        'July', 'August', 'September', 'October', 'November', 'December'
                      ];
                      return touchedSpots.map((spot) {
                        final monthName = months[(spot.x.toInt() - 1).clamp(0, 11)];
                        final isRencana = spot.barIndex == 0;
                        return LineTooltipItem(
                          '$monthName: ${spot.y.toInt()} ${isRencana ? 'Rencana' : 'Selesai'}',
                          TextStyle(
                            color: isRencana ? const Color(0xFF38BDF8) : const Color(0xFF34D399),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: intervalY,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark ? const Color(0xFF334155).withAlpha(120) : const Color(0xFFE2E8F0),
                    strokeWidth: 0.9,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: intervalY,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value > maxY) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          textAlign: TextAlign.right,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const months = [
                          'January', 'February', 'March', 'April', 'May', 'June',
                          'July', 'August', 'September', 'October', 'November', 'December'
                        ];
                        final idx = value.toInt() - 1;
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Transform.rotate(
                              angle: -0.75, // Miring ~43 derajat persis referensi gambar
                              alignment: Alignment.centerRight,
                              child: Text(
                                months[idx],
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      width: 1.2,
                    ),
                  ),
                ),
                minX: 1,
                maxX: 12,
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // Green Area (Realisasi Selesai / Product B)
                  LineChartBarData(
                    spots: realisasiSpots,
                    isCurved: false, // Garis lurus patah-patah persis referensi gambar
                    color: const Color(0xFF34D399),
                    barWidth: 2.0,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF34D399).withAlpha(isDark ? 50 : 35),
                    ),
                  ),
                  // Blue Area (Target Rencana / Product A)
                  LineChartBarData(
                    spots: rencanaSpots,
                    isCurved: false, // Garis lurus patah-patah persis referensi gambar
                    color: const Color(0xFF38BDF8),
                    barWidth: 2.0,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF38BDF8).withAlpha(isDark ? 50 : 35),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Metric Badges Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProgressMetric('Total Target', '$total Proker', const Color(0xFF38BDF8), isDark),
              _buildProgressMetric('Sedang Jalan', '$proses Proker', const Color(0xFFF59E0B), isDark),
              _buildProgressMetric('Telah Selesai', '$selesai Proker', const Color(0xFF34D399), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetric(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  // Modern Interactive Calendar for Agenda Terdekat
  Widget _buildCalendarAgendaCard(ThemeData theme, bool isDark, Color primary) {
    final now = DateTime.now();
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    // 1 = Monday, 7 = Sunday
    final startingWeekday = firstDayOfMonth.weekday;

    // Filter agenda by dates in this month
    final agendaDates = <int, List<AgendaOsis>>{};
    for (final ag in _agendaList) {
      if (ag.waktuMulai.year == year && ag.waktuMulai.month == month) {
        agendaDates.putIfAbsent(ag.waktuMulai.day, () => []).add(ag);
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 6),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Calendar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profil.namaOrganisasi.isNotEmpty ? _profil.namaOrganisasi : 'Kalender Agenda',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(_calendarMonth),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.amberAccent : const Color(0xFFD97706),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 22),
                    tooltip: 'Bulan Sebelumnya',
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 22),
                    tooltip: 'Bulan Berikutnya',
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Days of Week Header
          Row(
            children: const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const Divider(height: 16),

          // Calendar Grid (6 rows max)
          Builder(
            builder: (context) {
              final totalCells = ((startingWeekday - 1) + daysInMonth + 6) ~/ 7 * 7;
              final rows = <Widget>[];

              for (int i = 0; i < totalCells; i += 7) {
                final dayCells = <Widget>[];
                for (int j = 0; j < 7; j++) {
                  final index = i + j;
                  final dayNum = index - (startingWeekday - 1) + 1;
                  final isValidDay = dayNum >= 1 && dayNum <= daysInMonth;

                  if (!isValidDay) {
                    dayCells.add(const Expanded(child: SizedBox(height: 34)));
                    continue;
                  }

                  final isToday = now.year == year && now.month == month && now.day == dayNum;
                  final hasAgenda = agendaDates.containsKey(dayNum);
                  final agendasOnDay = agendaDates[dayNum] ?? [];

                  dayCells.add(
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          _showAgendaDialog(DateTime(year, month, dayNum), agendasOnDay);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                          decoration: BoxDecoration(
                            color: isToday
                                ? primary.withAlpha(isDark ? 80 : 35)
                                : (hasAgenda ? const Color(0xFFF59E0B).withAlpha(isDark ? 40 : 25) : Colors.transparent),
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(color: primary, width: 1.2)
                                : (hasAgenda
                                    ? Border.all(color: const Color(0xFFF59E0B).withAlpha(120), width: 0.8)
                                    : null),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: (isToday || hasAgenda) ? FontWeight.bold : FontWeight.normal,
                                  color: isToday
                                      ? primary
                                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ),
                              if (hasAgenda)
                                Positioned(
                                  bottom: 3,
                                  child: Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF59E0B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                rows.add(Row(children: dayCells));
              }

              return Column(children: rows);
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Titik kuning = Ada agenda',
                    style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ],
              ),
              InkWell(
                onTap: () => widget.onNavigateTab?.call(2),
                child: const Text('Buka Kalender Lengkap >', style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAgendaDialog(DateTime date, List<AgendaOsis> agendas) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.event_note_rounded, color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agenda Kegiatan OSIS',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (agendas.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_rounded, size: 48, color: isDark ? Colors.white30 : Colors.black26),
                        const SizedBox(height: 10),
                        Text(
                          'Tidak ada agenda pada tanggal ini.',
                          style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: agendas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final a = agendas[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withAlpha(isDark ? 40 : 25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          a.judul,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withAlpha(isDark ? 50 : 25),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          a.status,
                                          style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Waktu: ${DateFormat('HH:mm').format(a.waktuMulai)}${a.waktuSelesai != null ? ' - ${DateFormat('HH:mm').format(a.waktuSelesai!)}' : ''}',
                                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                  Text(
                                    'Lokasi: ${a.lokasi}',
                                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                  ),
                                  if (a.deskripsi.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      a.deskripsi,
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onNavigateTab?.call(2);
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: const Text('Buka Menu Agenda & Tambah Agenda'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
}
