import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/app_settings_service.dart';
import '../widgets/nusantara_decorations.dart';

class KasOsisScreen extends StatefulWidget {
  final String username;
  final int initialTab;

  const KasOsisScreen({
    super.key,
    required this.username,
    this.initialTab = 0,
  });

  @override
  State<KasOsisScreen> createState() => _KasOsisScreenState();
}

class _KasOsisScreenState extends State<KasOsisScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  StreamSubscription<String>? _dataSub;

  List<AnggotaOsis> _anggotaList = [];
  List<KasOsisSession> _kasSessions = [];
  List<KasOsisTransaksi> _transaksiList = [];
  List<AbsensiOsisSession> _absensiSessions = [];

  KasOsisSession? _selectedKasSession;
  AbsensiOsisSession? _selectedAbsensiSession;

  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  String _kasFilter = 'ALL'; // ALL, LUNAS, BELUM
  String _absenFilter = 'ALL'; // ALL, Hadir, Izin, Sakit, Alpa
  String _bukuKasFilter = 'ALL'; // ALL, MASUK, KELUAR

  final _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

  bool get _canEdit => AuthService.canEditKasAndAbsensi(widget.username);
  bool get _isBendahara => _canEdit;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });

    _loadData();

    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'kas_osis' ||
          table == 'absensi_osis' ||
          table == 'kas_transaksi' ||
          table == 'anggota_osis' ||
          table == 'all') {
        _loadData(silent: true);
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

  Future<void> _handleRefresh() async {
    try {
      await SyncService.checkAndSync();
    } catch (_) {}
    await _loadData(silent: true);
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final anggota = await DataService.getAnggotaOsis();
      final kasList = await DataService.getKasOsisSessions();
      final trxList = await DataService.getKasTransaksi();
      final absensiList = await DataService.getAbsensiOsisSessions();

      if (!mounted) return;
      setState(() {
        _anggotaList = anggota;
        _kasSessions = kasList;
        _transaksiList = trxList;
        _absensiSessions = absensiList;

        if (_kasSessions.isNotEmpty) {
          if (_selectedKasSession == null) {
            _selectedKasSession = _kasSessions.first;
          } else {
            final idx = _kasSessions.indexWhere((s) => s.id == _selectedKasSession!.id);
            _selectedKasSession = idx != -1 ? _kasSessions[idx] : _kasSessions.first;
          }
        } else {
          _selectedKasSession = null;
        }

        if (_absensiSessions.isNotEmpty) {
          if (_selectedAbsensiSession == null) {
            _selectedAbsensiSession = _absensiSessions.first;
          } else {
            final idx = _absensiSessions.indexWhere((s) => s.id == _selectedAbsensiSession!.id);
            _selectedAbsensiSession = idx != -1 ? _absensiSessions[idx] : _absensiSessions.first;
          }
        } else {
          _selectedAbsensiSession = null;
        }

        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      debugPrint('Error loading Kas OSIS data: $e');
    }
  }

  // ── FITUR IMPOR EXCEL KHUSUS OSIS ──────────────────────────────────────────

  Future<void> _pickAndImportExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final rawBytes = await file.readAsBytes();

      if (rawBytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File Excel kosong atau tidak terbaca.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      if (!mounted) return;
      _showImportOptionsSheet(rawBytes, file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan impor Excel: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImportOptionsSheet(Uint8List bytes, String fileName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final namaKegiatanCtrl = TextEditingController();
    final lokasiCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withAlpha(100),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: NusantaraColors.gold.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NusantaraColors.gold.withAlpha(120)),
                    ),
                    child: const Icon(Icons.table_view_rounded, color: NusantaraColors.gold, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Impor File Excel OSIS',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          fileName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nama Kegiatan / Rapat Sesi Absensi:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: namaKegiatanCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Masukkan nama kegiatan rapat',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Lokasi Kegiatan:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: lokasiCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Masukkan lokasi kegiatan',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Pilihan 1: Buat Sesi Absensi & Update Anggota
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _loading = true);
                  final session = await DataService.importAbsensiOsisFromExcel(
                    bytes,
                    namaKegiatan: namaKegiatanCtrl.text.trim().isNotEmpty
                        ? namaKegiatanCtrl.text.trim()
                        : 'Sesi Absensi OSIS',
                    lokasi: lokasiCtrl.text.trim().isNotEmpty ? lokasiCtrl.text.trim() : 'Ruang OSIS',
                  );
                  await _loadData();
                  if (session != null) {
                    setState(() {
                      _selectedAbsensiSession = session;
                      _tabCtrl.animateTo(1); // Langsung pindah ke tab Absensi
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Berhasil membuat sesi absensi dengan ${session.items.length} anggota OSIS dari Excel!',
                          ),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tidak ada data anggota yang terbaca di file Excel ini.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.white),
                label: const Text('Buat Sesi Absensi Baru dari Excel Ini',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),

              // Tombol Pilihan 2: Perbarui Daftar Anggota OSIS Saja
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _loading = true);
                  final imported = await DataService.importAnggotaOsisFromExcel(bytes);
                  await _loadData();
                  setState(() {
                    _tabCtrl.animateTo(3); // Pindah ke tab Anggota OSIS
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Berhasil mengimpor ${imported.length} anggota OSIS ke sistem!'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.people_outline_rounded),
                label: const Text('Perbarui Daftar Anggota OSIS Saja'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Actions Kas OSIS ────────────────────────────────────────────────────────

  void _centangSemuaKas(bool sudahBayar) {
    if (_selectedKasSession == null || !_canEdit) return;
    setState(() {
      for (final item in _selectedKasSession!.items) {
        item.sudahBayar = sudahBayar;
        if (sudahBayar) {
          item.nominalBayar = _selectedKasSession!.nominalWajib;
          item.tanggalBayar = DateTime.now();
        } else {
          item.nominalBayar = 0;
          item.tanggalBayar = null;
        }
      }
    });
    _simpanKasSession(showToast: false);
  }

  Future<void> _simpanKasSession({bool showToast = true}) async {
    if (_selectedKasSession == null) return;
    try {
      _selectedKasSession!.updatedAt = DateTime.now();
      await DataService.saveKasOsisSession(_selectedKasSession!);

      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Catatan Kas "${_selectedKasSession!.judul}" berhasil disimpan.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan kas: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _hapusSesiKas() async {
    if (!_canEdit || _selectedKasSession == null) return;
    final session = _selectedKasSession!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Sesi Kas?'),
        content: Text('Apakah Anda yakin ingin menghapus sesi "${session.judul}"? Data pembayaran di sesi ini akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DataService.deleteKasOsisSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi kas berhasil dihapus.'), backgroundColor: Colors.red),
        );
      }
      await _loadData();
    }
  }

  void _hapusSesiAbsensi() async {
    if (!_canEdit || _selectedAbsensiSession == null) return;
    final session = _selectedAbsensiSession!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Sesi Presensi?'),
        content: Text('Apakah Anda yakin ingin menghapus sesi presensi "${session.namaKegiatan}"? Data kehadiran di sesi ini akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DataService.deleteAbsensiOsisSession(session.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesi presensi berhasil dihapus.'), backgroundColor: Colors.red),
        );
      }
      await _loadData();
    }
  }

  void _toggleBayarItem(KasOsisItem item) {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mode Lihat Saja: Pengeditan kas hanya diizinkan untuk 7 Pengurus Inti & Pimpinan Sekolah.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      item.sudahBayar = !item.sudahBayar;
      if (item.sudahBayar) {
        item.nominalBayar = _selectedKasSession?.nominalWajib ?? 5000;
        item.tanggalBayar = DateTime.now();
      } else {
        item.nominalBayar = 0;
        item.tanggalBayar = null;
      }
    });
    _simpanKasSession(showToast: false);
  }

  void _showEditNominalDialog(KasOsisItem item) {
    if (!_canEdit) return;
    final nominalCtrl = TextEditingController();
    bool tandaiLunas = item.sudahBayar;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primary = Theme.of(ctx).colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111827) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withAlpha(80),
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
                          color: NusantaraColors.gold.withAlpha(35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: NusantaraColors.gold.withAlpha(100)),
                        ),
                        child: const Icon(Icons.payments_rounded, color: NusantaraColors.gold, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pasang Nominal Iuran Siswa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              '${item.nama} • ${item.kelas}',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Nominal Pembayaran (Rp):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nominalCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      hintText: item.nominalBayar > 0
                          ? 'Masukkan nominal (saat ini: ${_currencyFormat.format(item.nominalBayar)})'
                          : 'Masukkan nominal pembayaran',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Pilihan Cepat:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip('2.000', () {
                        setModalState(() => nominalCtrl.text = '2000');
                      }),
                      _buildPresetChip('5.000', () {
                        setModalState(() => nominalCtrl.text = '5000');
                      }),
                      _buildPresetChip('10.000', () {
                        setModalState(() => nominalCtrl.text = '10000');
                      }),
                      _buildPresetChip('20.000', () {
                        setModalState(() => nominalCtrl.text = '20000');
                      }),
                      _buildPresetChip('Target Penuh (${_selectedKasSession?.nominalWajib ?? 5000})', () {
                        setModalState(() {
                          nominalCtrl.text = (_selectedKasSession?.nominalWajib ?? 5000).toString();
                          tandaiLunas = true;
                        });
                      }, isPrimary: true),
                      _buildPresetChip('Reset (Rp 0)', () {
                        setModalState(() {
                          nominalCtrl.text = '0';
                          tandaiLunas = false;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: tandaiLunas,
                    onChanged: (val) => setModalState(() => tandaiLunas = val ?? false),
                    title: const Text('Tandai sebagai LUNAS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Otomatis mencatat status iuran telah lunas', style: TextStyle(fontSize: 11)),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final rawText = nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                      final nom = rawText.isNotEmpty
                          ? (int.tryParse(rawText) ?? 0)
                          : (tandaiLunas ? (_selectedKasSession?.nominalWajib ?? 5000) : item.nominalBayar);
                      Navigator.pop(ctx);
                      setState(() {
                        item.nominalBayar = nom;
                        item.sudahBayar = tandaiLunas || (_selectedKasSession != null && nom >= _selectedKasSession!.nominalWajib);
                        if (item.sudahBayar) {
                          item.tanggalBayar = DateTime.now();
                        } else if (nom == 0) {
                          item.tanggalBayar = null;
                        }
                      });
                      _simpanKasSession(showToast: true);
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                    label: const Text('Simpan Nominal Kas', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, {bool isPrimary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary ? NusantaraColors.gold.withAlpha(40) : Colors.grey.withAlpha(25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary ? NusantaraColors.gold : Colors.grey.withAlpha(60),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isPrimary ? NusantaraColors.goldDark : null,
          ),
        ),
      ),
    );
  }

  void _ubahNominalWajibSesi() {
    if (_selectedKasSession == null || !_canEdit) return;
    final nominalCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tune_rounded, color: NusantaraColors.gold),
            SizedBox(width: 10),
            Text('Atur Iuran Sesi Kas', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesi: ${_selectedKasSession!.judul}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 12),
            const Text('Nominal Iuran Wajib per Siswa (Rp):', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            TextField(
              controller: nominalCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                isDense: true,
                border: OutlineInputBorder(),
                hintText: 'Masukkan nominal iuran baru',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final newNom = int.tryParse(nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              if (newNom <= 0) return;
              Navigator.pop(ctx);
              setState(() {
                _selectedKasSession!.nominalWajib = newNom;
                for (final item in _selectedKasSession!.items) {
                  item.sudahBayar = item.nominalBayar >= newNom;
                }
              });
              _simpanKasSession(showToast: true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _tambahSesiKasBaru() {
    DateTime selectedDate = DateTime.now();
    final nominalCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: NusantaraColors.gold),
              SizedBox(width: 10),
              Text('Buat Sesi Kas OSIS Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tanggal / Periode Kas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null) {
                    setDialogState(() {
                      selectedDate = picked;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    border: Border.all(color: Colors.grey.withAlpha(120)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_note_rounded, size: 20, color: NusantaraColors.gold),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(selectedDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Periode: Kas Bulan ${DateFormat('MMMM yyyy', 'id_ID').format(selectedDate)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.calendar_today_rounded, size: 16, color: NusantaraColors.gold),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Nominal Iuran Wajib per Anggota (Rp):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: nominalCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixText: 'Rp ',
                  hintText: 'Masukkan nominal iuran (bawaan: ${_currencyFormat.format(AppSettingsService.kasDefaultIuranNotifier.value)})',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final nominal = int.tryParse(nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? AppSettingsService.kasDefaultIuranNotifier.value;
                Navigator.pop(ctx);
                final newId = 'kas-${DateTime.now().millisecondsSinceEpoch}';
                final judul = 'Kas Bulan ${DateFormat('MMMM yyyy', 'id_ID').format(selectedDate)}';
                final items = _anggotaList.map((a) {
                  return KasOsisItem(
                    anggotaId: a.id,
                    nama: a.nama,
                    kelas: a.kelas,
                    jabatan: a.jabatan,
                    nominalBayar: 0,
                    sudahBayar: false,
                  );
                }).toList();

                final newSession = KasOsisSession(
                  id: newId,
                  judul: judul,
                  tanggal: selectedDate,
                  nominalWajib: nominal,
                  items: items,
                  updatedAt: DateTime.now(),
                );

                await DataService.saveKasOsisSession(newSession);
                await _loadData();
                setState(() => _selectedKasSession = newSession);
              },
              child: const Text('Buat Sesi'),
            ),
          ],
        ),
      ),
    );
  }

  void _shareRekapKasWhatsApp() {
    if (_selectedKasSession == null) return;
    final s = _selectedKasSession!;
    final lunas = s.items.where((i) => i.sudahBayar).toList();
    final belum = s.items.where((i) => !i.sudahBayar).toList();

    final buffer = StringBuffer();
    buffer.writeln('[REKAP KAS OSIS - ${s.judul.toUpperCase()}]');
    buffer.writeln('Tanggal: ${_dateFormat.format(s.tanggal)}');
    buffer.writeln('Iuran Wajib: ${_currencyFormat.format(s.nominalWajib)} / anggota');
    buffer.writeln('Terkumpul: *${_currencyFormat.format(s.totalTerkumpul)}* dari target ${_currencyFormat.format(s.totalTarget)} (${s.persentaseBayar.toStringAsFixed(1)}%)\n');

    buffer.writeln('[DAFTAR ANGGOTA SUDAH LUNAS (${lunas.length}/${s.items.length})]:');
    if (lunas.isEmpty) {
      buffer.writeln('(Belum ada anggota yang membayar)');
    } else {
      for (int i = 0; i < lunas.length; i++) {
        buffer.writeln('${i + 1}. ${lunas[i].nama} (${lunas[i].kelas}) - [LUNAS]');
      }
    }

    buffer.writeln('\n[DAFTAR ANGGOTA BELUM MEMBAYAR (${belum.length})]:');
    if (belum.isEmpty) {
      buffer.writeln('(Semua anggota OSIS telah lunas)');
    } else {
      for (int i = 0; i < belum.length; i++) {
        buffer.writeln('${i + 1}. ${belum[i].nama} (${belum[i].kelas})');
      }
    }

    buffer.writeln('\n_Sistem Kas OSIS SMK Bakti Nusantara 666_');

    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Rekap Kas OSIS: ${s.judul}'));
  }

  // ── Actions Absensi OSIS ───────────────────────────────────────────────────

  void _semuaHadirAbsensi() {
    if (_selectedAbsensiSession == null || !_canEdit) return;
    setState(() {
      for (final item in _selectedAbsensiSession!.items) {
        item.status = 'Hadir';
      }
    });
    _simpanAbsensiSession(showToast: false);
  }

  Future<void> _simpanAbsensiSession({bool showToast = true}) async {
    if (_selectedAbsensiSession == null) return;
    try {
      _selectedAbsensiSession!.updatedAt = DateTime.now();
      await DataService.saveAbsensiOsisSession(_selectedAbsensiSession!);

      if (showToast && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Presensi "${_selectedAbsensiSession!.namaKegiatan}" berhasil disimpan.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan presensi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _tambahSesiAbsensiBaru() {
    DateTime selectedDate = DateTime.now();
    final kegiatanCtrl = TextEditingController();
    final lokasiCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.how_to_reg_rounded, color: NusantaraColors.pandanGreen),
              SizedBox(width: 10),
              Text('Buat Sesi Absensi OSIS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TANGGAL KEGIATAN
                const Text('Tanggal Kegiatan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                      border: Border.all(color: Colors.grey.withAlpha(120)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: NusantaraColors.pandanGreen),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(selectedDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 2. NAMA KEGIATAN
                const Text('Nama Kegiatan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: kegiatanCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'Masukkan nama kegiatan rapat',
                  ),
                ),
                const SizedBox(height: 14),

                // 3. LOKASI KEGIATAN
                const Text('Lokasi Kegiatan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: lokasiCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'Masukkan lokasi kegiatan',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Akan memuat ${_anggotaList.length} anggota OSIS resmi.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final kegiatan = kegiatanCtrl.text.trim();
                final lokasi = lokasiCtrl.text.trim();
                if (kegiatan.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nama kegiatan tidak boleh kosong!'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                Navigator.pop(ctx);
                final newId = 'abs-${DateTime.now().millisecondsSinceEpoch}';
                final items = _anggotaList.map((a) {
                  return AbsensiOsisItem(
                    anggotaId: a.id,
                    nama: a.nama,
                    kelas: a.kelas,
                    jabatan: a.jabatan,
                    status: 'Hadir',
                  );
                }).toList();

                final newSession = AbsensiOsisSession(
                  id: newId,
                  namaKegiatan: kegiatan,
                  tanggal: selectedDate,
                  lokasi: lokasi.isNotEmpty ? lokasi : 'Ruang OSIS',
                  items: items,
                  updatedAt: DateTime.now(),
                );

                await DataService.saveAbsensiOsisSession(newSession);
                await _loadData();
                setState(() => _selectedAbsensiSession = newSession);
              },
              child: const Text('Mulai Absensi'),
            ),
          ],
        ),
      ),
    );
  }

  void _shareRekapAbsensiWhatsApp() {
    if (_selectedAbsensiSession == null) return;
    final s = _selectedAbsensiSession!;
    final buffer = StringBuffer();
    buffer.writeln('[PRESENSI KEGIATAN OSIS]');
    buffer.writeln('Kegiatan: *${s.namaKegiatan}*');
    buffer.writeln('Tanggal: ${_dateFormat.format(s.tanggal)}');
    buffer.writeln('Lokasi: ${s.lokasi}');
    buffer.writeln('Tingkat Kehadiran: *${s.persentaseHadir.toStringAsFixed(1)}%* (Hadir: ${s.totalHadir}, Izin: ${s.totalIzin}, Sakit: ${s.totalSakit}, Alpa: ${s.totalAlpa})\n');

    buffer.writeln('[RINCIAN KEHADIRAN ANGGOTA]:');
    for (int i = 0; i < s.items.length; i++) {
      final it = s.items[i];
      buffer.writeln('${i + 1}. [${it.status.toUpperCase()}] ${it.nama} (${it.kelas} - ${it.jabatan})');
    }

    buffer.writeln('\n_Dicatat melalui Jurnal OSIS Digital SMK Bakti Nusantara 666_');
    SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: 'Presensi OSIS: ${s.namaKegiatan}'));
  }

  // ── Actions Buku Kas & Transaksi ───────────────────────────────────────────

  void _tambahTransaksiBaru([String initialJenis = 'MASUK']) {
    final jenisCtrl = ValueNotifier<String>(initialJenis);
    final nominalCtrl = TextEditingController();
    final ketCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  jenisCtrl.value == 'MASUK' ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: jenisCtrl.value == 'MASUK' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 10),
                Text(
                  jenisCtrl.value == 'MASUK' ? 'Catat Pemasukan Kas' : 'Catat Pengeluaran Kas',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: ValueListenableBuilder<String>(
                valueListenable: jenisCtrl,
                builder: (context, jenis, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Toggle Masuk / Keluar
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Pemasukan (+)')),
                              selected: jenis == 'MASUK',
                              selectedColor: const Color(0xFF10B981).withAlpha(50),
                              labelStyle: TextStyle(
                                color: jenis == 'MASUK' ? const Color(0xFF059669) : null,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  jenisCtrl.value = 'MASUK';
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('Pengeluaran (-)')),
                              selected: jenis == 'KELUAR',
                              selectedColor: const Color(0xFFEF4444).withAlpha(50),
                              labelStyle: TextStyle(
                                color: jenis == 'KELUAR' ? const Color(0xFFDC2626) : null,
                                fontWeight: FontWeight.bold,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  jenisCtrl.value = 'KELUAR';
                                  setDialogState(() {});
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Nominal
                      const Text('Nominal (Rp):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nominalCtrl,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          prefixText: 'Rp ',
                          hintText: 'Masukkan nominal',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Keterangan
                      const Text('Keterangan:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ketCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          isDense: true,
                          border: const OutlineInputBorder(),
                          hintText: jenis == 'MASUK'
                              ? 'Masukkan keterangan pemasukan'
                              : 'Masukkan keterangan pengeluaran',
                          hintStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () async {
                  final nom = int.tryParse(nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                  final ket = ketCtrl.text.trim();
                  if (nom <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Nominal harus lebih dari Rp 0!'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  if (ket.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Keterangan tidak boleh kosong!'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final trx = KasOsisTransaksi(
                    id: 'trx-${DateTime.now().millisecondsSinceEpoch}',
                    tanggal: DateTime.now(),
                    jenis: jenisCtrl.value,
                    judul: ket,
                    nominal: nom,
                    keterangan: ket,
                    kategori: jenisCtrl.value == 'MASUK' ? 'Pemasukan' : 'Pengeluaran',
                    penanggungJawab: widget.username,
                  );

                  await DataService.addKasTransaksi(trx);
                  await _loadData();

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Catatan ${trx.jenis == 'MASUK' ? 'Pemasukan' : 'Pengeluaran'} Rp $nom berhasil disimpan!'),
                        backgroundColor: const Color(0xFF059669),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: jenisCtrl.value == 'MASUK' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Simpan Transaksi'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _hapusTransaksi(KasOsisTransaksi trx) {
    if (!_isBendahara) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Hapus Transaksi Kas', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Text(
          'Hapus catatan "${trx.keterangan}" (${trx.jenis == 'MASUK' ? '+' : '-'} ${_currencyFormat.format(trx.nominal)}) dari buku kas?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await DataService.deleteKasTransaksi(trx.id);
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaksi berhasil dihapus.'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  // ── Actions Anggota OSIS ───────────────────────────────────────────────────

  void _tambahAnggotaManual() {
    final namaCtrl = TextEditingController();
    final kelasCtrl = TextEditingController();
    final jabatanCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: NusantaraColors.batikNavy),
            SizedBox(width: 10),
            Text('Tambah Anggota OSIS', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nama Lengkap Siswa:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: namaCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Masukkan nama lengkap siswa',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Kelas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: kelasCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Masukkan kelas siswa',
                ),
              ),
              const SizedBox(height: 12),
              const Text('Jabatan / Sekbid:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: jabatanCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  hintText: 'Masukkan jabatan atau sekbid',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final nama = namaCtrl.text.trim();
              if (nama.isEmpty) return;

              Navigator.pop(ctx);
              final newAnggota = AnggotaOsis(
                id: 'ang-${DateTime.now().millisecondsSinceEpoch}',
                nama: nama,
                kelas: kelasCtrl.text.trim(),
                nis: '-',
                jabatan: jabatanCtrl.text.trim(),
              );

              await DataService.addAnggotaOsis(newAnggota);
              await _loadData();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // ── BUILD UTAMA SCREEN ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              indicatorColor: NusantaraColors.gold,
              indicatorWeight: 3,
              labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
              unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.check_box_outlined, size: 18),
                  text: 'Ceklis Kas Bendahara',
                ),
                Tab(
                  icon: Icon(Icons.how_to_reg_rounded, size: 18),
                  text: 'Absensi OSIS',
                ),
                Tab(
                  icon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                  text: 'Buku Kas & Saldo',
                ),
                Tab(
                  icon: Icon(Icons.groups_rounded, size: 18),
                  text: 'Anggota OSIS',
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (!_canEdit)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFEF3C7),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode Lihat Saja: Anda dapat melihat seluruh data kas & absensi. Pengeditan hanya diizinkan untuk 7 Inti & Pimpinan Sekolah.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: NusantaraColors.gold,
                        child: _buildTabKasChecklist(theme, isDark, primary),
                      ),
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: NusantaraColors.pandanGreen,
                        child: _buildTabAbsensi(theme, isDark, primary),
                      ),
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: NusantaraColors.batikNavy,
                        child: _buildTabBukuKas(theme, isDark, primary),
                      ),
                      RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: NusantaraColors.gold,
                        child: _buildTabAnggota(theme, isDark, primary),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── TAB 1: CEKLIS KAS BENDAHARA (DENGAN TOMBOL ABSENSI) ─────────────────────

  Widget _buildTabKasChecklist(ThemeData theme, bool isDark, Color primary) {
    if (_selectedKasSession == null) {
      return LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Belum ada sesi kas aktif.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _tambahSesiKasBaru,
                    icon: const Icon(Icons.add),
                    label: const Text('Buat Sesi Kas Pertama'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final session = _selectedKasSession!;
    final items = session.items;

    final filteredItems = items.where((i) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = i.nama.toLowerCase().contains(q) ||
            i.kelas.toLowerCase().contains(q) ||
            i.jabatan.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_kasFilter == 'LUNAS') return i.sudahBayar;
      if (_kasFilter == 'BELUM') return !i.sudahBayar;
      return true;
    }).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Ringkas & Terpadu: Sesi, Iuran, Aksi Cepat
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 30 : 6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Baris 1: Pemilih Sesi Kas & Tombol Aksi Cepat
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 0.8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: session.id,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                items: _kasSessions.map((s) {
                                  return DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(
                                      '${s.judul} (${_currencyFormat.format(s.nominalWajib)})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() {
                                      _selectedKasSession = _kasSessions.firstWhere((s) => s.id == id);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.tune_rounded, size: 18, color: NusantaraColors.gold),
                          tooltip: 'Atur Iuran Sesi',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: _ubahNominalWajibSesi,
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.upload_file_rounded, size: 18, color: NusantaraColors.gold),
                          tooltip: 'Impor Excel',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: _pickAndImportExcel,
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.share_rounded, size: 18),
                          tooltip: 'Bagikan WA',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: _shareRekapKasWhatsApp,
                        ),
                        if (_canEdit) ...[
                          const SizedBox(width: 4),
                          IconButton.filled(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            tooltip: 'Buat Sesi Baru',
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                            onPressed: _tambahSesiKasBaru,
                          ),
                          if (_selectedKasSession != null) ...[
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                              tooltip: 'Hapus Sesi Kas',
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: _hapusSesiKas,
                            ),
                          ],
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Tanggal Sesi Kas
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(session.tanggal),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Iuran: ${_currencyFormat.format(session.nominalWajib)}/siswa',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: NusantaraColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Baris 2: Indikator Keuangan Ringkas & Progress Bar
                    Row(
                      children: [
                        Text(
                          _currencyFormat.format(session.totalTerkumpul),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        Text(
                          ' / ${_currencyFormat.format(session.totalTarget)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${session.totalLunas}/${session.items.length} Lunas (${session.persentaseBayar.toStringAsFixed(0)}%)',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (session.persentaseBayar / 100).clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Baris 3: Filter Cepat Lunas/Belum & Tombol Cepat Presensi OSIS
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('Semua (${items.length})', _kasFilter == 'ALL', () {
                                  setState(() => _kasFilter = 'ALL');
                                }, isDark),
                                const SizedBox(width: 5),
                                _buildFilterChip('Lunas (${session.totalLunas})', _kasFilter == 'LUNAS', () {
                                  setState(() => _kasFilter = 'LUNAS');
                                }, isDark, activeCol: const Color(0xFF10B981)),
                                const SizedBox(width: 5),
                                _buildFilterChip('Belum (${items.length - session.totalLunas})', _kasFilter == 'BELUM', () {
                                  setState(() => _kasFilter = 'BELUM');
                                }, isDark, activeCol: Colors.redAccent),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _tabCtrl.animateTo(1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: NusantaraColors.batikNavy.withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NusantaraColors.batikNavy.withAlpha(120), width: 0.9),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.how_to_reg_rounded, size: 13, color: NusantaraColors.batikNavy),
                                SizedBox(width: 4),
                                Text('Presensi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: NusantaraColors.batikNavy)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Toolbar (Pencarian & Centang Cepat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Masukkan nama atau kelas untuk mencari...',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.search, size: 17),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 15),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_canEdit) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _centangSemuaKas(true),
                        icon: const Icon(Icons.done_all, size: 15, color: Color(0xFF10B981)),
                        label: const Text('Lunas Semua', style: TextStyle(fontSize: 11)),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                      ),
                      TextButton(
                        onPressed: () => _centangSemuaKas(false),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                        child: const Text('Batal Semua', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Daftar Anggota dengan Ceklis Kas - Full Page Scrollable
        if (filteredItems.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('Tidak ada anggota sesuai filter.', style: TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final item = filteredItems[idx];
                  return _buildKasMemberCard(item, session, isDark, primary);
                },
                childCount: filteredItems.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap, bool isDark, {Color? activeCol}) {
    final col = activeCol ?? NusantaraColors.gold;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? col : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? col : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
        ),
      ),
    );
  }

  Widget _buildKasMemberCard(KasOsisItem item, KasOsisSession session, bool isDark, Color primary) {
    final isLunas = item.sudahBayar;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLunas
              ? const Color(0xFF10B981).withAlpha(140)
              : (isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0)),
          width: isLunas ? 1.5 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleBayarItem(item),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // 1. AREA CEKLIS BESAR & LEGA (Touch target 52x52 dp, ikon 28dp)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isLunas
                        ? const Color(0xFF10B981).withAlpha(isDark ? 45 : 30)
                        : Colors.grey.withAlpha(isDark ? 30 : 20),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isLunas ? const Color(0xFF10B981) : Colors.grey.withAlpha(100),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      isLunas ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isLunas ? const Color(0xFF10B981) : Colors.grey,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. DATA SISWA & DISPLAY NOMINAL BAYAR
                Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nama,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          item.kelas,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: NusantaraColors.gold.withAlpha(isDark ? 35 : 20),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: NusantaraColors.gold.withAlpha(120),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          item.jabatan,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? NusantaraColors.goldLight : NusantaraColors.goldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Display Nominal Bayar vs Target
                  Row(
                    children: [
                      Text(
                        'Bayar: ${_currencyFormat.format(item.nominalBayar)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isLunas ? const Color(0xFF10B981) : Colors.redAccent,
                        ),
                      ),
                      Text(
                        ' / ${_currencyFormat.format(session.nominalWajib)}',
                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // 3. STATUS BADGE & TOMBOL PASANG / UBAH NOMINAL
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isLunas
                        ? const Color(0xFF10B981).withAlpha(isDark ? 40 : 25)
                        : Colors.red.withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLunas ? const Color(0xFF10B981) : Colors.red.withAlpha(120),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isLunas ? 'Lunas' : 'Belum Lunas',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isLunas ? const Color(0xFF10B981) : Colors.red,
                    ),
                  ),
                ),
                if (_canEdit) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showEditNominalDialog(item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: NusantaraColors.gold.withAlpha(isDark ? 35 : 20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: NusantaraColors.gold.withAlpha(120), width: 0.9),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_outlined, size: 13, color: NusantaraColors.gold),
                          SizedBox(width: 4),
                          Text(
                            'Pasang Rp',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: NusantaraColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  // ── TAB 2: ABSENSI OSIS (PER NAMA SISWA ANGGOTA OSIS) ──────────────────────

  Widget _buildTabAbsensi(ThemeData theme, bool isDark, Color primary) {
    if (_selectedAbsensiSession == null) {
      return LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.how_to_reg_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Belum ada sesi presensi rapat OSIS.'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _tambahSesiAbsensiBaru,
                        icon: const Icon(Icons.add),
                        label: const Text('Buat Sesi Manual'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickAndImportExcel,
                        icon: const Icon(Icons.table_view_rounded, color: NusantaraColors.gold),
                        label: const Text('Impor dari Excel'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final session = _selectedAbsensiSession!;
    final items = session.items;

    final filteredItems = items.where((i) {
      if (_absenFilter != 'ALL' && i.status.toUpperCase() != _absenFilter.toUpperCase()) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return i.nama.toLowerCase().contains(q) ||
          i.kelas.toLowerCase().contains(q) ||
          i.jabatan.toLowerCase().contains(q);
    }).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Ringkas & Terpadu Presensi Rapat OSIS
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 30 : 6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Baris 1: Dropdown Sesi Presensi & Tombol Aksi Cepat
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 0.8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: session.id,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                items: _absensiSessions.map((s) {
                                  return DropdownMenuItem<String>(
                                    value: s.id,
                                    child: Text(
                                      '${s.namaKegiatan} (${s.tanggal.day}/${s.tanggal.month}/${s.tanggal.year})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (id) {
                                  if (id != null) {
                                    setState(() {
                                      _selectedAbsensiSession = _absensiSessions.firstWhere((s) => s.id == id);
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.upload_file_rounded, size: 18, color: NusantaraColors.gold),
                          tooltip: 'Impor Excel',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: _pickAndImportExcel,
                        ),
                        const SizedBox(width: 4),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.share_rounded, size: 18),
                          tooltip: 'Bagikan WA',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: _shareRekapAbsensiWhatsApp,
                        ),
                        if (_canEdit) ...[
                          const SizedBox(width: 4),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.save_rounded, size: 18, color: Color(0xFF10B981)),
                            tooltip: 'Simpan Presensi',
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                            onPressed: () => _simpanAbsensiSession(),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filled(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            tooltip: 'Buat Sesi Baru',
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            padding: EdgeInsets.zero,
                            onPressed: _tambahSesiAbsensiBaru,
                          ),
                          if (_selectedAbsensiSession != null) ...[
                            const SizedBox(width: 4),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                              tooltip: 'Hapus Sesi Presensi',
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                              onPressed: _hapusSesiAbsensi,
                            ),
                          ],
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Detail Sesi: Tanggal & Lokasi Kegiatan
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 5),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(session.tanggal),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.place_outlined, size: 13, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 4),
                          Text(
                            session.lokasi.isNotEmpty ? session.lokasi : 'Ruang OSIS',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Baris 2: Indikator Kehadiran (Hadir, Izin, Sakit, Alpa) + Tombol Cepat Semua Hadir
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildAbsenMetric('Hadir', session.totalHadir, const Color(0xFF10B981)),
                              _buildAbsenMetric('Izin', session.totalIzin, const Color(0xFF3B82F6)),
                              _buildAbsenMetric('Sakit', session.totalSakit, const Color(0xFFF59E0B)),
                              _buildAbsenMetric('Alpa', session.totalAlpa, const Color(0xFFEF4444)),
                            ],
                          ),
                        ),
                        if (_canEdit) ...[
                          const SizedBox(width: 6),
                          TextButton.icon(
                            onPressed: _semuaHadirAbsensi,
                            icon: const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF10B981)),
                            label: const Text('Semua Hadir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Baris 3: Filter Chip Kehadiran & Shortcut ke Kas OSIS
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip('Semua (${session.items.length})', _absenFilter == 'ALL', () {
                                  setState(() => _absenFilter = 'ALL');
                                }, isDark),
                                const SizedBox(width: 5),
                                _buildFilterChip('Hadir (${session.totalHadir})', _absenFilter == 'Hadir', () {
                                  setState(() => _absenFilter = 'Hadir');
                                }, isDark, activeCol: const Color(0xFF10B981)),
                                const SizedBox(width: 5),
                                _buildFilterChip('Izin (${session.totalIzin})', _absenFilter == 'Izin', () {
                                  setState(() => _absenFilter = 'Izin');
                                }, isDark, activeCol: const Color(0xFF3B82F6)),
                                const SizedBox(width: 5),
                                _buildFilterChip('Sakit (${session.totalSakit})', _absenFilter == 'Sakit', () {
                                  setState(() => _absenFilter = 'Sakit');
                                }, isDark, activeCol: const Color(0xFFF59E0B)),
                                const SizedBox(width: 5),
                                _buildFilterChip('Alpa (${session.totalAlpa})', _absenFilter == 'Alpa', () {
                                  setState(() => _absenFilter = 'Alpa');
                                }, isDark, activeCol: const Color(0xFFEF4444)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _tabCtrl.animateTo(0),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: NusantaraColors.gold.withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NusantaraColors.gold.withAlpha(120), width: 0.9),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance_wallet_rounded, size: 13, color: NusantaraColors.gold),
                                SizedBox(width: 4),
                                Text('Ceklis Kas', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: NusantaraColors.gold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Search Bar Siswa Presensi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama atau jabatan untuk mencari presensi...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 17),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 15),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Daftar Siswa Anggota OSIS untuk Presensi - Full Page Scrollable
        if (filteredItems.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.withAlpha(120)),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Tidak ada siswa cocok dengan "$_searchQuery"'
                          : 'Tidak ada data presensi dengan status $_absenFilter',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final item = filteredItems[idx];
                  return _buildAbsenStudentCard(item, session, isDark);
                },
                childCount: filteredItems.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAbsenMetric(String label, int count, Color color) {
    final isSelected = _absenFilter == label;
    return InkWell(
      onTap: () {
        setState(() {
          _absenFilter = isSelected ? 'ALL' : label;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: isSelected ? 2.2 : 1.5),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withAlpha(90),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsenStudentCard(
    AbsensiOsisItem item,
    AbsensiOsisSession session,
    bool isDark,
  ) {
    const statuses = ['Hadir', 'Izin', 'Sakit', 'Alpa'];
    final colors = {
      'Hadir': const Color(0xFF059669),
      'Izin': const Color(0xFF0284C7),
      'Sakit': const Color(0xFFD97706),
      'Alpa': const Color(0xFFDC2626),
    };
    final statusIcons = {
      'Hadir': Icons.check_rounded,
      'Izin': Icons.article_outlined,
      'Sakit': Icons.healing_outlined,
      'Alpa': Icons.close_rounded,
    };

    final activeColor = colors[item.status] ?? Colors.grey;
    final activeIcon = statusIcons[item.status] ?? Icons.help_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: activeColor.withAlpha(120),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 25 : 6),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: NusantaraColors.batikNavy.withAlpha(isDark ? 50 : 25),
                  child: Text(
                    item.nama.isNotEmpty ? item.nama[0] : 'S',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: NusantaraColors.batikNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NAMA SISWA UTAMA
                      Text(
                        item.nama,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              item.kelas,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: NusantaraColors.gold.withAlpha(isDark ? 35 : 20),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: NusantaraColors.gold.withAlpha(120),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              item.jabatan,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? NusantaraColors.goldLight : NusantaraColors.goldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status Badge Aktif
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: activeColor.withAlpha(isDark ? 40 : 25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: activeColor.withAlpha(130), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(activeIcon, size: 13, color: activeColor),
                      const SizedBox(width: 4),
                      Text(
                        item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: activeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segmented Status Selector: H, I, S, A
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: statuses.map((st) {
                  final isSelected = item.status == st;
                  final col = colors[st]!;
                  final icon = statusIcons[st]!;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: InkWell(
                        onTap: !_canEdit
                            ? null
                            : () {
                                setState(() {
                                  item.status = st;
                                });
                                _simpanAbsensiSession(showToast: false);
                              },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? col : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: col.withAlpha(80),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                icon,
                                size: 15,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white60 : const Color(0xFF475569)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                st,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 3: BUKU KAS & SALDO KESELURUHAN ─────────────────────────────────────

  Widget _buildTabBukuKas(ThemeData theme, bool isDark, Color primary) {
    int totalMasuk = 0;
    int totalKeluar = 0;

    for (final s in _kasSessions) {
      totalMasuk += s.totalTerkumpul;
    }
    for (final t in _transaksiList) {
      if (t.jenis == 'MASUK') {
        totalMasuk += t.nominal;
      } else {
        totalKeluar += t.nominal;
      }
    }
    final saldoSaatIni = totalMasuk - totalKeluar;

    final filteredTrx = _transaksiList.where((t) {
      if (_bukuKasFilter == 'MASUK') return t.jenis == 'MASUK';
      if (_bukuKasFilter == 'KELUAR') return t.jenis == 'KELUAR';
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Saldo Kas Utama
          MegaMendungCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.account_balance_rounded, size: 20, color: NusantaraColors.gold),
                    SizedBox(width: 8),
                    Text(
                      'SALDO KAS OSIS SAAT INI',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _currencyFormat.format(saldoSaatIni),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: saldoSaatIni >= 0 ? const Color(0xFF10B981) : Colors.red,
                  ),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Kas Masuk', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormat.format(totalMasuk),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Kas Keluar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 2),
                          Text(
                            _currencyFormat.format(totalKeluar),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Catat Pemasukan & Pengeluaran Berdampingan
          if (_isBendahara)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _tambahTransaksiBaru('MASUK'),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                    label: const Text('Catat Pemasukan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _tambahTransaksiBaru('KELUAR'),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                    label: const Text('Catat Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 18),

          // Riwayat Transaksi Manual dengan Filter Chips
          Row(
            children: [
              const Text('Riwayat Mutasi:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              ChoiceChip(
                label: Text('Semua (${_transaksiList.length})'),
                selected: _bukuKasFilter == 'ALL',
                labelStyle: const TextStyle(fontSize: 11),
                onSelected: (val) {
                  if (val) setState(() => _bukuKasFilter = 'ALL');
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: Text('Masuk (${_transaksiList.where((t) => t.jenis == 'MASUK').length})'),
                selected: _bukuKasFilter == 'MASUK',
                selectedColor: const Color(0xFF10B981).withAlpha(40),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: _bukuKasFilter == 'MASUK' ? const Color(0xFF059669) : null,
                  fontWeight: _bukuKasFilter == 'MASUK' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) setState(() => _bukuKasFilter = 'MASUK');
                },
              ),
              const SizedBox(width: 4),
              ChoiceChip(
                label: Text('Keluar (${_transaksiList.where((t) => t.jenis == 'KELUAR').length})'),
                selected: _bukuKasFilter == 'KELUAR',
                selectedColor: const Color(0xFFEF4444).withAlpha(40),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: _bukuKasFilter == 'KELUAR' ? const Color(0xFFDC2626) : null,
                  fontWeight: _bukuKasFilter == 'KELUAR' ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (val) {
                  if (val) setState(() => _bukuKasFilter = 'KELUAR');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (filteredTrx.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 36, color: Colors.grey.withAlpha(120)),
                    const SizedBox(height: 8),
                    Text(
                      _bukuKasFilter == 'ALL'
                          ? 'Belum ada catatan mutasi kas.'
                          : 'Belum ada transaksi ${_bukuKasFilter.toLowerCase()}.',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            ...filteredTrx.map((t) {
              final isMasuk = t.jenis == 'MASUK';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  leading: CircleAvatar(
                    radius: 17,
                    backgroundColor: isMasuk
                        ? const Color(0xFF10B981).withAlpha(30)
                        : Colors.red.withAlpha(30),
                    child: Icon(
                      isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      color: isMasuk ? const Color(0xFF10B981) : Colors.red,
                      size: 19,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.keterangan,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (t.kategori.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: primary.withAlpha(60), width: 0.8),
                          ),
                          child: Text(
                            t.kategori,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primary),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${_dateFormat.format(t.tanggal)} • PJ: ${t.penanggungJawab}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isMasuk ? '+' : '-'} ${_currencyFormat.format(t.nominal)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isMasuk ? const Color(0xFF10B981) : Colors.red,
                        ),
                      ),
                      if (_isBendahara) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                          tooltip: 'Hapus transaksi',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _hapusTransaksi(t),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ── TAB 4: ANGGOTA OSIS (DENGAN NAMA SISWA RESMI & IMPORT EXCEL) ───────────

  Widget _buildTabAnggota(ThemeData theme, bool isDark, Color primary) {
    final filtered = _anggotaList.where((a) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return a.nama.toLowerCase().contains(q) ||
          a.kelas.toLowerCase().contains(q) ||
          a.jabatan.toLowerCase().contains(q);
    }).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Ringkas Anggota OSIS
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 30 : 6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: NusantaraColors.batikNavy.withAlpha(isDark ? 50 : 25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.groups_rounded, color: NusantaraColors.batikNavy, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daftar Anggota & Pengurus OSIS',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          Text(
                            'Total ${_anggotaList.length} siswa resmi terdaftar',
                            style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.upload_file_rounded, size: 18, color: NusantaraColors.gold),
                      tooltip: 'Impor Excel',
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      padding: EdgeInsets.zero,
                      onPressed: _pickAndImportExcel,
                    ),
                    if (_canEdit) ...[
                      const SizedBox(width: 4),
                      IconButton.filled(
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        tooltip: 'Tambah Anggota',
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        onPressed: _tambahAnggotaManual,
                      ),
                    ],
                  ],
                ),
              ),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama atau jabatan anggota OSIS...',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 17),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 15),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'Tidak ada anggota OSIS cocok dengan "$_searchQuery"'
                      : 'Belum ada anggota OSIS terdaftar.',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final item = filtered[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: NusantaraColors.batikNavy.withAlpha(35),
                        child: Text(
                          item.nama.isNotEmpty ? item.nama[0] : 'O',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: NusantaraColors.batikNavy),
                        ),
                      ),
                      title: Text(item.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text('${item.kelas} • ${item.jabatan}', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                      trailing: _canEdit
                          ? IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              tooltip: 'Hapus Anggota',
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Hapus Anggota OSIS?'),
                                    content: Text('Hapus ${item.nama} dari daftar anggota OSIS?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await DataService.deleteAnggotaOsis(item.id);
                                  await _loadData();
                                }
                              },
                            )
                          : null,
                    ),
                  );
                },
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }
}
