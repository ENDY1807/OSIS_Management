import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/localization_service.dart';
import '../app_theme.dart';

class KebaikanScreen extends StatefulWidget {
  final String username;
  const KebaikanScreen({super.key, this.username = ''});

  @override
  State<KebaikanScreen> createState() => _KebaikanScreenState();
}

class _KebaikanScreenState extends State<KebaikanScreen> {
  List<Siswa> _siswa = [];
  List<CatatanKebaikan> _kebaikan = [];
  String _currentUser = '';
  String _filterKategori = 'Semua';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  bool get _isReadOnly => AuthService.isReadOnly(_currentUser);
  bool get _canEdit =>
      !_isReadOnly &&
      (AuthService.hasExecutiveAccess(_currentUser) ||
          AuthService.isSuperStaff(_currentUser));

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.normalizeUsername(widget.username);
    _initUserAndLoad();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'kebaikan' || table == 'siswa' || table == 'all') {
        if (mounted) _load(showLoading: false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant KebaikanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _initUserAndLoad();
    }
  }

  Future<void> _initUserAndLoad() async {
    String u = widget.username;
    if (u.isEmpty) {
      u = (await AuthService.getUserName()) ?? '';
    }
    if (mounted) {
      setState(() {
        _currentUser = AuthService.normalizeUsername(u);
      });
      _load();
    }
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading && _kebaikan.isEmpty) setState(() => _loading = true);
    try {
      final s = await DataService.getSiswa();
      final k = await DataService.getKebaikan();
      if (!mounted) return;
      setState(() {
        _siswa = s;
        _kebaikan = k..sort((a, b) => b.tanggal.compareTo(a.tanggal));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<CatatanKebaikan> get _filteredList {
    return _kebaikan.where((k) {
      final matchKategori = _filterKategori == 'Semua' || k.kategori == _filterKategori;
      if (!matchKategori) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final nama = (k.namaSiswa ?? '').toLowerCase();
      final kelas = (k.kelasSiswa ?? '').toLowerCase();
      final judul = k.judul.toLowerCase();
      return nama.contains(q) || kelas.contains(q) || judul.contains(q);
    }).toList();
  }

  Color _kategoriColor(String kat) {
    switch (kat) {
      case KategoriKebaikan.ibadah:
        return const Color(0xFF10B981); // Emerald
      case KategoriKebaikan.kejujuran:
        return const Color(0xFF00B4D8); // Cyan/Teal
      case KategoriKebaikan.sosial:
        return const Color(0xFF8B5CF6); // Purple
      case KategoriKebaikan.prestasi:
        return const Color(0xFFF59E0B); // Amber / Gold
      case KategoriKebaikan.lingkungan:
        return const Color(0xFF059669); // Forest
      case KategoriKebaikan.kedisiplinan:
        return const Color(0xFF3B82F6); // Blue
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  IconData _kategoriIcon(String kat) {
    switch (kat) {
      case KategoriKebaikan.ibadah:
        return Icons.auto_awesome_rounded;
      case KategoriKebaikan.kejujuran:
        return Icons.verified_user_rounded;
      case KategoriKebaikan.sosial:
        return Icons.volunteer_activism_rounded;
      case KategoriKebaikan.prestasi:
        return Icons.emoji_events_rounded;
      case KategoriKebaikan.lingkungan:
        return Icons.eco_rounded;
      case KategoriKebaikan.kedisiplinan:
        return Icons.alarm_on_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  void _showForm([CatatanKebaikan? existing]) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String? selectedSiswaId = existing?.siswaId;
    final judulCtrl = TextEditingController(text: existing?.judul ?? '');
    final ketCtrl = TextEditingController(text: existing?.keterangan ?? '');
    final apresiasiCtrl = TextEditingController(
        text: existing?.apresiasi ?? 'Pujian Lisan & Catatan Prestasi');
    int poin = existing?.poin ?? 10;
    String kategori = existing?.kategori ?? KategoriKebaikan.ibadah;
    DateTime tanggal = existing?.tanggal ?? DateTime.now();
    bool isSaving = false;

    final quickSuggestions = [
      'Membantu merapikan ruang kelas / mushola',
      'Mengembalikan uang/barang hilang ke posko',
      'Memimpin doa bersama dan tadarus',
      'Membantu teman yang sakit / tertinggal pelajaran',
      'Meraih Juara / Prestasi mewakili sekolah',
      'Aktif sebagai petugas upacara & ketertiban',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDark
                ? const Border(top: BorderSide(color: Color(0xFF243452), width: 1))
                : null,
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.star_rounded,
                          color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existing == null
                                ? LocalizationService.tr('kebaikan_add')
                                : LocalizationService.tr('kebaikan_edit'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : kTextDark,
                            ),
                          ),
                          Text(
                            'Catat aksi positif, karakter terpuji & apresiasi siswa',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Pilih Siswa
                DropdownButtonFormField<String>(
                  value: selectedSiswaId,
                  decoration: InputDecoration(
                    labelText: 'Pilih Siswa *',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.person_search_rounded, color: kAccent),
                  ),
                  items: _siswa
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text('${s.nama} (${s.kelas})',
                                overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: isSaving
                      ? null
                      : (val) {
                          setModal(() => selectedSiswaId = val);
                        },
                ),
                const SizedBox(height: 12),

                // Kategori Kebaikan
                DropdownButtonFormField<String>(
                  value: kategori,
                  decoration: InputDecoration(
                    labelText: 'Kategori Kebaikan *',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: Icon(_kategoriIcon(kategori), color: _kategoriColor(kategori)),
                  ),
                  items: KategoriKebaikan.all
                      .map((k) => DropdownMenuItem(
                            value: k,
                            child: Row(
                              children: [
                                Icon(_kategoriIcon(k), size: 16, color: _kategoriColor(k)),
                                const SizedBox(width: 8),
                                Text(k),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: isSaving ? null : (val) => setModal(() => kategori = val ?? kategori),
                ),
                const SizedBox(height: 12),

                // Judul Kebaikan
                TextField(
                  controller: judulCtrl,
                  decoration: InputDecoration(
                    labelText: 'Judul Kebaikan / Aksi Positif *',
                    hintText: 'Contoh: Membantu merapikan mushola',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.volunteer_activism_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 8),

                // Saran Cepat
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: quickSuggestions.map((sug) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(sug, style: const TextStyle(fontSize: 11)),
                          backgroundColor: isDark ? const Color(0xFF1B2433) : const Color(0xFFF1F5F9),
                          side: BorderSide.none,
                          onPressed: () => setModal(() => judulCtrl.text = sug),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Poin Kebaikan (+5, +10, +15, +20, +50)
                Row(
                  children: [
                    Text(
                      'Poin Bintang:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: [5, 10, 15, 20, 50].map((p) {
                          final isSelected = poin == p;
                          return ChoiceChip(
                            label: Text('+$p'),
                            selected: isSelected,
                            selectedColor: const Color(0xFF10B981),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            onSelected: (_) => setModal(() => poin = p),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Apresiasi / Reward yang diberikan
                TextField(
                  controller: apresiasiCtrl,
                  decoration: InputDecoration(
                    labelText: 'Bentuk Apresiasi yang Diberikan',
                    hintText: 'Contoh: Pujian Lisan & Piagam Bintang Kebaikan',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.military_tech_outlined, color: Color(0xFFF59E0B)),
                  ),
                ),
                const SizedBox(height: 12),

                // Tanggal
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tanggal,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setModal(() => tanggal = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tanggal Kejadian',
                      labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                      prefixIcon: const Icon(Icons.calendar_today_outlined, color: kAccent),
                    ),
                    child: Text(
                      DateFormat('dd MMMM yyyy', 'id').format(tanggal),
                      style: TextStyle(fontSize: 14, color: isDark ? Colors.white : kTextDark),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Keterangan Tambahan
                TextField(
                  controller: ketCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Keterangan Tambahan (Opsional)',
                    hintText: 'Catatan tambahan terkait aksi terpuji ini...',
                    labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    prefixIcon: const Icon(Icons.notes_rounded, color: kAccent),
                  ),
                ),
                const SizedBox(height: 18),

                // Tombol Simpan
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedSiswaId == null || selectedSiswaId!.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Pilih siswa yang melakukan kebaikan!'),
                              backgroundColor: Colors.redAccent,
                            ));
                            return;
                          }
                          if (judulCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Judul kebaikan wajib diisi!'),
                              backgroundColor: Colors.redAccent,
                            ));
                            return;
                          }

                          setModal(() => isSaving = true);

                          final siswaMatch = _siswa.firstWhere(
                            (s) => s.id == selectedSiswaId,
                            orElse: () => Siswa(id: selectedSiswaId!, nama: '', kelas: '', nis: ''),
                          );

                          final catatan = CatatanKebaikan(
                            id: existing?.id ?? const Uuid().v4(),
                            siswaId: selectedSiswaId!,
                            judul: judulCtrl.text.trim(),
                            kategori: kategori,
                            poin: poin,
                            tanggal: tanggal,
                            keterangan: ketCtrl.text.trim(),
                            namaSiswa: siswaMatch.nama,
                            kelasSiswa: siswaMatch.kelas,
                            nisSiswa: siswaMatch.nis,
                            petugas: _currentUser,
                            apresiasi: apresiasiCtrl.text.trim().isNotEmpty
                                ? apresiasiCtrl.text.trim()
                                : 'Pujian Lisan & Catatan Prestasi',
                          );

                          try {
                            if (existing == null) {
                              await DataService.addKebaikan(catatan);
                              try {
                                await NotificationService.notifyUpdate(
                                  title: 'Catatan Kebaikan Baru',
                                  message:
                                      'Aksi "${catatan.judul}" (+${catatan.poin} Poin) dicatat untuk ${catatan.namaSiswa}',
                                  category: 'system',
                                  actor: _currentUser,
                                );
                              } catch (_) {}
                            } else {
                              await DataService.updateKebaikan(catatan);
                            }

                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        existing == null
                                            ? 'Catatan kebaikan berhasil ditambahkan!'
                                            : 'Catatan kebaikan berhasil diperbarui!',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ));
                            }
                            await _load();
                          } catch (e) {
                            setModal(() => isSaving = false);
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text('Gagal menyimpan: $e'),
                                backgroundColor: Colors.redAccent,
                              ));
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          LocalizationService.tr('btn_save'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLeaderboard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Hitung total poin per siswa
    final Map<String, int> poinMap = {};
    final Map<String, String> namaMap = {};
    final Map<String, String> kelasMap = {};

    for (final k in _kebaikan) {
      final sId = k.siswaId;
      poinMap[sId] = (poinMap[sId] ?? 0) + k.poin;
      if (k.namaSiswa != null && k.namaSiswa!.isNotEmpty) {
        namaMap[sId] = k.namaSiswa!;
        kelasMap[sId] = k.kelasSiswa ?? '';
      }
    }

    final sortedEntries = poinMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141D2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 26),
                const SizedBox(width: 10),
                Text(
                  LocalizationService.tr('kebaikan_leaderboard'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : kTextDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (sortedEntries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Belum ada akumulasi poin kebaikan.',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              )
            else
              ...List.generate(
                sortedEntries.length > 5 ? 5 : sortedEntries.length,
                (i) {
                  final e = sortedEntries[i];
                  final nama = namaMap[e.key] ?? 'Siswa';
                  final kelas = kelasMap[e.key] ?? '';
                  final totalPoin = e.value;

                  Color rankColor;
                  if (i == 0) rankColor = const Color(0xFFF59E0B); // Emas
                  else if (i == 1) rankColor = const Color(0xFF94A3B8); // Perak
                  else if (i == 2) rankColor = const Color(0xFFB45309); // Perunggu
                  else rankColor = const Color(0xFF10B981);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B2433) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: i == 0 ? rankColor.withAlpha(120) : (isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: rankColor,
                          child: Text(
                            '#${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nama,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : kTextDark)),
                              Text(kelas,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.black54)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(isDark ? 40 : 25),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                '+$totalPoin Poin',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(CatatanKebaikan k) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final katColor = _kategoriColor(k.kategori);
    final textTitle = isDark ? Colors.white : kTextDark;
    final textSub = isDark ? const Color(0xFF94A3B8) : Colors.black54;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141D2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
        border: Border.all(
          color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin_rounded, size: 16, color: katColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${k.namaSiswa ?? 'Siswa'} (${k.kelasSiswa ?? '-'})',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: textTitle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        k.judul,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(90)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        '+${k.poin} Poin',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badgeChip(
                  _kategoriIcon(k.kategori),
                  k.kategori,
                  color: katColor,
                  isDark: isDark,
                ),
                _badgeChip(
                  Icons.military_tech_outlined,
                  k.apresiasi,
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
                _badgeChip(
                  Icons.calendar_today_outlined,
                  DateFormat('dd MMM yyyy', 'id').format(k.tanggal),
                  color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                  isDark: isDark,
                ),
              ],
            ),
            if (k.keterangan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E1626) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  k.keterangan,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSub,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            if (_canEdit) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: Text(LocalizationService.tr('btn_edit'),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () => _showForm(k),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 15),
                    label: Text(LocalizationService.tr('btn_delete'),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(LocalizationService.tr('kebaikan_delete_confirm')),
                          content: Text('Hapus catatan kebaikan "${k.judul}" untuk ${k.namaSiswa}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(LocalizationService.tr('btn_cancel')),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(LocalizationService.tr('btn_delete'),
                                  style: const TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await DataService.deleteKebaikan(k.id);
                        _load();
                      }
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badgeChip(IconData icon, String text,
      {required Color color, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 35 : 20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
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

    final totalCatatan = _kebaikan.length;
    final totalPoin = _kebaikan.fold<int>(0, (sum, item) => sum + item.poin);
    final filtered = _filteredList;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header Metrik Kebaikan
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1424) : primary,
              border: isDark
                  ? const Border(bottom: BorderSide(color: Color(0xFF243452)))
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withAlpha(60)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$totalCatatan',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Total Kebaikan',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withAlpha(60)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '+$totalPoin',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6EE7B7),
                              ),
                            ),
                            const Text(
                              'Akumulasi Poin',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _showLeaderboard,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withAlpha(180),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: const [
                            Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
                            SizedBox(height: 2),
                            Text(
                              'Bintang',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search & Filter Bar
          Container(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari nama siswa, kelas, atau aksi kebaikan...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'Semua',
                      ...KategoriKebaikan.all,
                    ].map((k) {
                      final selected = _filterKategori == k;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(k),
                          selected: selected,
                          selectedColor: const Color(0xFF10B981),
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : (isDark ? const Color(0xFF94A3B8) : kTextDark),
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                          onSelected: (_) => setState(() => _filterKategori = k),
                          showCheckmark: false,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // List Catatan Kebaikan
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: primary))
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withAlpha(isDark ? 35 : 25),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.star_outline_rounded,
                                    size: 38, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                LocalizationService.tr('kebaikan_empty'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : kTextDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Apresiasi perilaku terpuji siswa dengan mencatat kebaikannya sekarang.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                                ),
                              ),
                              if (_canEdit) ...[
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _showForm(),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(LocalizationService.tr('kebaikan_add')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(0xFF10B981),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                LocalizationService.tr('kebaikan_add'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }
}
