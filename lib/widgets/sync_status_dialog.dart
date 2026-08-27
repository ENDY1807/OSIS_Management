import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sync_service.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';

class SyncStatusDialog extends StatefulWidget {
  const SyncStatusDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SyncStatusDialog(),
    );
  }

  @override
  State<SyncStatusDialog> createState() => _SyncStatusDialogState();
}

class _SyncStatusDialogState extends State<SyncStatusDialog> {
  bool _isProcessing = false;
  String? _statusMessage;
  List<SyncAction> _pendingItems = [];

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    final list = await SyncService.getQueue();
    if (mounted) {
      setState(() {
        _pendingItems = list;
      });
    }
  }

  Future<void> _triggerManualSync() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    final online = await SyncService.checkConnection();
    if (!online) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Gagal: Perangkat sedang offline atau server tidak dapat dijangkau.';
        });
      }
      return;
    }

    // Jalankan flush antrean
    final success = await SyncService.flushQueue();

    // Lakukan pull data terbaru dari server
    try {
      await DataService.syncPendingChanges();
      await AuthService.syncWithSupabase();
    } catch (_) {}

    await _loadQueue();

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _statusMessage = success
            ? 'Sinkronisasi berhasil! Semua data telah tersinkron ke cloud.'
            : 'Beberapa item belum berhasil tersinkron. Akan dicoba lagi secara otomatis.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.statusNotifier,
      builder: (context, syncStatus, _) {
        return ValueListenableBuilder<int>(
          valueListenable: SyncService.pendingCountNotifier,
          builder: (context, pendingCount, _) {
            return ValueListenableBuilder<DateTime?>(
              valueListenable: SyncService.lastSyncTimeNotifier,
              builder: (context, lastSyncTime, _) {
                final isOnline = syncStatus == SyncStatus.online;
                final isSyncing = syncStatus == SyncStatus.syncing || _isProcessing;

                final statusColor = isSyncing
                    ? Colors.blueAccent
                    : (isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

                final statusText = isSyncing
                    ? 'Sedang Menyinkronkan...'
                    : (isOnline ? 'Online (Terhubung)' : 'Offline (Mode Lokal)');

                final lastSyncFormatted = lastSyncTime != null
                    ? DateFormat('dd MMM yyyy, HH:mm:ss', 'id').format(lastSyncTime)
                    : 'Belum pernah';

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131A26) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 100 : 30),
                        blurRadius: 20,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 20,
                    right: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Handle bar
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: statusColor.withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSyncing
                                  ? Icons.sync_rounded
                                  : (isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded),
                              color: statusColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Status Sinkronisasi & Jaringan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Info Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Data Tertunda (Pending)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: pendingCount > 0
                                        ? const Color(0xFFF59E0B).withAlpha(40)
                                        : const Color(0xFF10B981).withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pendingCount > 0 ? '$pendingCount Item' : 'Semua Tersinkron',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: pendingCount > 0
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Sinkron Terakhir',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                Text(
                                  lastSyncFormatted,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Daftar item pending jika ada
                      if (_pendingItems.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Rincian Antrean (${_pendingItems.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 140),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _pendingItems.length,
                            separatorBuilder: (_, __) => const Divider(height: 8),
                            itemBuilder: (context, idx) {
                              final item = _pendingItems[idx];
                              return Row(
                                children: [
                                  Icon(
                                    item.actionType == SyncActionType.delete
                                        ? Icons.delete_outline_rounded
                                        : (item.actionType == SyncActionType.insert
                                            ? Icons.add_circle_outline_rounded
                                            : Icons.edit_outlined),
                                    size: 16,
                                    color: item.actionType == SyncActionType.delete
                                        ? Colors.redAccent
                                        : primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${item.table.toUpperCase()} • ${item.actionType.name}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('HH:mm').format(item.createdAt),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],

                      if (_statusMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _statusMessage!.contains('berhasil')
                                ? const Color(0xFF10B981).withAlpha(20)
                                : const Color(0xFFEF4444).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _statusMessage!.contains('berhasil')
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // Tombol Aksi
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSyncing
                                  ? null
                                  : () async {
                                      setState(() => _isProcessing = true);
                                      await SyncService.checkConnection();
                                      await _loadQueue();
                                      if (mounted) {
                                        setState(() => _isProcessing = false);
                                      }
                                    },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Cek Jaringan'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: isSyncing ? null : _triggerManualSync,
                              icon: isSyncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_rounded, size: 18),
                              label: Text(
                                isSyncing ? 'Menyinkronkan...' : 'Sinkronkan Sekarang',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
