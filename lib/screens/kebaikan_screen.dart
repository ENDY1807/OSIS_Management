import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/app_settings_service.dart';
import '../services/localization_service.dart';
import '../widgets/dynamic_form_field_builder.dart';
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
  String? _filterSiswaId;
  DateTime _selectedDate = _today();
  final _filterCtrl = TextEditingController();
  final _filterFocus = FocusNode();
  bool _loading = true;
  StreamSubscription<String>? _dataSub;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _selectedDate == _today();
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
    _filterCtrl.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: _today(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _filterSiswaId = null;
        _filterCtrl.clear();
      });
    }
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

  List<CatatanKebaikan> get _filteredByDate => _kebaikan.where((k) =>
      k.tanggal.year == _selectedDate.year &&
      k.tanggal.month == _selectedDate.month &&
      k.tanggal.day == _selectedDate.day).toList();

  List<CatatanKebaikan> get _filtered =>
      _filterSiswaId == null ? _filteredByDate : _filteredByDate.where((k) => k.siswaId == _filterSiswaId).toList();

  String _namaSiswa(String id, [CatatanKebaikan? fallback]) {
    final found = _siswa.where((s) => s.id == id);
    if (found.isNotEmpty) return found.first.nama;
    return fallback?.namaSiswa ?? '(Siswa dihapus)';
  }

  String _kelasSiswa(String id, [CatatanKebaikan? fallback]) {
    final found = _siswa.where((s) => s.id == id);
    if (found.isNotEmpty) return found.first.kelas;
    return fallback?.kelasSiswa ?? '-';
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

    final configuredFields = AppSettingsService.customFieldsNotifier.value['kebaikan'] ?? [
      AppCustomInputField(id: 'keb_siswa', label: 'Nama Siswa', type: InputFieldType.select, isRequired: true),
      AppCustomInputField(id: 'keb_tgl', label: 'Tanggal Pencatatan', type: InputFieldType.date, isRequired: true),
      AppCustomInputField(id: 'keb_kategori', label: 'Kategori Kebaikan', type: InputFieldType.dropdown, options: ['Kedisiplinan & Kejujuran', 'Kepedulian Sosial & Gotong Royong', 'Prestasi & Keaktifan', 'Inisiatif Positif', 'Religius & Akhlak Terpuji', 'Lainnya']),
      AppCustomInputField(id: 'keb_ket', label: 'Uraian Catatan Kebaikan', type: InputFieldType.text, placeholder: 'Masukkan catatan kebaikan siswa...', isRequired: true),
      AppCustomInputField(id: 'keb_poin', label: 'Poin Apresiasi', type: InputFieldType.number, placeholder: 'Contoh: 10'),
    ];

    final Map<String, TextEditingController> controllers = {};
    final Map<String, dynamic> dynamicValues = {};

    controllers['keb_ket'] = TextEditingController(
      text: existing != null
          ? (existing.keterangan.isNotEmpty ? existing.keterangan : existing.judul)
          : '',
    );
    controllers['keb_poin'] = TextEditingController(
      text: existing != null && existing.poin > 0 ? existing.poin.toString() : '',
    );
    dynamicValues['keb_tgl'] = existing?.tanggal ?? _selectedDate;
    dynamicValues['keb_kategori'] = existing?.kategori ?? 'Kedisiplinan & Kejujuran';

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

                // Dynamic Form Fields sesuai Konfigurasi Admin Settings
                ...configuredFields.map((field) {
                  if (field.id == 'keb_siswa') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${field.label}${field.isRequired ? ' *' : ''}',
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
                      ],
                    );
                  }

                  if (field.id == 'keb_ket') {
                    controllers.putIfAbsent(field.id, () => TextEditingController());
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${field.label}${field.isRequired ? ' *' : ''}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: controllers['keb_ket'],
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: field.placeholder.isNotEmpty
                                ? field.placeholder
                                : 'Masukkan tindakan atau kebaikan yang dilakukan siswa...',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 40),
                              child: Icon(Icons.edit_note_rounded, color: Color(0xFF10B981)),
                            ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  }

                  if (field.id == 'keb_tgl') {
                    final curDate = dynamicValues['keb_tgl'] is DateTime
                        ? dynamicValues['keb_tgl'] as DateTime
                        : DateTime.now();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
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
                                  Text(
                                    field.label,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(curDate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: curDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setModal(() {
                                    dynamicValues['keb_tgl'] = picked;
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Ubah Tanggal',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return DynamicFormFieldBuilder.buildField(
                    context: context,
                    field: field,
                    isDark: isDark,
                    controllers: controllers,
                    dynamicValues: dynamicValues,
                    setModalState: setModal,
                  );
                }),
                const SizedBox(height: 8),

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
                          final ket = (controllers['keb_ket']?.text ?? '').trim();
                          if (ket.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Keterangan kebaikan tidak boleh kosong!'),
                              backgroundColor: Colors.orange,
                            ));
                            return;
                          }

                          setModal(() => isSaving = true);

                          final tanggal = dynamicValues['keb_tgl'] is DateTime
                              ? dynamicValues['keb_tgl'] as DateTime
                              : DateTime.now();
                          final kategori = dynamicValues['keb_kategori']?.toString() ?? 'Kebaikan';
                          final poin = int.tryParse(controllers['keb_poin']?.text.trim() ?? '0') ?? 0;

                          final catatan = CatatanKebaikan(
                            id: existing?.id ?? const Uuid().v4(),
                            siswaId: selectedSiswa!.id,
                            judul: ket,
                            kategori: kategori,
                            poin: poin,
                            tanggal: tanggal,
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
                      : const Text(
                          'Simpan',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final cardBg = isDark ? const Color(0xFF141D2E) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0);
    final textTitle = isDark ? Colors.white : kTextDark;
    final textSub = isDark ? const Color(0xFF94A3B8) : kTextMid;
    final textMuted = isDark ? const Color(0xFF64748B) : kTextLight;
    const kebaikanGreen = Color(0xFF059669);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // ── Date picker header (sama dengan Pencatatan Pelanggaran) ──
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1424) : kPrimaryDark,
                  border: isDark ? const Border(bottom: BorderSide(color: Color(0xFF243452))) : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      DateFormat('EEEE, dd MMMM yyyy', LocalizationService.currentLocale.value.languageCode).format(_selectedDate),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                        _filterSiswaId = null;
                        _filterCtrl.clear();
                      }),
                      child: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: _isToday ? null : () => setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 1));
                        _filterSiswaId = null;
                        _filterCtrl.clear();
                      }),
                      child: Icon(Icons.chevron_right,
                          color: _isToday ? Colors.white38 : Colors.white),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _load,
                      child: const Icon(Icons.refresh, color: Colors.white, size: 20),
                    ),
                  ]),
                ]),
              ),
            ),

            // ── Search filter siswa ──
            if (_filteredByDate.isNotEmpty)
              Container(
                color: isDark ? const Color(0xFF141D2E) : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _siswa.isEmpty
                    ? const SizedBox.shrink()
                    : RawAutocomplete<Siswa>(
                        textEditingController: _filterCtrl,
                        focusNode: _filterFocus,
                        displayStringForOption: (s) => '${s.nama} - ${s.kelas}',
                        optionsBuilder: (v) {
                          final idsWithRecords = _filteredByDate.map((k) => k.siswaId).toSet();
                          final available = _siswa.where((s) => idsWithRecords.contains(s.id)).toList();
                          if (v.text.isEmpty) return available;
                          final q = v.text.toLowerCase();
                          return available.where((s) =>
                            s.nama.toLowerCase().contains(q) ||
                            s.nis.toLowerCase().contains(q) ||
                            s.kelas.toLowerCase().contains(q));
                        },
                        onSelected: (v) => setState(() => _filterSiswaId = v.id),
                        fieldViewBuilder: (_, ctrl, fn, onSubmit) => TextField(
                          controller: ctrl,
                          focusNode: fn,
                          onTapOutside: (_) => fn.unfocus(),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Cari siswa yang tercatat kebaikan...',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : Colors.black38),
                            prefixIcon: const Icon(Icons.search, size: 20, color: kebaikanGreen),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            suffixIcon: _filterSiswaId != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => setState(() {
                                      _filterSiswaId = null;
                                      _filterCtrl.clear();
                                    }),
                                  )
                                : null,
                          ),
                        ),
                        optionsViewBuilder: (_, onSel, options) => Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 380),
                              child: ListView(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                children: options.map((s) => ListTile(
                                  dense: true,
                                  title: Text(s.nama, style: const TextStyle(fontSize: 13)),
                                  subtitle: Text('${s.kelas} • NIS: ${s.nis}',
                                      style: const TextStyle(fontSize: 11)),
                                  onTap: () => onSel(s),
                                )).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

            // ── Summary bar ──
            if (_filtered.isNotEmpty)
              Container(
                color: isDark ? const Color(0xFF1A263D) : kebaikanGreen,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _filterSiswaId == null
                          ? '${_filtered.map((k) => k.siswaId).toSet().length} ${LocalizationService.tr('students')} • ${_filtered.length} ${LocalizationService.tr('records')}'
                          : '${_filtered.length} ${LocalizationService.tr('records')}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ]),
              ),

            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: primary))
                  : RefreshIndicator(
                      onRefresh: () async {
                        await SyncService.checkAndSync();
                        await _load();
                      },
                      color: primary,
                      child: _filtered.isEmpty
                          ? LayoutBuilder(
                              builder: (context, constraints) => SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_outline, size: 72, color: textMuted),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Catatan sedang kosong',
                                          style: TextStyle(fontSize: 16, color: textSub),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                              itemCount: _filtered.map((k) => k.siswaId).toSet().length,
                              itemBuilder: (_, i) {
                                final ids = _filtered.map((k) => k.siswaId).toSet().toList();
                                final siswaId = ids[i];
                                final kebSiswa = _filtered.where((k) => k.siswaId == siswaId).toList()
                                  ..sort((a, b) => b.tanggal.compareTo(a.tanggal));
                                final firstRecord = kebSiswa.first;
                                final nama = _namaSiswa(siswaId, firstRecord);
                                final kelas = _kelasSiswa(siswaId, firstRecord);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: cardBorder),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: kebaikanGreen.withAlpha(isDark ? 45 : 30),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: kebaikanGreen.withAlpha(100)),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${kebSiswa.length}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: kebaikanGreen,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  nama,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: textTitle,
                                                  ),
                                                ),
                                                Text(
                                                  'Kelas $kelas • ${kebSiswa.length} kebaikan',
                                                  style: TextStyle(fontSize: 11, color: textMuted),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: LocalizationService.tr('btn_delete'),
                                            onPressed: !_canEdit
                                                ? null
                                                : () async {
                                                    final ok = await showDialog<bool>(
                                                      context: context,
                                                      builder: (d) => AlertDialog(
                                                        title: const Text('Hapus Catatan Kebaikan?'),
                                                        content: Text('Hapus semua ${kebSiswa.length} catatan kebaikan $nama?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(d, false),
                                                            child: Text(LocalizationService.tr('btn_cancel')),
                                                          ),
                                                          ElevatedButton(
                                                            onPressed: () => Navigator.pop(d, true),
                                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                            child: Text(LocalizationService.tr('btn_delete')),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (ok != true) return;
                                                    for (final k in kebSiswa) {
                                                      await DataService.deleteKebaikan(k.id);
                                                    }
                                                    final actorName = _currentUser.isNotEmpty ? _currentUser : 'Sistem';
                                                    await NotificationService.notifyUpdate(
                                                      title: 'Catatan Kebaikan Dihapus',
                                                      message: 'Semua catatan kebaikan $nama telah dihapus oleh $actorName',
                                                      category: 'system',
                                                      actor: actorName,
                                                    );
                                                    _load();
                                                  },
                                          ),
                                        ]),
                                        const SizedBox(height: 10),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        // ── List item kebaikan ──
                                        ...kebSiswa.map((k) => Padding(
                                              padding: const EdgeInsets.only(bottom: 6),
                                              child: Row(children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  margin: const EdgeInsets.only(right: 8, top: 2),
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: kebaikanGreen,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: _canEdit ? () => _showForm(k) : null,
                                                    child: Text(
                                                      k.keterangan.isNotEmpty ? k.keterangan : k.judul,
                                                      style: TextStyle(fontSize: 12, color: textSub),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  DateFormat('dd/MM/yy').format(k.tanggal),
                                                  style: TextStyle(fontSize: 10, color: textMuted),
                                                ),
                                                const SizedBox(width: 4),
                                                GestureDetector(
                                                  onTap: !_canEdit
                                                      ? null
                                                      : () async {
                                                          await DataService.deleteKebaikan(k.id);
                                                          final actorName = _currentUser.isNotEmpty ? _currentUser : 'Sistem';
                                                          await NotificationService.notifyUpdate(
                                                            title: 'Catatan Kebaikan Dihapus',
                                                            message: 'Catatan kebaikan untuk $nama dihapus oleh $actorName',
                                                            category: 'system',
                                                            actor: actorName,
                                                          );
                                                          _load();
                                                        },
                                                  child: Icon(
                                                    Icons.close,
                                                    size: 14,
                                                    color: _canEdit ? textMuted : Colors.transparent,
                                                  ),
                                                ),
                                              ]),
                                            )),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: !_canEdit
          ? null
          : FloatingActionButton(
              onPressed: () => _showForm(),
              backgroundColor: primary,
              foregroundColor: theme.colorScheme.onPrimary,
              elevation: 4,
              shape: const CircleBorder(),
              tooltip: 'Catat Kebaikan',
              child: const Icon(Icons.add_rounded, size: 28),
            ),
    );
  }
}
