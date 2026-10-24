import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
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
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  bool get _isReadOnly => AuthService.isReadOnly(_currentUser);
  bool get _canEdit => !_isReadOnly;

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
    if (_searchQuery.isEmpty) return _kebaikan;
    final q = _searchQuery.toLowerCase();
    return _kebaikan.where((k) {
      final nama = (k.namaSiswa ?? '').toLowerCase();
      final kelas = (k.kelasSiswa ?? '').toLowerCase();
      final ket = k.keterangan.toLowerCase();
      final judul = k.judul.toLowerCase();
      return nama.contains(q) || kelas.contains(q) || ket.contains(q) || judul.contains(q);
    }).toList();
  }

  void _showForm([CatatanKebaikan? existing]) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Siswa? selectedSiswa;
    if (existing != null) {
      try {
        selectedSiswa = _siswa.firstWhere(
          (s) => s.id == existing.siswaId,
          orElse: () => Siswa(
            id: existing.siswaId,
            nama: existing.namaSiswa ?? 'Siswa',
            kelas: existing.kelasSiswa ?? '',
            nis: existing.nisSiswa ?? '',
          ),
        );
      } catch (_) {
        selectedSiswa = Siswa(
          id: existing.siswaId,
          nama: existing.namaSiswa ?? 'Siswa',
          kelas: existing.kelasSiswa ?? '',
          nis: existing.nisSiswa ?? '',
        );
      }
    }

    final ketCtrl = TextEditingController(
      text: existing != null
          ? (existing.keterangan.isNotEmpty ? existing.keterangan : existing.judul)
          : '',
    );
    final autoDate = existing?.tanggal ?? DateTime.now();
    bool isSaving = false;

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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.volunteer_activism_rounded,
                          color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existing == null ? 'Catat Kebaikan Siswa' : 'Edit Catatan Kebaikan',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : kTextDark,
                            ),
                          ),
                          Text(
                            'Pencatatan aksi positif & karakter terpuji siswa',
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
                const SizedBox(height: 20),

                // 1. PILIH SISWA (Searchable Autocomplete yang bisa diketik juga)
                Text(
                  'Pilih Siswa *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Autocomplete<Siswa>(
                  initialValue: TextEditingValue(
                    text: selectedSiswa != null
                        ? '${selectedSiswa!.nama} (${selectedSiswa!.kelas})'
                        : '',
                  ),
                  displayStringForOption: (s) => '${s.nama} (${s.kelas})',
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _siswa.take(25);
                    }
                    final q = textEditingValue.text.toLowerCase();
                    return _siswa.where((s) {
                      return s.nama.toLowerCase().contains(q) ||
                          s.kelas.toLowerCase().contains(q) ||
                          s.nis.toLowerCase().contains(q);
                    });
                  },
                  onSelected: (Siswa selection) {
                    setModal(() {
                      selectedSiswa = selection;
                    });
                  },
                  fieldViewBuilder: (context, fieldTextCtrl, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: fieldTextCtrl,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: 'Masukkan nama siswa atau kelas...',
                        prefixIcon: const Icon(Icons.person_search_rounded, color: Color(0xFF10B981)),
                        suffixIcon: selectedSiswa != null
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20)
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (text) {
                        if (selectedSiswa != null &&
                            '${selectedSiswa!.nama} (${selectedSiswa!.kelas})' != text) {
                          setModal(() {
                            selectedSiswa = null;
                          });
                        }
                      },
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                            itemBuilder: (BuildContext context, int index) {
                              final Siswa option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF10B981)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              option.nama,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              'Kelas ${option.kelas}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white60 : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 2. KETERANGAN
                Text(
                  'Keterangan *',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: ketCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Masukkan tindakan atau kebaikan yang dilakukan siswa...',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.edit_note_rounded, color: Color(0xFF10B981)),
                    ),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),

                // 3. TANGGAL OTOMATIS SESUAI HARI INI
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF10B981)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tanggal Pencatatan',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(autoDate),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Otomatis Hari Ini',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // TOMBOL SIMPAN
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (selectedSiswa == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Silakan pilih siswa terlebih dahulu dari daftar!'),
                              backgroundColor: Colors.orange,
                            ));
                            return;
                          }
                          final ket = ketCtrl.text.trim();
                          if (ket.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Keterangan kebaikan tidak boleh kosong!'),
                              backgroundColor: Colors.orange,
                            ));
                            return;
                          }

                          setModal(() => isSaving = true);

                          final catatan = CatatanKebaikan(
                            id: existing?.id ?? const Uuid().v4(),
                            siswaId: selectedSiswa!.id,
                            judul: ket,
                            kategori: 'Kebaikan',
                            poin: 0,
                            tanggal: autoDate,
                            keterangan: ket,
                            namaSiswa: selectedSiswa!.nama,
                            kelasSiswa: selectedSiswa!.kelas,
                            nisSiswa: selectedSiswa!.nis,
                            petugas: _currentUser,
                            apresiasi: 'Catatan Kebaikan Siswa',
                          );

                          try {
                            if (existing == null) {
                              await DataService.addKebaikan(catatan);
                              try {
                                await NotificationService.notifyUpdate(
                                  title: 'Catatan Kebaikan Siswa',
                                  message: '${catatan.namaSiswa} (${catatan.kelasSiswa}): ${catatan.keterangan}',
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
                                content: Text(
                                  existing == null
                                      ? 'Catatan kebaikan untuk ${catatan.namaSiswa} berhasil disimpan!'
                                      : 'Catatan kebaikan berhasil diperbarui!',
                                ),
                                backgroundColor: const Color(0xFF059669),
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
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          existing == null ? 'Simpan Catatan Kebaikan' : 'Perbarui Catatan',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(CatatanKebaikan k) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                  color: Colors.black.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
        border: Border.all(
          color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(isDark ? 35 : 20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: Color(0xFF059669),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k.namaSiswa ?? 'Siswa',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textTitle,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Kelas ${k.kelasSiswa ?? '-'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.calendar_today_rounded, size: 12, color: textSub),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('d MMM yyyy', 'id_ID').format(k.tanggal),
                            style: TextStyle(fontSize: 11.5, color: textSub),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1424) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                k.keterangan.isNotEmpty ? k.keterangan : k.judul,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (k.petugas.isNotEmpty || _canEdit) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (k.petugas.isNotEmpty)
                    Expanded(
                      child: Text(
                        'Dicatat oleh: ${k.petugas}',
                        style: TextStyle(fontSize: 11, color: textSub),
                      ),
                    ),
                  if (_canEdit) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit',
                      color: theme.colorScheme.primary,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _showForm(k),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: 'Hapus',
                      color: Colors.redAccent,
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Hapus Catatan Kebaikan'),
                            content: Text('Hapus catatan kebaikan untuk ${k.namaSiswa}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Hapus'),
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
                ],
              ),
            ],
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

    final totalCatatan = _kebaikan.length;
    final totalSiswa = _kebaikan.map((e) => e.siswaId).toSet().length;
    final filtered = _filteredList;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header Metrik Bersih & Modern (Tanpa Bintang)
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1424) : primary,
              border: isDark
                  ? const Border(bottom: BorderSide(color: Color(0xFF243452)))
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalCatatan',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Total Catatan Kebaikan',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$totalSiswa',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6EE7B7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Siswa Terpuji',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Container(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Masukkan nama siswa, kelas, atau isi kebaikan...',
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
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
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withAlpha(isDark ? 35 : 20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  size: 34,
                                  color: Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum Ada Catatan Kebaikan',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : kTextDark,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Catat aksi terpuji siswa hari ini untuk apresiasi karakter positif.',
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
                                  label: const Text('Catat Kebaikan Sekarang'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: const Color(0xFF059669),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _buildCard(filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              onPressed: () => _showForm(),
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: 'Catat Kebaikan',
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
    );
  }
}
