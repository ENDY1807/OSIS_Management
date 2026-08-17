import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, XFile, ShareParams;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../app_theme.dart';

const _uuid = Uuid();

enum ClipboardMode { none, copy, cut }
enum ViewMode { grid, list }
enum SortMode { nameAsc, nameDesc, dateNewest, dateOldest }

class ArsipScreen extends StatefulWidget {
  final String username;
  const ArsipScreen({super.key, this.username = ''});

  @override
  State<ArsipScreen> createState() => _ArsipScreenState();
}

class _ArsipScreenState extends State<ArsipScreen> {
  List<Arsip> _allArsip = [];
  List<String> _allFolders = [];
  String _currentPath = ''; // '' represents Root (/)
  String _search = '';
  bool _loading = true;
  ViewMode _viewMode = ViewMode.list;
  SortMode _sortMode = SortMode.dateNewest;
  StreamSubscription<String>? _dataSub;

  // Multi-select state
  bool _isSelectionMode = false;
  final Set<String> _selectedFileIds = {};
  final Set<String> _selectedFolderPaths = {};

  // Clipboard state
  ClipboardMode _clipboardMode = ClipboardMode.none;
  List<Arsip> _clipboardFiles = [];
  List<String> _clipboardFolders = [];

  bool get _canEdit => true;

  @override
  void initState() {
    super.initState();
    _load();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'arsip' || table == 'arsip_folder' || table == 'all') {
        if (mounted) _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && _allArsip.isEmpty && _allFolders.isEmpty) {
      setState(() => _loading = true);
    }
    try {
      final arsip = await DataService.getArsip();
      final folders = await DataService.getArsipFolders();
      if (!mounted) return;

      // Seed default folders if completely empty
      if (folders.isEmpty && arsip.isEmpty) {
        final defaultFolders = ['Surat Masuk', 'Surat Keluar', 'Proposal', 'LPJ', 'Dokumentasi'];
        for (final f in defaultFolders) {
          await DataService.addArsipFolder(f);
        }
        final reloadedFolders = await DataService.getArsipFolders();
        if (!mounted) return;
        setState(() {
          _allArsip = arsip;
          _allFolders = reloadedFolders;
          _loading = false;
        });
        return;
      }

      setState(() {
        _allArsip = arsip;
        _allFolders = folders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat arsip: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Path & Navigation Helpers ──────────────────────────────────────────────
  List<String> get _pathSegments {
    if (_currentPath.isEmpty) return [];
    return _currentPath.split('/');
  }

  void _navigateToPath(String path) {
    setState(() {
      _currentPath = path;
      _search = '';
      _clearSelection();
    });
  }

  void _goUp() {
    if (_currentPath.isEmpty) return;
    final segs = _pathSegments;
    if (segs.length <= 1) {
      _navigateToPath('');
    } else {
      _navigateToPath(segs.sublist(0, segs.length - 1).join('/'));
    }
  }

  // ── Known Folders & Hierarchy Helper ───────────────────────────────────────
  Set<String> _getAllKnownFolders() {
    final Set<String> all = {};
    for (final f in _allFolders) {
      final clean = f.trim();
      if (clean.isEmpty || clean.toLowerCase() == 'root') continue;
      final parts = clean.split('/');
      String current = '';
      for (final p in parts) {
        final segment = p.trim();
        if (segment.isEmpty || segment.toLowerCase() == 'root') continue;
        current = current.isEmpty ? segment : '$current/$segment';
        all.add(current);
      }
    }
    for (final a in _allArsip) {
      final clean = a.kategori.trim();
      if (clean.isEmpty || clean.toLowerCase() == 'root') continue;
      final parts = clean.split('/');
      String current = '';
      for (final p in parts) {
        final segment = p.trim();
        if (segment.isEmpty || segment.toLowerCase() == 'root') continue;
        current = current.isEmpty ? segment : '$current/$segment';
        all.add(current);
      }
    }
    return all;
  }

  // Subfolders inside current path
  List<String> get _currentSubfolders {
    final allKnown = _getAllKnownFolders();
    final Set<String> result = {};
    if (_currentPath.isEmpty) {
      for (final f in allKnown) {
        final top = f.split('/').first;
        result.add(top);
      }
    } else {
      final prefix = '$_currentPath/';
      for (final f in allKnown) {
        if (f.startsWith(prefix) && f != _currentPath) {
          final rest = f.substring(prefix.length);
          final directChild = rest.split('/').first;
          result.add('$_currentPath/$directChild');
        }
      }
    }
    var list = result.toList();
    if (_search.isNotEmpty) {
      list = list.where((p) => p.split('/').last.toLowerCase().contains(_search.toLowerCase())).toList();
    }
    list.sort((a, b) => a.split('/').last.toLowerCase().compareTo(b.split('/').last.toLowerCase()));
    return list;
  }

  // Files inside current path
  List<Arsip> get _currentFiles {
    var files = _allArsip.where((a) {
      if (a.keterangan == '__folder__' || a.nomorSurat == '__dir__') return false;
      if (_currentPath.isEmpty) {
        return a.kategori.isEmpty || a.kategori == 'Root';
      }
      return a.kategori == _currentPath;
    }).toList();

    if (_search.isNotEmpty) {
      files = files.where((a) =>
        a.judul.toLowerCase().contains(_search.toLowerCase()) ||
        a.nomorSurat.toLowerCase().contains(_search.toLowerCase()) ||
        a.deskripsi.toLowerCase().contains(_search.toLowerCase())
      ).toList();
    }

    switch (_sortMode) {
      case SortMode.nameAsc:
        files.sort((a, b) => a.judul.toLowerCase().compareTo(b.judul.toLowerCase()));
        break;
      case SortMode.nameDesc:
        files.sort((a, b) => b.judul.toLowerCase().compareTo(a.judul.toLowerCase()));
        break;
      case SortMode.dateNewest:
        files.sort((a, b) => b.tanggal.compareTo(a.tanggal));
        break;
      case SortMode.dateOldest:
        files.sort((a, b) => a.tanggal.compareTo(b.tanggal));
        break;
    }
    return files;
  }

  // ── Multi-select operations ────────────────────────────────────────────────
  void _toggleFileSelection(String id) {
    setState(() {
      if (_selectedFileIds.contains(id)) {
        _selectedFileIds.remove(id);
      } else {
        _selectedFileIds.add(id);
      }
      _isSelectionMode = _selectedFileIds.isNotEmpty || _selectedFolderPaths.isNotEmpty;
    });
  }

  void _toggleFolderSelection(String path) {
    setState(() {
      if (_selectedFolderPaths.contains(path)) {
        _selectedFolderPaths.remove(path);
      } else {
        _selectedFolderPaths.add(path);
      }
      _isSelectionMode = _selectedFileIds.isNotEmpty || _selectedFolderPaths.isNotEmpty;
    });
  }

  void _selectAll() {
    setState(() {
      _selectedFileIds.addAll(_currentFiles.map((f) => f.id));
      _selectedFolderPaths.addAll(_currentSubfolders);
      _isSelectionMode = true;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFileIds.clear();
      _selectedFolderPaths.clear();
      _isSelectionMode = false;
    });
  }

  int get _selectedCount => _selectedFileIds.length + _selectedFolderPaths.length;

  // ── Clipboard (Copy / Cut / Paste) ─────────────────────────────────────────
  void _copySelected() {
    final files = _allArsip.where((a) => _selectedFileIds.contains(a.id)).toList();
    final folders = _selectedFolderPaths.toList();
    setState(() {
      _clipboardFiles = files;
      _clipboardFolders = folders;
      _clipboardMode = ClipboardMode.copy;
      _clearSelection();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.content_copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('${files.length + folders.length} item disalin. Buka folder tujuan lalu tekan Tempel.')),
          ],
        ),
        backgroundColor: kPrimaryDark,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _cutSelected() {
    final files = _allArsip.where((a) => _selectedFileIds.contains(a.id)).toList();
    final folders = _selectedFolderPaths.toList();
    setState(() {
      _clipboardFiles = files;
      _clipboardFolders = folders;
      _clipboardMode = ClipboardMode.cut;
      _clearSelection();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.content_cut_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('${files.length + folders.length} item dipotong (Move). Buka folder tujuan lalu tekan Tempel.')),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pasteClipboard() async {
    if (_clipboardMode == ClipboardMode.none) return;
    setState(() => _loading = true);
    try {
      if (_clipboardMode == ClipboardMode.cut) {
        final ids = _clipboardFiles.map((f) => f.id).toList();
        await DataService.moveArsipToFolder(ids, _currentPath);

        for (final oldPath in _clipboardFolders) {
          final folderName = oldPath.split('/').last;
          final newPath = _currentPath.isEmpty ? folderName : '$_currentPath/$folderName';
          if (oldPath != newPath) {
            await DataService.renameArsipFolder(oldPath, newPath);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Berhasil memindahkan item'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (_clipboardMode == ClipboardMode.copy) {
        await DataService.copyArsipToFolder(_clipboardFiles, _currentPath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Berhasil menyalin file'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      _clipboardFiles.clear();
      _clipboardFolders.clear();
      _clipboardMode = ClipboardMode.none;
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menempelkan: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _cancelClipboard() {
    setState(() {
      _clipboardMode = ClipboardMode.none;
      _clipboardFiles.clear();
      _clipboardFolders.clear();
    });
  }

  // ── Move to specific folder dialog (Bertahap / Hierarchical) ──────────────
  void _showMoveDialog(List<Arsip> filesToMove, {List<String> foldersToMove = const []}) {
    if (filesToMove.isEmpty && foldersToMove.isEmpty) return;

    // Start at Root
    String targetPath = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setM) {
            final allKnown = _getAllKnownFolders();

            // Subfolders inside current targetPath in dialog
            final Set<String> directSubfolders = {};
            if (targetPath.isEmpty) {
              for (final f in allKnown) {
                final top = f.split('/').first;
                directSubfolders.add(top);
              }
            } else {
              final prefix = '$targetPath/';
              for (final f in allKnown) {
                if (f.startsWith(prefix) && f != targetPath) {
                  final rest = f.substring(prefix.length);
                  final directChild = rest.split('/').first;
                  directSubfolders.add('$targetPath/$directChild');
                }
              }
            }

            // Exclude moving a folder into itself or its children
            final validSubfolders = directSubfolders.where((sub) {
              for (final fm in foldersToMove) {
                if (sub == fm || sub.startsWith('$fm/')) return false;
              }
              return true;
            }).toList();
            validSubfolders.sort((a, b) => a.split('/').last.toLowerCase().compareTo(b.split('/').last.toLowerCase()));

            final totalItems = filesToMove.length + foldersToMove.length;
            final pathSegments = targetPath.isEmpty ? <String>[] : targetPath.split('/');

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: kAccent.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.drive_file_move_rounded, color: kAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pindahkan $totalItems Item',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark)),
                            Text(
                              targetPath.isEmpty ? 'Lokasi saat ini: Root (/)' : 'Lokasi: $targetPath',
                              style: const TextStyle(fontSize: 11, color: kTextMid),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Quick create subfolder button
                      IconButton(
                        icon: const Icon(Icons.create_new_folder_outlined, color: kAccent),
                        tooltip: 'Buat Folder di Sini',
                        onPressed: () {
                          final fNameC = TextEditingController();
                          showDialog(
                            context: ctx,
                            builder: (dCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Folder Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              content: TextField(
                                controller: fNameC,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  labelText: 'Nama Folder',
                                  hintText: 'Masukan Nama Folder',
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Batal')),
                                ElevatedButton(
                                  onPressed: () async {
                                    final name = fNameC.text.trim();
                                    if (name.isEmpty) return;
                                    final newFullPath = targetPath.isEmpty ? name : '$targetPath/$name';
                                    await DataService.addArsipFolder(newFullPath);
                                    if (!_allFolders.contains(newFullPath)) {
                                      _allFolders.add(newFullPath);
                                    }
                                    if (dCtx.mounted) Navigator.pop(dCtx);
                                    setM(() {});
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: kAccent),
                                  child: const Text('Buat'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Breadcrumb Navigation in Dialog
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => setM(() => targetPath = ''),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.home_rounded, size: 16, color: targetPath.isEmpty ? kAccent : kTextMid),
                                  const SizedBox(width: 4),
                                  Text('Root',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: targetPath.isEmpty ? FontWeight.bold : FontWeight.normal,
                                          color: targetPath.isEmpty ? kAccent : kTextDark)),
                                ],
                              ),
                            ),
                          ),
                          for (int i = 0; i < pathSegments.length; i++) ...[
                            const Icon(Icons.chevron_right_rounded, size: 16, color: kTextLight),
                            InkWell(
                              onTap: () {
                                final newTarget = pathSegments.sublist(0, i + 1).join('/');
                                setM(() => targetPath = newTarget);
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Text(
                                  pathSegments[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: i == pathSegments.length - 1 ? FontWeight.bold : FontWeight.normal,
                                    color: i == pathSegments.length - 1 ? kAccent : kTextDark,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Back to parent directory button
                  if (targetPath.isNotEmpty)
                    InkWell(
                      onTap: () {
                        if (pathSegments.length <= 1) {
                          setM(() => targetPath = '');
                        } else {
                          setM(() => targetPath = pathSegments.sublist(0, pathSegments.length - 1).join('/'));
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.arrow_upward_rounded, size: 18, color: kAccent),
                            SizedBox(width: 10),
                            Text('..',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextDark)),
                          ],
                        ),
                      ),
                    ),

                  // Subfolders List (Hierarchical / Bertahap)
                  Expanded(
                    child: validSubfolders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_open_rounded, size: 44, color: Colors.grey.shade300),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tidak ada subfolder di dalam folder ini',
                                  style: TextStyle(fontSize: 13, color: kTextMid),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tekan "Pindahkan ke Sini" untuk memindahkan ke "${targetPath.isEmpty ? "Root" : targetPath.split("/").last}"',
                                  style: const TextStyle(fontSize: 11, color: kTextLight),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: validSubfolders.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (ctx, idx) {
                              final subPath = validSubfolders[idx];
                              final subName = subPath.split('/').last;
                              final subCount = _allArsip
                                  .where((a) => (a.kategori == subPath || a.kategori.startsWith('$subPath/')) &&
                                      a.keterangan != '__folder__' &&
                                      a.nomorSurat != '__dir__')
                                  .length;
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration:
                                      BoxDecoration(color: kAccent.withAlpha(20), borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.folder_rounded, color: kAccent, size: 20),
                                ),
                                title: Text(subName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark)),
                                subtitle: Text('$subCount item • Ketuk untuk masuk',
                                    style: const TextStyle(fontSize: 11, color: kTextLight)),
                                trailing: const Icon(Icons.chevron_right_rounded, color: kTextMid, size: 20),
                                onTap: () {
                                  // Navigate inside this folder (bertahap)
                                  setM(() => targetPath = subPath);
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),

                  // Bottom Action Button: Pindahkan ke Sini
                  ElevatedButton.icon(
                    icon: const Icon(Icons.drive_file_move_rounded, size: 18),
                    label: Text(
                      'Pindahkan ke ${targetPath.isEmpty ? "Root (/)" : targetPath.split("/").last}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _loading = true);
                      try {
                        // Move files
                        if (filesToMove.isNotEmpty) {
                          final ids = filesToMove.map((f) => f.id).toList();
                          await DataService.moveArsipToFolder(ids, targetPath);
                        }

                        // Move folders
                        for (final oldPath in foldersToMove) {
                          final folderName = oldPath.split('/').last;
                          final newPath = targetPath.isEmpty ? folderName : '$targetPath/$folderName';
                          if (oldPath != newPath) {
                            await DataService.renameArsipFolder(oldPath, newPath);
                          }
                        }

                        final targetLabel = targetPath.isEmpty ? 'Root (/)' : targetPath;
                        final totalItems = filesToMove.length + foldersToMove.length;
                        await NotificationService.notifyUpdate(
                          title: 'File / Folder Dipindahkan',
                          message: '$totalItems item dipindahkan ke folder $targetLabel oleh ${widget.username}',
                          category: 'arsip',
                          actor: widget.username,
                        );

                        _clearSelection();
                        await _load();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$totalItems item berhasil dipindahkan ke ${targetPath.isEmpty ? "Root (/)" : targetPath}',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal memindahkan: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

  // ── Compress & Archive to ZIP ──────────────────────────────────────────────
  Future<void> _archiveSelectedToZip() async {
    final selectedFiles = _allArsip.where((a) => _selectedFileIds.contains(a.id)).toList();
    if (selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih setidaknya 1 file untuk dikompres ke ZIP')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (d) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(color: kAccent),
              SizedBox(height: 16),
              Text('Mengompres file ke ZIP...', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Mengemas berkas arsip...', style: TextStyle(fontSize: 12, color: kTextMid)),
            ],
          ),
        ),
      ),
    );

    try {
      final archive = Archive();

      for (final a in selectedFiles) {
        Uint8List? fileBytes;
        String fileName = a.judul;

        if (a.fileUrl.isNotEmpty) {
          try {
            final res = await http.get(Uri.parse(a.fileUrl));
            if (res.statusCode == 200) {
              fileBytes = res.bodyBytes;
              final uri = Uri.parse(a.fileUrl);
              final seg = uri.pathSegments.lastOrNull ?? '';
              if (seg.contains('.')) {
                final ext = seg.split('.').last;
                if (!fileName.toLowerCase().endsWith('.$ext')) {
                  fileName = '$fileName.$ext';
                }
              }
            }
          } catch (_) {}
        }

        if (fileBytes == null) {
          final content = 'Arsip: ${a.judul}\nKategori: ${a.kategori}\nTanggal: ${a.tanggal}\nNo Surat: ${a.nomorSurat}\nDeskripsi: ${a.deskripsi}\nKeterangan: ${a.keterangan}\nFile URL: ${a.fileUrl}';
          fileBytes = Uint8List.fromList(content.codeUnits);
          fileName = '$fileName.txt';
        }

        archive.addFile(ArchiveFile(fileName, fileBytes.length, fileBytes));
      }

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      if (mounted) Navigator.pop(context);

      if (zipBytes == null) {
        throw Exception('Gagal mengompresi arsip');
      }

      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final zipName = 'Arsip_OSIS_$dateStr.zip';
      final zipFile = File('${dir.path}/$zipName');
      await zipFile.writeAsBytes(zipBytes);

      _clearSelection();

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.archive_rounded, color: Colors.amber, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('File ZIP Berhasil Dibuat!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark)),
                  Text('$zipName (${(zipBytes.length / 1024).toStringAsFixed(1)} KB)',
                      style: const TextStyle(fontSize: 12, color: kTextMid)),
                ])),
              ]),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Bagikan File ZIP (WhatsApp / dll)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await SharePlus.instance.share(ShareParams(
                    files: [XFile(zipFile.path, mimeType: 'application/zip')],
                    text: 'Arsip OSIS: $zipName',
                  ));
                },
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Buka File ZIP'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await OpenFilex.open(zipFile.path);
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat ZIP: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Delete batch ───────────────────────────────────────────────────────────
  Future<void> _deleteSelected() async {
    final count = _selectedCount;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Hapus Item Terpilih?'),
        content: Text('Yakin ingin menghapus $count item yang dipilih secara permanen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Hapus'),
            onPressed: () => Navigator.pop(d, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    final countFiles = _selectedFileIds.length;
    final countFolders = _selectedFolderPaths.length;
    for (final id in _selectedFileIds) {
      await DataService.deleteArsip(id);
    }
    for (final path in _selectedFolderPaths) {
      await DataService.deleteArsipFolder(path);
    }
    final locLabel = _currentPath.isEmpty ? 'Root (/)' : _currentPath;
    await NotificationService.notifyUpdate(
      title: 'Item Arsip Dihapus',
      message: '$countFiles file dan $countFolders folder di $locLabel telah dihapus oleh ${widget.username}',
      category: 'arsip',
      actor: widget.username,
    );
    _clearSelection();
    await _load();
  }

  // ── Create New Folder Modal ────────────────────────────────────────────────
  void _showCreateFolderDialog() {
    final namaC = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Buat Folder Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
            const SizedBox(height: 4),
            Text(_currentPath.isEmpty ? 'Folder akan dibuat di Root (/)' : 'Folder dibuat di: $_currentPath',
                style: const TextStyle(fontSize: 12, color: kTextMid)),
            const SizedBox(height: 16),
            TextField(
              controller: namaC,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Folder *',
                prefixIcon: Icon(Icons.create_new_folder_outlined, color: kAccent),
                hintText: 'Masukan Nama Folder',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.create_new_folder_rounded, size: 18),
              label: const Text('Buat Folder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final folderName = namaC.text.trim();
                if (folderName.isEmpty) return;
                final fullPath = _currentPath.isEmpty ? folderName : '$_currentPath/$folderName';

                if (_allFolders.contains(fullPath)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Folder dengan nama ini sudah ada'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                await DataService.addArsipFolder(fullPath);
                final locLabel = _currentPath.isEmpty ? 'Root (/)' : _currentPath;
                await NotificationService.notifyUpdate(
                  title: 'Folder Baru Dibuat',
                  message: 'Folder "$folderName" dibuat di lokasi $locLabel oleh ${widget.username}',
                  category: 'arsip',
                  actor: widget.username,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rename Folder Modal ────────────────────────────────────────────────────
  void _showRenameFolderDialog(String oldPath) {
    final oldName = oldPath.split('/').last;
    final nameC = TextEditingController(text: oldName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Ganti Nama Folder', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
            const SizedBox(height: 16),
            TextField(
              controller: nameC,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Baru *',
                prefixIcon: Icon(Icons.edit_outlined, color: kAccent),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Simpan Perubahan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final newName = nameC.text.trim();
                if (newName.isEmpty || newName == oldName) {
                  Navigator.pop(ctx);
                  return;
                }
                final segs = oldPath.split('/');
                segs[segs.length - 1] = newName;
                final newPath = segs.join('/');

                await DataService.renameArsipFolder(oldPath, newPath);
                await NotificationService.notifyUpdate(
                  title: 'Folder Diubah Nama',
                  message: 'Folder "$oldName" diubah menjadi "$newName" oleh ${widget.username}',
                  category: 'arsip',
                  actor: widget.username,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                await _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upload / Add File Modal ────────────────────────────────────────────────
  void _showFileForm({Arsip? existing}) async {
    final judulC = TextEditingController(text: existing?.judul ?? '');
    final nomorC = TextEditingController(text: existing?.nomorSurat ?? '');
    final deskC = TextEditingController(text: existing?.deskripsi ?? '');
    final ketC = TextEditingController(text: existing?.keterangan ?? '');
    DateTime tanggal = existing?.tanggal ?? DateTime.now();
    String fileUrl = existing?.fileUrl ?? '';
    String? pickedFileName;
    Uint8List? pickedFileBytes;
    bool uploading = false;
    final sekbid = await AuthService.getUserName() ?? '';

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Text(existing == null ? 'Tambah File Baru' : 'Edit Informasi File',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.folder_rounded, size: 16, color: kAccent),
                  const SizedBox(width: 6),
                  Text(_currentPath.isEmpty ? 'Lokasi: Root (/)' : 'Lokasi: $_currentPath',
                      style: const TextStyle(fontSize: 12, color: kTextMid)),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: judulC,
                  autofocus: existing == null,
                  decoration: const InputDecoration(
                    labelText: 'Nama File / Judul Dokumen *',
                    prefixIcon: Icon(Icons.insert_drive_file_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nomorC,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Surat / Dokumen (opsional)',
                    prefixIcon: Icon(Icons.tag, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context, initialDate: tanggal,
                      firstDate: DateTime(2020), lastDate: DateTime(2100),
                    );
                    if (picked != null) setModal(() => tanggal = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Dokumen',
                      prefixIcon: Icon(Icons.calendar_month_outlined, color: kAccent),
                    ),
                    child: Text(DateFormat('dd MMMM yyyy', 'id').format(tanggal),
                        style: const TextStyle(fontSize: 14, color: kTextDark)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deskC,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi Singkat',
                    prefixIcon: Icon(Icons.description_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 12),
                // File Picker
                InkWell(
                  onTap: () async {
                    final result = await FilePicker.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'zip', 'txt'],
                    );
                    if (result == null) return;
                    final f = result.files.first;
                    final fBytes = await f.readAsBytes();
                    setModal(() {
                      pickedFileName = f.name;
                      pickedFileBytes = fBytes;
                      if (judulC.text.trim().isEmpty) {
                        judulC.text = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
                      }
                    });
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Upload File dari HP / Komputer',
                      prefixIcon: const Icon(Icons.upload_file_outlined, color: kAccent),
                      suffixIcon: pickedFileName != null
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18, color: kTextLight),
                              onPressed: () => setModal(() {
                                pickedFileName = null;
                                pickedFileBytes = null;
                              }),
                            )
                          : null,
                    ),
                    child: Text(
                      pickedFileName ?? (fileUrl.isNotEmpty ? '(File tersimpan di cloud, tap untuk ganti)' : 'Pilih file...'),
                      style: TextStyle(
                        fontSize: 13,
                        color: pickedFileName != null ? kTextDark : kTextLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ketC,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan Tambahan',
                    prefixIcon: Icon(Icons.notes_outlined, color: kAccent),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: uploading ? null : () async {
                    if (judulC.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Nama file tidak boleh kosong'), backgroundColor: Colors.orange),
                      );
                      return;
                    }
                    setModal(() => uploading = true);
                    try {
                      if (pickedFileBytes != null && pickedFileName != null) {
                        fileUrl = await DataService.uploadArsipFile(pickedFileBytes!, pickedFileName!);
                      }
                      final a = Arsip(
                        id: existing?.id ?? _uuid.v4(),
                        judul: judulC.text.trim(),
                        kategori: _currentPath,
                        deskripsi: deskC.text.trim(),
                        nomorSurat: nomorC.text.trim(),
                        tanggal: tanggal,
                        pembuatId: sekbid,
                        fileUrl: fileUrl,
                        keterangan: ketC.text.trim(),
                      );
                      if (existing == null) {
                        await DataService.addArsip(a);
                        final folderName = _currentPath.isEmpty ? 'Root (/)' : _currentPath;
                        await NotificationService.notifyUpdate(
                          title: 'File Arsip Ditambahkan',
                          message: 'File "${a.judul}" ditambahkan di folder $folderName oleh ${widget.username}',
                          category: 'arsip',
                          actor: widget.username,
                        );
                      } else {
                        await DataService.updateArsip(a);
                        final folderName = _currentPath.isEmpty ? 'Root (/)' : _currentPath;
                        await NotificationService.notifyUpdate(
                          title: 'File Arsip Diperbarui',
                          message: 'File "${a.judul}" di folder $folderName diperbarui oleh ${widget.username}',
                          category: 'arsip',
                          actor: widget.username,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    } catch (e) {
                      setModal(() => uploading = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: uploading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(existing == null ? 'Simpan File' : 'Perbarui File',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── File Detail & Action Modal ─────────────────────────────────────────────
  void _showFileDetail(Arsip a) {
    bool loading = false;
    bool downloading = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: [
                _fileFormatBadge(a.fileUrl, a.judul),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.judul, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark)),
                  Text('Lokasi: ${a.kategori.isEmpty ? "Root (/)" : a.kategori}', style: const TextStyle(fontSize: 11, color: kTextMid)),
                ])),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _detailRow('Tanggal', DateFormat('dd MMMM yyyy', 'id').format(a.tanggal)),
              if (a.nomorSurat.isNotEmpty) _detailRow('Nomor Dokumen', a.nomorSurat),
              if (a.pembuatId.isNotEmpty) _detailRow('Diupload Oleh', a.pembuatId),
              if (a.deskripsi.isNotEmpty) _detailRow('Deskripsi', a.deskripsi),
              if (a.keterangan.isNotEmpty) _detailRow('Keterangan', a.keterangan),
              const SizedBox(height: 20),

              // Open file button
              if (a.fileUrl.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.visibility_rounded, size: 18),
                    label: Text(loading ? 'Membuka File...' : 'Buka File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: (loading || downloading) ? null : () async {
                      setModal(() => loading = true);
                      try {
                        final fileName = _getFileNameWithExt(a.fileUrl, a.judul);
                        final file = await _downloadToTemp(a.fileUrl, fileName);
                        if (file != null) {
                          await OpenFilex.open(file.path);
                        } else {
                          final url = Uri.parse(a.fileUrl);
                          if (await canLaunchUrl(url)) {
                            launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        }
                      } catch (_) {
                        final url = Uri.parse(a.fileUrl);
                        if (await canLaunchUrl(url)) {
                          launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      } finally {
                        if (ctx.mounted) setModal(() => loading = false);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: downloading
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: kAccent))
                          : const Icon(Icons.download_rounded, size: 16),
                      label: Text(downloading ? 'Mengunduh...' : 'Unduh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: (loading || downloading) ? null : () async {
                        setModal(() => downloading = true);
                        try {
                          if (a.fileUrl.isEmpty) {
                            throw Exception('File tidak memiliki URL unduhan');
                          }
                          final fileName = _getFileNameWithExt(a.fileUrl, a.judul);

                          // Tampilkan notifikasi awal bahwa download sedang berjalan
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text('Sedang mengunduh: $fileName...')),
                                  ],
                                ),
                                backgroundColor: kPrimaryDark,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }

                          await NotificationService.showImmediate(
                            id: NotificationService.idFromString('download_$fileName'),
                            title: 'Mengunduh File',
                            body: 'Sedang mengunduh "$fileName"...',
                            username: widget.username,
                          );

                          final response = await http.get(Uri.parse(a.fileUrl));
                          if (response.statusCode != 200) {
                            throw Exception('Gagal mengunduh file (HTTP ${response.statusCode})');
                          }

                          File? savedFile;
                          String locationName = 'Downloads';

                          // 1. Coba folder Downloads publik di Android
                          try {
                            final downloadsDir = Directory('/storage/emulated/0/Download');
                            if (await downloadsDir.exists()) {
                              final f = File('${downloadsDir.path}/$fileName');
                              await f.writeAsBytes(response.bodyBytes);
                              savedFile = f;
                              locationName = 'Downloads';
                            }
                          } catch (_) {}

                          // 2. Coba external storage directory
                          if (savedFile == null) {
                            try {
                              final extDir = await getExternalStorageDirectory();
                              if (extDir != null) {
                                final f = File('${extDir.path}/$fileName');
                                await f.writeAsBytes(response.bodyBytes);
                                savedFile = f;
                                locationName = 'Penyimpanan Eksternal';
                              }
                            } catch (_) {}
                          }

                          // 3. Coba app documents directory
                          if (savedFile == null) {
                            try {
                              final docDir = await getApplicationDocumentsDirectory();
                              final f = File('${docDir.path}/$fileName');
                              await f.writeAsBytes(response.bodyBytes);
                              savedFile = f;
                              locationName = 'Dokumen Aplikasi';
                            } catch (_) {}
                          }

                          // 4. Fallback ke temporary directory
                          if (savedFile == null) {
                            final tempDir = await getTemporaryDirectory();
                            final f = File('${tempDir.path}/$fileName');
                            await f.writeAsBytes(response.bodyBytes);
                            savedFile = f;
                            locationName = 'Penyimpanan Sementara';
                          }

                          await NotificationService.showImmediate(
                            id: NotificationService.idFromString('download_done_$fileName'),
                            title: 'Unduhan Selesai',
                            body: 'File "$fileName" berhasil diunduh ke $locationName',
                            username: widget.username,
                          );

                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('Tersimpan di $locationName: $fileName')),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                action: SnackBarAction(
                                  label: 'Buka',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    if (savedFile != null) {
                                      OpenFilex.open(savedFile.path);
                                    }
                                  },
                                ),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Gagal unduh: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          if (ctx.mounted) setModal(() => downloading = false);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Bagikan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        try {
                          final fileName = _getFileNameWithExt(a.fileUrl, a.judul);
                          final file = await _downloadToTemp(a.fileUrl, fileName);
                          if (file != null) {
                            await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: a.judul));
                          } else {
                            await SharePlus.instance.share(ShareParams(text: '${a.judul}\n${a.fileUrl}'));
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Gagal bagikan: $e'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ],

              // Actions: Move, Edit, Delete
              if (_canEdit) ...[
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.drive_file_move_outlined, size: 16),
                      label: const Text('Pindahkan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showMoveDialog([a]);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showFileForm(existing: a);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: const Text('Hapus File?'),
                          content: Text('File "${a.judul}" akan dihapus permanen.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: const Text('Hapus'),
                              onPressed: () => Navigator.pop(d, true),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      await DataService.deleteArsip(a.id);
                      final folderName = a.kategori.isEmpty ? 'Root (/)' : a.kategori;
                      await NotificationService.notifyUpdate(
                        title: 'File Arsip Dihapus',
                        message: 'File "${a.judul}" di folder $folderName telah dihapus oleh ${widget.username}',
                        category: 'arsip',
                        actor: widget.username,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      await _load();
                    },
                    child: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 12, color: kTextLight))),
        const Text(': ', style: TextStyle(fontSize: 12, color: kTextLight)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark))),
      ],
    ),
  );

  Widget _fileFormatBadge(String url, String judul) {
    String ext = 'FILE';
    Color badgeColor = Colors.blueGrey;
    IconData iconData = Icons.insert_drive_file_rounded;

    if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      final seg = uri.pathSegments.lastOrNull ?? '';
      if (seg.contains('.')) {
        ext = seg.split('.').last.toUpperCase();
      }
    }

    if (ext == 'PDF') {
      badgeColor = Colors.red.shade700;
      iconData = Icons.picture_as_pdf_rounded;
    } else if (ext.contains('DOC')) {
      badgeColor = Colors.blue.shade700;
      iconData = Icons.description_rounded;
    } else if (ext.contains('XLS')) {
      badgeColor = Colors.green.shade700;
      iconData = Icons.table_chart_rounded;
    } else if (ext.contains('PPT')) {
      badgeColor = Colors.orange.shade700;
      iconData = Icons.slideshow_rounded;
    } else if (['JPG', 'JPEG', 'PNG', 'WEBP'].contains(ext)) {
      badgeColor = Colors.purple.shade600;
      iconData = Icons.image_rounded;
    } else if (ext == 'ZIP' || ext == 'RAR' || ext == '7Z') {
      badgeColor = Colors.amber.shade800;
      iconData = Icons.archive_rounded;
    } else if (ext == 'TXT') {
      badgeColor = Colors.blueGrey.shade700;
      iconData = Icons.text_snippet_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: badgeColor.withAlpha(80)),
      ),
      child: Column(
        children: [
          Icon(iconData, color: badgeColor, size: 22),
          const SizedBox(height: 2),
          Text(ext, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor)),
        ],
      ),
    );
  }

  String _getFileNameWithExt(String url, String judul) {
    final uri = Uri.parse(url);
    final seg = uri.pathSegments.lastOrNull ?? '';
    final ext = seg.contains('.') ? '.${seg.split('.').last}' : '';
    if (judul.endsWith(ext)) return judul;
    return '$judul$ext';
  }

  Future<File?> _downloadToTemp(String url, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    if (await file.exists()) return file;
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return file;
    }
    return null;
  }

  // ── UI BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final subfolders = _currentSubfolders;
    final files = _currentFiles;
    final bool isEmpty = subfolders.isEmpty && files.isEmpty;

    return Scaffold(
      backgroundColor: kBg,
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          // Breadcrumb Navigation
          _buildBreadcrumbsBar(),

          // Search and View Controls Bar
          _buildToolbar(),

          // Main Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kAccent))
                : isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: kAccent,
                        child: _viewMode == ViewMode.list
                            ? _buildListView(subfolders, files)
                            : _buildGridView(subfolders, files),
                      ),
          ),

          // Bottom Clipboard Bar
          if (_clipboardMode != ClipboardMode.none) _buildClipboardBar(),
        ],
      ),
      floatingActionButton: _canEdit && !_isSelectionMode ? _buildFloatingActionButtons() : null,
    );
  }

  // Normal App Bar
  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('File Manager Arsip'),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: Icon(_viewMode == ViewMode.list ? Icons.grid_view_rounded : Icons.view_list_rounded),
          tooltip: _viewMode == ViewMode.list ? 'Tampilan Grid' : 'Tampilan List',
          onPressed: () => setState(() => _viewMode = _viewMode == ViewMode.list ? ViewMode.grid : ViewMode.list),
        ),
        PopupMenuButton<SortMode>(
          icon: const Icon(Icons.sort_rounded),
          tooltip: 'Urutkan File',
          onSelected: (m) => setState(() => _sortMode = m),
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: SortMode.dateNewest,
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, size: 16, color: kAccent),
                  SizedBox(width: 10),
                  Text('Terbaru'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: SortMode.dateOldest,
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 16, color: kTextMid),
                  SizedBox(width: 10),
                  Text('Terlama'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: SortMode.nameAsc,
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha_rounded, size: 16, color: kAccent),
                  SizedBox(width: 10),
                  Text('Nama (A - Z)'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: SortMode.nameDesc,
              child: Row(
                children: [
                  Icon(Icons.sort_by_alpha_rounded, size: 16, color: kAccent),
                  SizedBox(width: 10),
                  Text('Nama (Z - A)'),
                ],
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.checklist_rounded),
          tooltip: 'Pilih Banyak',
          onPressed: () => setState(() => _isSelectionMode = true),
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Segarkan',
          onPressed: _load,
        ),
      ],
    );
  }

  // Selection Mode App Bar
  AppBar _buildSelectionAppBar() {
    return AppBar(
      backgroundColor: kPrimaryDark,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _clearSelection,
      ),
      title: Text('$_selectedCount Dipilih', style: const TextStyle(fontSize: 16)),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all_rounded),
          tooltip: 'Pilih Semua',
          onPressed: _selectAll,
        ),
        if (_selectedCount > 0 && _canEdit)
          IconButton(
            icon: const Icon(Icons.drive_file_move_outlined),
            tooltip: 'Pindahkan ke Folder',
            onPressed: () {
              final files = _allArsip.where((a) => _selectedFileIds.contains(a.id)).toList();
              final folders = _selectedFolderPaths.toList();
              _showMoveDialog(files, foldersToMove: folders);
            },
          ),
        if (_selectedFileIds.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: 'Kompres ke ZIP',
            onPressed: _archiveSelectedToZip,
          ),
          IconButton(
            icon: const Icon(Icons.content_copy_rounded),
            tooltip: 'Salin',
            onPressed: _copySelected,
          ),
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.content_cut_rounded),
              tooltip: 'Potong (Move)',
              onPressed: _cutSelected,
            ),
        ],
        if (_canEdit && _selectedCount > 0)
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            tooltip: 'Hapus',
            onPressed: _deleteSelected,
          ),
      ],
    );
  }

  // Breadcrumb Path Bar
  Widget _buildBreadcrumbsBar() {
    final segments = _pathSegments;
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (_currentPath.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: kAccent),
                tooltip: 'Naik 1 Tingkat',
                onPressed: _goUp,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              const SizedBox(width: 4),
            ],
            InkWell(
              onTap: () => _navigateToPath(''),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _currentPath.isEmpty ? kAccent.withAlpha(20) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.home_rounded, size: 16, color: _currentPath.isEmpty ? kAccent : kTextMid),
                    const SizedBox(width: 4),
                    Text(
                      'Root',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _currentPath.isEmpty ? FontWeight.bold : FontWeight.normal,
                        color: _currentPath.isEmpty ? kAccent : kTextDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (int i = 0; i < segments.length; i++) ...[
              const Icon(Icons.chevron_right, size: 16, color: kTextLight),
              InkWell(
                onTap: () => _navigateToPath(segments.sublist(0, i + 1).join('/')),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: i == segments.length - 1 ? kAccent.withAlpha(20) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    segments[i],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == segments.length - 1 ? FontWeight.bold : FontWeight.normal,
                      color: i == segments.length - 1 ? kAccent : kTextDark,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Toolbar (Search, Filter, Sort)
  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                onChanged: (val) => setState(() => _search = val),
                decoration: InputDecoration(
                  hintText: 'Cari dalam folder ini...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: kBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_sortMode == SortMode.dateNewest ? Icons.sort_rounded : Icons.filter_list_rounded, color: kAccent),
            tooltip: 'Ganti Urutan',
            onPressed: () {
              setState(() {
                if (_sortMode == SortMode.dateNewest) {
                  _sortMode = SortMode.nameAsc;
                } else if (_sortMode == SortMode.nameAsc) {
                  _sortMode = SortMode.dateOldest;
                } else {
                  _sortMode = SortMode.dateNewest;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // Clipboard Bottom Bar
  Widget _buildClipboardBar() {
    final count = _clipboardFiles.length + _clipboardFolders.length;
    final isCut = _clipboardMode == ClipboardMode.cut;
    return Container(
      color: isCut ? Colors.orange.shade900 : kPrimaryDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(isCut ? Icons.content_cut_rounded : Icons.content_copy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count item ${isCut ? "akan dipindahkan" : "disalin"} ke ${_currentPath.isEmpty ? "Root" : _currentPath}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            ElevatedButton(
              onPressed: _pasteClipboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isCut ? Colors.orange.shade900 : kPrimaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Tempel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: _cancelClipboard,
              tooltip: 'Batal',
            ),
          ],
        ),
      ),
    );
  }

  // List View Mode
  Widget _buildListView(List<String> subfolders, List<Arsip> files) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      children: [
        // Subfolders
        if (subfolders.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('FOLDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextLight, letterSpacing: 0.5)),
          ),
          ...subfolders.map((path) {
            final folderName = path.split('/').last;
            final isSelected = _selectedFolderPaths.contains(path);
            final childCount = _allArsip
                .where((a) => (a.kategori == path || a.kategori.startsWith('$path/')) &&
                    a.keterangan != '__folder__' &&
                    a.nomorSurat != '__dir__')
                .length;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? kAccent.withAlpha(20) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? kAccent : Colors.transparent),
                boxShadow: [BoxShadow(color: kPrimary.withAlpha(40), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: ListTile(
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleFolderSelection(path);
                  } else {
                    _navigateToPath(path);
                  }
                },
                onLongPress: () => _toggleFolderSelection(path),
                leading: _isSelectionMode
                    ? Checkbox(
                        value: isSelected,
                        activeColor: kAccent,
                        onChanged: (_) => _toggleFolderSelection(path),
                      )
                    : Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: kAccent.withAlpha(25), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.folder_rounded, color: kAccent, size: 24),
                      ),
                title: Text(folderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark)),
                subtitle: Text('$childCount item di dalamnya', style: const TextStyle(fontSize: 11, color: kTextLight)),
                trailing: _isSelectionMode
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_canEdit)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, size: 18, color: kTextLight),
                              onSelected: (val) async {
                                if (val == 'move') {
                                  _showMoveDialog([], foldersToMove: [path]);
                                }
                                if (val == 'rename') _showRenameFolderDialog(path);
                                if (val == 'delete') {
                                  _selectedFolderPaths.add(path);
                                  await _deleteSelected();
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'move',
                                  child: Row(
                                    children: [
                                      Icon(Icons.drive_file_move_outlined, size: 16, color: kPrimaryDark),
                                      SizedBox(width: 8),
                                      Text('Pindahkan Folder'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16, color: kAccent),
                                      SizedBox(width: 8),
                                      Text('Ganti Nama'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Hapus Folder', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          const Icon(Icons.chevron_right, color: kTextLight, size: 18),
                        ],
                      ),
              ),
            );
          }),
          const SizedBox(height: 12),
        ],

        // Files
        if (files.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text('DOKUMEN & FILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextLight, letterSpacing: 0.5)),
          ),
          ...files.map((a) {
            final isSelected = _selectedFileIds.contains(a.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? kAccent.withAlpha(20) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? kAccent : Colors.transparent),
                boxShadow: [BoxShadow(color: kPrimary.withAlpha(40), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: ListTile(
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleFileSelection(a.id);
                  } else {
                    _showFileDetail(a);
                  }
                },
                onLongPress: () => _toggleFileSelection(a.id),
                leading: _isSelectionMode
                    ? Checkbox(
                        value: isSelected,
                        activeColor: kAccent,
                        onChanged: (_) => _toggleFileSelection(a.id),
                      )
                    : _fileFormatBadge(a.fileUrl, a.judul),
                title: Text(a.judul, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextDark), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  [
                    if (a.nomorSurat.isNotEmpty) 'No. ${a.nomorSurat}',
                    DateFormat('dd MMM yyyy', 'id').format(a.tanggal),
                  ].join(' • '),
                  style: const TextStyle(fontSize: 11, color: kTextMid),
                ),
                trailing: const Icon(Icons.chevron_right, color: kTextLight, size: 18),
              ),
            );
          }),
        ],
      ],
    );
  }

  // Grid View Mode
  Widget _buildGridView(List<String> subfolders, List<Arsip> files) {
    return CustomScrollView(
      slivers: [
        if (subfolders.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('FOLDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextLight, letterSpacing: 0.5)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.9,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final path = subfolders[idx];
                  final folderName = path.split('/').last;
                  final isSelected = _selectedFolderPaths.contains(path);
                  final childCount = _allArsip
                      .where((a) => (a.kategori == path || a.kategori.startsWith('$path/')) &&
                          a.keterangan != '__folder__' &&
                          a.nomorSurat != '__dir__')
                      .length;
                  return InkWell(
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleFolderSelection(path);
                      } else {
                        _navigateToPath(path);
                      }
                    },
                    onLongPress: () => _toggleFolderSelection(path),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? kAccent.withAlpha(25) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? kAccent : Colors.transparent, width: 1.5),
                        boxShadow: [BoxShadow(color: kPrimary.withAlpha(40), blurRadius: 4, offset: const Offset(0, 1))],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_rounded, color: kAccent, size: 36),
                          const SizedBox(height: 6),
                          Text(
                            folderName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: kTextDark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          Text('$childCount file', style: const TextStyle(fontSize: 10, color: kTextLight)),
                        ],
                      ),
                    ),
                  );
                },
                childCount: subfolders.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],

        if (files.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('DOKUMEN & FILE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kTextLight, letterSpacing: 0.5)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, idx) {
                  final a = files[idx];
                  final isSelected = _selectedFileIds.contains(a.id);
                  return InkWell(
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleFileSelection(a.id);
                      } else {
                        _showFileDetail(a);
                      }
                    },
                    onLongPress: () => _toggleFileSelection(a.id),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? kAccent.withAlpha(25) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? kAccent : Colors.transparent, width: 1.5),
                        boxShadow: [BoxShadow(color: kPrimary.withAlpha(40), blurRadius: 4, offset: const Offset(0, 1))],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _fileFormatBadge(a.fileUrl, a.judul),
                          const SizedBox(height: 6),
                          Text(
                            a.judul,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: kTextDark),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: files.length,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open_rounded, size: 64, color: kTextLight),
          const SizedBox(height: 12),
          Text(
            _search.isNotEmpty ? 'Tidak ada hasil untuk "$_search"' : 'Folder ini masih kosong',
            style: const TextStyle(fontSize: 15, color: kTextMid, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text('Gunakan tombol + di bawah untuk membuat folder atau upload file',
              style: TextStyle(fontSize: 12, color: kTextLight)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'fab_folder',
          onPressed: _showCreateFolderDialog,
          backgroundColor: Colors.white,
          foregroundColor: kAccent,
          tooltip: 'Buat Folder Baru',
          child: const Icon(Icons.create_new_folder_rounded),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'fab_file',
          onPressed: () => _showFileForm(),
          backgroundColor: kAccent,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Tambah File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
