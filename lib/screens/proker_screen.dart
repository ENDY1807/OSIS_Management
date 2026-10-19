import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/localization_service.dart';
import '../services/app_settings_service.dart';
import '../widgets/dynamic_form_field_builder.dart';
import '../app_theme.dart';
import 'package:uuid/uuid.dart';

class ProkerScreen extends StatefulWidget {
  final String username;
  const ProkerScreen({super.key, this.username = ''});
  @override
  State<ProkerScreen> createState() => _ProkerScreenState();
}

class _ProkerScreenState extends State<ProkerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  StreamSubscription<String>? _dataSub;
  List<Proker> _proker = [];
  String _currentUser = '';
  String _filterSekbid = 'Semua';

  bool get _isReadOnly => AuthService.isReadOnly(_currentUser);

  /// Kesiswaan, Pembina, Kepala Sekolah, Ketua, Wakil, Sekre, Bendahara, dan Admin
  /// memiliki akses penuh untuk edit, hapus, dan kelola proker semua sekbid.
  bool get _isSuperStaff {
    if (_isReadOnly) return false;
    return AuthService.isSuperStaff(_currentUser);
  }

  /// Cek apakah pengguna berhak mengesahkan proker (Kepala Sekolah, Pembina, Admin)
  bool get _canApproveProker =>
      !_isReadOnly &&
      (AuthService.hasExecutiveAccess(_currentUser) ||
          AuthService.isPembinaOrKesiswaan(_currentUser));

  bool get _canCreateProker => !_isReadOnly;

  /// Normalisasi status agar selalu selaras antara database, form, dan tab
  static String _canonicalStatus(String? s) {
    if (s == null) return StatusProker.belum;
    final lower = s.trim().toLowerCase();
    if (lower.contains('selesai') || lower.contains('done') || lower.contains('complete')) {
      return StatusProker.selesai;
    }
    if (lower.contains('jalan') || lower.contains('progress')) {
      return StatusProker.berjalan;
    }
    return StatusProker.belum;
  }

  /// Cek hak akses edit/hapus untuk suatu proker:
  /// - SuperStaff (Kepala Sekolah, Admin, Pembina, Kesiswaan, Ketua, Wakil, Sekre, Bendahara) -> BEBAS edit proker sekbid mana saja.
  /// - User Sekbid (contoh: sekbid1) -> HANYA bisa edit & hapus proker sekbid miliknya sendiri.
  /// - Viewer (Hanya Melihat) -> TIDAK BISA edit maupun hapus proker apapun.
  bool _canEditProker(Proker p) {
    if (_isReadOnly) return false;
    if (_isSuperStaff) return true;
    final u = _currentUser.toUpperCase();
    final pSekbid = p.sekbid.toUpperCase();
    return pSekbid == u;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
    if (widget.username.isNotEmpty) {
      _currentUser = AuthService.normalizeUsername(widget.username);
    }
    _initUser();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'proker' || table == 'app_settings' || table == 'all') {
        if (mounted) _load();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProkerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username) {
      _initUser();
    }
  }

  Future<void> _initUser() async {
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
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await DataService.getProker();
    if (!mounted) return;
    setState(() => _proker = data
      ..sort((a, b) => a.tanggalRencana.compareTo(b.tanggalRencana)));
  }

  List<Proker> get _filtered {
    List<Proker> list = _proker;
    if (_filterSekbid != 'Semua') {
      list = list.where((p) => p.sekbid.trim().toUpperCase() == _filterSekbid.trim().toUpperCase()).toList();
    }
    switch (_tab.index) {
      case 0:
        return list.where((p) => _canonicalStatus(p.status) == StatusProker.belum).toList();
      case 1:
        return list.where((p) => _canonicalStatus(p.status) == StatusProker.berjalan).toList();
      case 2:
        return list.where((p) => _canonicalStatus(p.status) == StatusProker.selesai).toList();
      default:
        return list;
    }
  }

  Color _statusColor(String s) {
    switch (_canonicalStatus(s)) {
      case StatusProker.berjalan:
        return const Color(0xFF0097B2);
      case StatusProker.selesai:
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFF8D6E63);
    }
  }

  IconData _statusIcon(String s) {
    switch (_canonicalStatus(s)) {
      case StatusProker.berjalan:
        return Icons.timelapse_rounded;
      case StatusProker.selesai:
        return Icons.check_circle_rounded;
      default:
        return Icons.schedule_rounded;
    }
  }

  static List<AppCustomInputField> get _defaultProkerFields => [
    AppCustomInputField(id: 'prok_nama', label: 'Nama Program Kerja', type: InputFieldType.text, placeholder: 'Nama program...', isRequired: true),
    AppCustomInputField(id: 'prok_sekbid', label: 'Divisi / Sekbid', type: InputFieldType.dropdown),
    AppCustomInputField(id: 'prok_pj', label: 'Penanggung Jawab', type: InputFieldType.text, placeholder: 'Nama PJ proker'),
    AppCustomInputField(id: 'prok_tgl_rencana', label: 'Tanggal Rencana', type: InputFieldType.date, isRequired: true),
    AppCustomInputField(id: 'prok_tgl_realisasi', label: 'Tanggal Realisasi', type: InputFieldType.date),
    AppCustomInputField(id: 'prok_status', label: 'Status Proker', type: InputFieldType.dropdown, options: StatusProker.all),
    AppCustomInputField(id: 'prok_desk', label: 'Deskripsi Program', type: InputFieldType.text, placeholder: 'Rincian proker...'),
    AppCustomInputField(id: 'prok_ket', label: 'Keterangan Tambahan', type: InputFieldType.text, placeholder: 'Catatan tambahan...'),
  ];

  void _showForm([Proker? existing]) async {
    final rawFields = AppSettingsService.customFieldsNotifier.value['proker'];
    List<AppCustomInputField> configuredFields = (rawFields != null && rawFields.isNotEmpty)
        ? List<AppCustomInputField>.from(rawFields)
        : List<AppCustomInputField>.from(_defaultProkerFields);

    if (!configuredFields.any((f) => f.id == 'prok_nama')) {
      configuredFields.insert(0, _defaultProkerFields[0]);
    }
    if (!configuredFields.any((f) => f.id == 'prok_sekbid')) {
      configuredFields.insert(1, _defaultProkerFields[1]);
    }
    if (!configuredFields.any((f) => f.id == 'prok_status')) {
      configuredFields.add(_defaultProkerFields[5]);
    }
    if (!configuredFields.any((f) => f.id == 'prok_tgl_rencana')) {
      configuredFields.add(_defaultProkerFields[3]);
    }

    final Map<String, TextEditingController> controllers = {};
    final Map<String, dynamic> dynamicValues = {};

    final prokerUnits = AuthService.prokerUnits;
    String selectedSekbid = existing?.sekbid ?? '';
    if (selectedSekbid.isEmpty) {
      if (_currentUser.isNotEmpty) {
        final match = prokerUnits.firstWhere(
          (u) => u.toUpperCase() == _currentUser.toUpperCase(),
          orElse: () => '',
        );
        selectedSekbid = match.isNotEmpty
            ? match
            : (_isSuperStaff
                ? (prokerUnits.isNotEmpty ? prokerUnits.first : 'SEKBID1')
                : _currentUser);
      } else {
        selectedSekbid = prokerUnits.isNotEmpty ? prokerUnits.first : 'SEKBID1';
      }
    }
    if (selectedSekbid.isEmpty) {
      selectedSekbid = prokerUnits.isNotEmpty ? prokerUnits.first : 'SEKBID1';
    }

    for (final field in configuredFields) {
      if (field.id == 'prok_nama') {
        controllers[field.id] =
            TextEditingController(text: existing?.nama ?? '');
        dynamicValues[field.id] = existing?.nama ?? '';
      } else if (field.id == 'prok_desk') {
        controllers[field.id] =
            TextEditingController(text: existing?.deskripsi ?? '');
        dynamicValues[field.id] = existing?.deskripsi ?? '';
      } else if (field.id == 'prok_pj') {
        controllers[field.id] = TextEditingController(
            text: existing?.penanggungJawab ??
                AuthService.getDisplayName(_currentUser));
        dynamicValues[field.id] = existing?.penanggungJawab ??
            AuthService.getDisplayName(_currentUser);
      } else if (field.id == 'prok_sekbid') {
        dynamicValues[field.id] = selectedSekbid;
      } else if (field.id == 'prok_tgl_rencana') {
        dynamicValues[field.id] = existing?.tanggalRencana ?? DateTime.now();
      } else if (field.id == 'prok_tgl_realisasi') {
        dynamicValues[field.id] = existing?.tanggalRealisasi ?? DateTime.now();
      } else if (field.id == 'prok_status') {
        dynamicValues[field.id] = _canonicalStatus(existing?.status);
      } else if (field.id == 'prok_ket') {
        controllers[field.id] =
            TextEditingController(text: existing?.keterangan ?? '');
        dynamicValues[field.id] = existing?.keterangan ?? '';
      } else {
        if (field.type == InputFieldType.date) {
          dynamicValues[field.id] = DateTime.now();
        } else if (field.type == InputFieldType.dropdown &&
            field.options.isNotEmpty) {
          dynamicValues[field.id] = field.options.first;
        } else {
          controllers[field.id] = TextEditingController(text: '');
          dynamicValues[field.id] = '';
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                ? const Border(
                    top: BorderSide(color: Color(0xFF243452), width: 1))
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
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF243452) : kPrimary,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(
                    existing == null
                        ? LocalizationService.tr('proker_add')
                        : LocalizationService.tr('proker_edit'),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : kTextDark)),
                const SizedBox(height: 16),
                ...configuredFields.map((field) {
                  if (field.id == 'prok_sekbid') {
                    final currentVal = prokerUnits.firstWhere(
                      (u) => u.toUpperCase() == (dynamicValues[field.id]?.toString().toUpperCase() ?? selectedSekbid.toUpperCase()),
                      orElse: () => prokerUnits.isNotEmpty ? prokerUnits.first : selectedSekbid,
                    );
                    if (_isSuperStaff || !prokerUnits.contains(_currentUser)) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          value: prokerUnits.contains(currentVal) ? currentVal : (prokerUnits.isNotEmpty ? prokerUnits.first : null),
                          decoration: InputDecoration(
                            labelText:
                                field.label + (field.isRequired ? ' *' : ''),
                            labelStyle: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.black54),
                            prefixIcon: const Icon(Icons.group, color: kAccent),
                          ),
                          items: prokerUnits
                              .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(AuthService.getDisplayName(s))))
                              .toList(),
                          onChanged: isSaving ? null : (v) => setModal(() {
                            dynamicValues[field.id] = v ?? selectedSekbid;
                            selectedSekbid = v ?? selectedSekbid;
                          }),
                        ),
                      );
                    } else {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText:
                                field.label + (field.isRequired ? ' *' : ''),
                            labelStyle: TextStyle(
                                color:
                                    isDark ? Colors.white70 : Colors.black54),
                            prefixIcon: const Icon(Icons.group, color: kAccent),
                          ),
                          child: Text(
                              AuthService.getDisplayName(selectedSekbid),
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : kTextDark)),
                        ),
                      );
                    }
                  }

                  if (field.id == 'prok_status') {
                    final currentStatus = _canonicalStatus(dynamicValues[field.id]?.toString());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<String>(
                        value: currentStatus,
                        decoration: InputDecoration(
                          labelText:
                              field.label + (field.isRequired ? ' *' : ''),
                          labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54),
                          prefixIcon: const Icon(Icons.flag, color: kAccent),
                        ),
                        items: StatusProker.all
                            .map((s) => DropdownMenuItem(
                                value: s,
                                child:
                                    Text(LocalizationService.formatStatus(s))))
                            .toList(),
                        onChanged: isSaving ? null : (v) => setModal(
                            () => dynamicValues[field.id] = v ?? StatusProker.belum),
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
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final rawNama = controllers['prok_nama']?.text.trim();
                    final rawDynNama = dynamicValues['prok_nama']?.toString().trim();
                    final nama = (rawNama != null && rawNama.isNotEmpty)
                        ? rawNama
                        : (rawDynNama != null && rawDynNama.isNotEmpty
                            ? rawDynNama
                            : (existing?.nama ?? ''));

                    if (nama.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Nama program kerja wajib diisi!'),
                        backgroundColor: Colors.redAccent,
                      ));
                      return;
                    }

                    setModal(() => isSaving = true);

                    try {
                      final deskripsi = controllers['prok_desk']?.text.trim() ??
                          dynamicValues['prok_desk']?.toString().trim() ??
                          '';
                      final penanggungJawab =
                          controllers['prok_pj']?.text.trim() ??
                              dynamicValues['prok_pj']?.toString().trim() ??
                              '';
                      final keterangan = controllers['prok_ket']?.text.trim() ??
                          dynamicValues['prok_ket']?.toString().trim() ??
                          '';
                      final status = _canonicalStatus(dynamicValues['prok_status']?.toString());
                      final tanggalRencana =
                          dynamicValues['prok_tgl_rencana'] is DateTime
                              ? dynamicValues['prok_tgl_rencana'] as DateTime
                              : (existing?.tanggalRencana ?? DateTime.now());
                      final tanggalRealisasi =
                          dynamicValues['prok_tgl_realisasi'] is DateTime
                              ? dynamicValues['prok_tgl_realisasi'] as DateTime
                              : (status == StatusProker.selesai
                                  ? (existing?.tanggalRealisasi ?? DateTime.now())
                                  : null);

                      final targetSekbid = (dynamicValues['prok_sekbid']?.toString().trim().isNotEmpty == true)
                          ? dynamicValues['prok_sekbid'].toString().trim()
                          : selectedSekbid;

                      final p = Proker(
                        id: existing?.id ?? const Uuid().v4(),
                        nama: nama,
                        deskripsi: deskripsi,
                        sekbid: targetSekbid.isNotEmpty ? targetSekbid : 'SEKBID1',
                        penanggungJawab: penanggungJawab,
                        tanggalRencana: tanggalRencana,
                        tanggalRealisasi: status == StatusProker.selesai
                            ? tanggalRealisasi
                            : null,
                        status: status,
                        keterangan: keterangan,
                        disahkanKepsek: existing?.disahkanKepsek ?? false,
                        catatanKepsek: existing?.catatanKepsek ?? '',
                      );

                      if (existing == null) {
                        await DataService.addProker(p);
                        try {
                          await NotificationService.notifyUpdate(
                            title: 'Program Kerja Baru Dibuat',
                            message: 'Proker "${p.nama}" dibuat oleh $_currentUser',
                            category: 'proker',
                            actor: _currentUser,
                          );
                        } catch (_) {}
                      } else {
                        await DataService.updateProker(p);
                        try {
                          await NotificationService.notifyUpdate(
                            title: 'Program Kerja Diperbarui',
                            message:
                                'Proker "${p.nama}" (${p.sekbid} - Status: ${p.status}) diperbarui oleh $_currentUser',
                            category: 'proker',
                            actor: _currentUser,
                          );
                        } catch (_) {}
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      
                      // Auto-switch ke tab status yang sesuai dan reset filter agar proker langsung kelihatan
                      final canon = _canonicalStatus(p.status);
                      int targetTab = 0;
                      if (canon == StatusProker.berjalan) targetTab = 1;
                      if (canon == StatusProker.selesai) targetTab = 2;

                      if (mounted) {
                        setState(() {
                          _tab.index = targetTab;
                          _filterSekbid = 'Semua';
                        });
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  existing == null
                                      ? 'Program kerja "${p.nama}" berhasil ditambahkan!'
                                      : 'Program kerja "${p.nama}" berhasil diperbarui!',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                      }
                      await _load();
                    } catch (e) {
                      setModal(() => isSaving = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text('Gagal menyimpan program kerja: $e'),
                          backgroundColor: Colors.redAccent,
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          LocalizationService.tr('btn_save'),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dialog Pengesahan / Disposisi Resmi oleh Kepala Sekolah
  Future<void> _showApprovalDialog(Proker p) async {
    final catatanCtrl = TextEditingController(text: p.catatanKepsek);
    final bool newDisahkanState = !p.disahkanKepsek;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  newDisahkanState ? Icons.verified_rounded : Icons.highlight_off_rounded,
                  color: newDisahkanState ? const Color(0xFF10B981) : Colors.orange,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    newDisahkanState ? 'Pengesahan Kepala Sekolah' : 'Batalkan Pengesahan Proker',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1B2433) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Divisi: ${AuthService.getDisplayName(p.sekbid)} • PJ: ${p.penanggungJawab}',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    newDisahkanState
                        ? 'Sebagai Kepala Sekolah, Anda akan memberikan status Pengesahan Resmi pada program kerja ini.'
                        : 'Apakah Anda yakin ingin membatalkan status pengesahan resmi proker ini?',
                    style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 14),
                  if (newDisahkanState)
                    TextField(
                      controller: catatanCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan / Arahan Disposisi Kepala Sekolah',
                        hintText: 'Contoh: Disetujui, laksanakan sesuai jadwal.',
                        prefixIcon: const Icon(Icons.rate_review_outlined, color: kAccent),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(LocalizationService.tr('btn_cancel')),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: newDisahkanState ? const Color(0xFF10B981) : Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(newDisahkanState ? Icons.check_circle_rounded : Icons.close_rounded, size: 16),
                label: Text(newDisahkanState ? 'Sahkan Resmi' : 'Batalkan Status'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      await DataService.setApprovalProkerKepsek(
        p.id,
        disahkan: newDisahkanState,
        catatan: newDisahkanState ? catatanCtrl.text.trim() : '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newDisahkanState
              ? 'Proker "${p.nama}" berhasil disahkan secara resmi oleh Kepala Sekolah!'
              : 'Status pengesahan proker "${p.nama}" telah dicabut.'),
          backgroundColor: newDisahkanState ? const Color(0xFF10B981) : Colors.orange,
        ));
      }
      _load();
    }
  }

  Widget _buildProkerCard(Proker p) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _statusColor(p.status);
    final cardBg = isDark ? const Color(0xFF141D2E) : Colors.white;
    final cardBorder =
        isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0);
    final textTitle = isDark ? Colors.white : kTextDark;
    final textSub = isDark ? const Color(0xFF94A3B8) : kTextMid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: kPrimary.withAlpha(100),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
        border: isDark
            ? Border.all(color: cardBorder)
            : Border(left: BorderSide(color: color, width: 4)),
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
                      Text(p.nama,
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: textTitle)),
                      if (p.disahkanKepsek) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withAlpha(isDark ? 40 : 25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFF10B981).withAlpha(120),
                                width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.verified_rounded, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text('Disahkan Kepala Sekolah',
                                  style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: color.withAlpha(isDark ? 40 : 25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withAlpha(80), width: 1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_statusIcon(p.status), size: 13, color: color),
                    const SizedBox(width: 5),
                    Text(LocalizationService.formatStatus(p.status),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ]),
                ),
              ],
            ),
            if (p.deskripsi.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(p.deskripsi,
                  style: TextStyle(fontSize: 13, color: textSub),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(Icons.group_outlined, p.sekbid, isDark: isDark),
                _chip(Icons.person_outline, p.penanggungJawab, isDark: isDark),
                _chip(
                    Icons.calendar_today_outlined,
                    DateFormat(
                            'dd MMM yyyy',
                            LocalizationService
                                .currentLocale.value.languageCode)
                        .format(p.tanggalRencana),
                    isDark: isDark),
                if (p.tanggalRealisasi != null)
                  _chip(
                      Icons.event_available_outlined,
                      DateFormat(
                              'dd MMM yyyy',
                              LocalizationService
                                  .currentLocale.value.languageCode)
                          .format(p.tanggalRealisasi!),
                      color: const Color(0xFF10B981),
                      isDark: isDark),
              ],
            ),
            if (p.catatanKepsek.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withAlpha(isDark ? 25 : 15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withAlpha(70)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.school_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Arahan Kepala Sekolah: "${p.catatanKepsek}"',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (p.keterangan.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0E1626) : kBg,
                  borderRadius: BorderRadius.circular(8),
                  border: isDark
                      ? Border.all(color: const Color(0xFF243452))
                      : null,
                ),
                child: Text(p.keterangan,
                    style: TextStyle(
                        fontSize: 12,
                        color: textSub,
                        fontStyle: FontStyle.italic)),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_canApproveProker) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: p.disahkanKepsek ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    icon: Icon(
                      p.disahkanKepsek ? Icons.verified_rounded : Icons.verified_outlined,
                      size: 16,
                    ),
                    label: Text(
                      p.disahkanKepsek ? 'Disahkan (Ubah)' : 'Sahkan Proker',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showApprovalDialog(p),
                  ),
                  const SizedBox(width: 4),
                ],
                if (_canEditProker(p)) ...[
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6)),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(LocalizationService.tr('btn_edit'),
                        style: const TextStyle(fontSize: 13)),
                    onPressed: () => _showForm(p),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6)),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(LocalizationService.tr('btn_delete'),
                        style: const TextStyle(fontSize: 13)),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                              LocalizationService.tr('proker_delete_confirm')),
                          content: Text(
                              '${LocalizationService.tr('proker_delete_msg')}\n"${p.nama}"'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child:
                                    Text(LocalizationService.tr('btn_cancel'))),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                    LocalizationService.tr('btn_delete'),
                                    style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await DataService.deleteProker(p.id);
                        await NotificationService.cancelProkerReminder(
                            NotificationService.idFromString(
                                'proker_remind_${p.id}'));
                        await NotificationService.notifyUpdate(
                          title: 'Program Kerja Dihapus',
                          message:
                              'Proker "${p.nama}" (${p.sekbid}) telah dihapus oleh $_currentUser',
                          category: 'proker',
                          actor: _currentUser,
                        );
                        _load();
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label,
          {Color? color, bool isDark = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A263D) : kPrimary.withAlpha(60),
          borderRadius: BorderRadius.circular(6),
          border: isDark ? Border.all(color: const Color(0xFF243452)) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 12,
              color: color ?? (isDark ? const Color(0xFF00B4D8) : kAccent)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color ?? (isDark ? const Color(0xFFF1F5F9) : kTextMid),
                  fontWeight: FontWeight.w500)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final allSekbid = _isSuperStaff
        ? [LocalizationService.tr('btn_all'), ...AuthService.prokerUnits]
        : [LocalizationService.tr('btn_all'), _currentUser];
    final totalBelum =
        _proker.where((p) => _canonicalStatus(p.status) == StatusProker.belum).length;
    final totalBerjalan =
        _proker.where((p) => _canonicalStatus(p.status) == StatusProker.berjalan).length;
    final totalSelesai =
        _proker.where((p) => _canonicalStatus(p.status) == StatusProker.selesai).length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Stats header
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
                _statBox(LocalizationService.tr('status_draft'), totalBelum,
                    const Color(0xFFBF8F00)),
                const SizedBox(width: 8),
                _statBox(LocalizationService.tr('status_running'),
                    totalBerjalan, const Color(0xFF007A8E)),
                const SizedBox(width: 8),
                _statBox(LocalizationService.tr('status_done'), totalSelesai,
                    const Color(0xFF2E7D32)),
              ],
            ),
          ),

          if (_isSuperStaff)
            Container(
              color: isDark ? const Color(0xFF141D2E) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allSekbid.map((s) {
                    final displayName = s == LocalizationService.tr('btn_all')
                        ? s
                        : AuthService.getDisplayName(s);
                    final selected = _filterSekbid == s ||
                        (_filterSekbid == 'Semua' &&
                            s == LocalizationService.tr('btn_all'));
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(displayName),
                        selected: selected,
                        onSelected: (_) => setState(() => _filterSekbid =
                            (s == LocalizationService.tr('btn_all')
                                ? 'Semua'
                                : s)),
                        selectedColor: primary,
                        checkmarkColor: Colors.black,
                        labelStyle: TextStyle(
                          color: selected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? const Color(0xFF94A3B8) : kTextDark),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF0E1626)
                            : kPrimary.withAlpha(60),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        side: isDark && !selected
                            ? const BorderSide(color: Color(0xFF243452))
                            : BorderSide.none,
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Tabs
          Container(
            color: isDark ? const Color(0xFF0D1424) : primary,
            child: TabBar(
              controller: _tab,
              tabs: [
                Tab(
                    text:
                        '${LocalizationService.tr('status_draft')} ($totalBelum)'),
                Tab(
                    text:
                        '${LocalizationService.tr('status_running')} ($totalBerjalan)'),
                Tab(
                    text:
                        '${LocalizationService.tr('status_done')} ($totalSelesai)'),
              ],
            ),
          ),

          // List
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: List.generate(3, (i) {
                final list = _filtered;
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: primary.withAlpha(isDark ? 35 : 25),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.assignment_add,
                                size: 38,
                                color: primary),
                          ),
                          const SizedBox(height: 16),
                          Text(LocalizationService.tr('proker_empty'),
                              style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFF1F5F9)
                                      : kTextDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                            'Belum ada program kerja di kategori status ini. Klik tombol di bawah untuk membuat program kerja baru.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : Colors.black54,
                              fontSize: 12.5,
                            ),
                          ),
                          if (_canCreateProker) ...[
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: () => _showForm(),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: Text(LocalizationService.tr('proker_add')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _load,
                  color: primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _buildProkerCard(list[i]),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
      floatingActionButton: _canCreateProker
          ? FloatingActionButton.extended(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              label: Text(LocalizationService.tr('proker_add'),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _statBox(String label, int count, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(60)),
          ),
          child: Column(
            children: [
              Text('$count',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      );
}
