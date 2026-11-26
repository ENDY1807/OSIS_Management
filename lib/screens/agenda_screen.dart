import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';

class AgendaScreen extends StatefulWidget {
  final String username;
  const AgendaScreen({super.key, required this.username});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  List<AgendaOsis> _agendaList = [];
  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  String _filterKategori = 'Semua';
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  final _timeFmt = DateFormat('HH:mm', 'id_ID');

  bool get _canManage =>
      AuthService.canManageProker(widget.username) ||
      AuthService.canManageAdministrasi(widget.username);

  @override
  void initState() {
    super.initState();
    _loadAgenda();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'agenda_osis' || table == 'all') {
        if (mounted) _loadAgenda(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAgenda({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final list = await DataService.getAgenda();
      if (!mounted) return;
      setState(() {
        _agendaList = list;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AgendaOsis> get _filteredAgenda {
    return _agendaList.where((a) {
      final matchesSearch = _searchQuery.isEmpty ||
          a.judul.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.lokasi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.penanggungJawab.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          a.deskripsi.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesKategori = _filterKategori == 'Semua' ||
          a.kategori.toLowerCase() == _filterKategori.toLowerCase();

      return matchesSearch && matchesKategori;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final filtered = _filteredAgenda;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender & Agenda OSIS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: const [],
      ),
      body: Column(
        children: [
          // Filter & Search Header
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
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari agenda rapat, kegiatan, lomba, lokasi...',
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Kategori: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ...['Semua', 'Rapat OSIS', 'Kegiatan Sekolah', 'Perlombaan', 'Kegiatan Bidang', 'Agenda Tahunan'].map((cat) {
                        final isSelected = _filterKategori == cat;
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

          // Total Count Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total ${filtered.length} Jadwal Agenda',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                ),
                Text(
                  'Akan Datang: ${_agendaList.where((a) => a.status == 'Akan Datang').length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
          ),

          // List View
          Expanded(
            child: _loading && _agendaList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Tidak ada agenda dengan kata kunci "$_searchQuery"'
                                  : 'Belum ada agenda kegiatan yang terdaftar.',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final item = filtered[i];
                          return _buildAgendaCard(item, isDark, primary);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: () => _showAgendaDialog(),
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: 'Tambah Agenda Kegiatan',
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }

  Widget _buildAgendaCard(AgendaOsis a, bool isDark, Color primary) {
    Color statusColor = Colors.orange;
    if (a.status == 'Sedang Berlangsung') statusColor = Colors.blue;
    if (a.status == 'Selesai') statusColor = Colors.green;
    if (a.status == 'Dibatalkan') statusColor = Colors.red;

    final now = DateTime.now();
    final isToday = a.waktuMulai.year == now.year &&
        a.waktuMulai.month == now.month &&
        a.waktuMulai.day == now.day;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? Colors.amber.withAlpha(180)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isToday ? 1.5 : 1,
        ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Box
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isToday
                      ? Colors.amber.withAlpha(isDark ? 50 : 30)
                      : primary.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isToday ? Colors.amber : primary.withAlpha(100),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('dd').format(a.waktuMulai),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isToday ? Colors.amber : primary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(a.waktuMulai),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isToday ? Colors.amber : primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isToday) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('HARI INI', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            a.judul,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withAlpha(120), width: 0.8),
                          ),
                          child: Text(
                            a.status,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${a.kategori} • Bidang: ${a.bidang}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          '${_timeFmt.format(a.waktuMulai)}${a.waktuSelesai != null ? ' - ${_timeFmt.format(a.waktuSelesai!)}' : ''}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            a.lokasi,
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_canManage)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 19, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'edit') _showAgendaDialog(existing: a);
                    if (val == 'selesai') {
                      a.status = 'Selesai';
                      DataService.saveAgenda(a);
                    }
                    if (val == 'delete') _confirmDeleteAgenda(a);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'selesai', child: Text('Tandai Selesai')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit Agenda')),
                    const PopupMenuItem(value: 'delete', child: Text('Hapus Agenda', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
            ],
          ),
          if (a.deskripsi.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withAlpha(100) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                a.deskripsi,
                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : const Color(0xFF334155), height: 1.3),
              ),
            ),
          ],
          if (a.penanggungJawab.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'PJ: ${a.penanggungJawab}',
                style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  void _showAgendaDialog({AgendaOsis? existing}) {
    final judulCtrl = TextEditingController(text: existing?.judul ?? '');
    final lokasiCtrl = TextEditingController(text: existing?.lokasi ?? 'Ruang OSIS');
    final pjCtrl = TextEditingController(text: existing?.penanggungJawab ?? '');
    final deskCtrl = TextEditingController(text: existing?.deskripsi ?? '');
    String kategori = existing?.kategori ?? 'Rapat OSIS';
    String bidang = existing?.bidang ?? 'BPH';
    String status = existing?.status ?? 'Akan Datang';
    DateTime selectedDate = existing?.waktuMulai ?? DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(existing?.waktuMulai ?? DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null ? 'Tambah Agenda Baru' : 'Edit Agenda', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: judulCtrl, decoration: const InputDecoration(labelText: 'Nama Agenda / Kegiatan *')),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: kategori,
                          decoration: const InputDecoration(labelText: 'Kategori'),
                          items: const [
                            DropdownMenuItem(value: 'Rapat OSIS', child: Text('Rapat OSIS')),
                            DropdownMenuItem(value: 'Kegiatan Sekolah', child: Text('Kegiatan Sekolah')),
                            DropdownMenuItem(value: 'Perlombaan', child: Text('Perlombaan')),
                            DropdownMenuItem(value: 'Kegiatan Bidang', child: Text('Kegiatan Bidang')),
                            DropdownMenuItem(value: 'Agenda Tahunan', child: Text('Agenda Tahunan')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlg(() => kategori = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: bidang,
                          decoration: const InputDecoration(labelText: 'Bidang Pelaksana'),
                          items: const [
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
                            DropdownMenuItem(value: 'Sekolah', child: Text('Seluruh Sekolah')),
                          ],
                          onChanged: (v) {
                            if (v != null) setDlg(() => bidang = v);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Date & Time Picker Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setDlg(() => selectedDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.access_time, size: 16),
                          label: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                          onPressed: () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (t != null) setDlg(() => selectedTime = t);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: lokasiCtrl, decoration: const InputDecoration(labelText: 'Tempat / Lokasi Kegiatan')),
                  const SizedBox(height: 8),
                  TextField(controller: pjCtrl, decoration: const InputDecoration(labelText: 'Penanggung Jawab')),
                  const SizedBox(height: 8),
                  TextField(controller: deskCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Deskripsi / Catatan Agenda')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status Agenda'),
                    items: const [
                      DropdownMenuItem(value: 'Akan Datang', child: Text('Akan Datang')),
                      DropdownMenuItem(value: 'Sedang Berlangsung', child: Text('Sedang Berlangsung')),
                      DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                      DropdownMenuItem(value: 'Dibatalkan', child: Text('Dibatalkan')),
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
                final judul = judulCtrl.text.trim();
                if (judul.isEmpty) return;

                final startTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                final item = AgendaOsis(
                  id: existing?.id ?? 'agd-${DateTime.now().millisecondsSinceEpoch}',
                  judul: judul,
                  kategori: kategori,
                  bidang: bidang,
                  waktuMulai: startTime,
                  waktuSelesai: startTime.add(const Duration(hours: 2)),
                  lokasi: lokasiCtrl.text.trim().isNotEmpty ? lokasiCtrl.text.trim() : 'Ruang OSIS',
                  penanggungJawab: pjCtrl.text.trim(),
                  deskripsi: deskCtrl.text.trim(),
                  status: status,
                );

                await DataService.saveAgenda(item);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAgenda(AgendaOsis a) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Agenda?'),
        content: Text('Yakin ingin menghapus agenda "${a.judul}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await DataService.deleteAgenda(a.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
