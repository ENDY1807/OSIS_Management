import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/localization_service.dart';
import '../services/notification_service.dart';

class NotificationCenterSheet extends StatefulWidget {
  final String username;
  final Function(int tabIndex)? onNavigateToTab;

  const NotificationCenterSheet({
    super.key,
    required this.username,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    required String username,
    Function(int tabIndex)? onNavigateToTab,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => NotificationCenterSheet(
        username: username,
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }

  @override
  State<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  String _selectedCategory = 'all'; // 'all', 'unread', 'arsip', 'laporan', 'proker', 'pelanggaran'
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final list = await NotificationService.getNotifications(forUser: widget.username);
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  List<AppNotification> get _filteredList {
    if (_selectedCategory == 'unread') {
      return _notifications.where((n) => !n.isRead).toList();
    }
    if (_selectedCategory == 'all') {
      return _notifications;
    }
    return _notifications.where((n) {
      final cat = n.category.toLowerCase();
      if (_selectedCategory == 'laporan') {
        return cat.contains('laporan');
      }
      return cat == _selectedCategory;
    }).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  int? _getTabIndexForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('proker')) return 0;
    if (cat.contains('laporan')) return 1;
    if (cat.contains('arsip')) return 2;
    if (cat.contains('pelanggaran')) return 3;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    final isSmallScreen = screenWidth < 360;

    // Hitung tinggi adaptif sesuai layar HP
    final sheetHeight = screenHeight < 600
        ? screenHeight * 0.90
        : (screenHeight * 0.82).clamp(480.0, 780.0);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131A26) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: isDark ? const Border(top: BorderSide(color: Color(0xFF263348), width: 1)) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF263348) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Utama (Responsif)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 14 : 20),
            child: Row(
              children: [
                // Icon Badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.notifications_active_rounded, color: primary, size: isSmallScreen ? 20 : 22),
                ),
                const SizedBox(width: 10),

                // Judul & Badge Jumlah Belum Dibaca
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          LocalizationService.tr('notifications'),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 15 : 17,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$_unreadCount baru',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Close Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 18,
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Bar Tombol Aksi Cepat (Baca Semua & Hapus Semua)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 14 : 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Riwayat aktivitas sistem',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_unreadCount > 0)
                      InkWell(
                        onTap: () async {
                          await NotificationService.markAllAsRead(forUser: widget.username);
                          await _loadNotifications();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.done_all_rounded, size: 14, color: primary),
                              const SizedBox(width: 4),
                              Text(
                                'Baca Semua',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_unreadCount > 0 && _notifications.isNotEmpty)
                      const SizedBox(width: 8),
                    if (_notifications.isNotEmpty)
                      InkWell(
                        onTap: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('Hapus Semua Notifikasi?'),
                              content: const Text('Semua riwayat notifikasi akan dibersihkan secara permanen.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Batal')),
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await NotificationService.clearAll(forUser: widget.username);
                            await _loadNotifications();
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.delete_sweep_rounded, size: 14, color: Colors.redAccent),
                              const SizedBox(width: 4),
                              Text(
                                'Hapus Semua',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
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

          const SizedBox(height: 10),

          // Horizontal Filter Chips Bar
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 14 : 20),
              children: [
                _buildFilterChip(id: 'all', label: 'Semua (${_notifications.length})', isDark: isDark, primary: primary),
                const SizedBox(width: 6),
                _buildFilterChip(id: 'unread', label: 'Belum Dibaca ($_unreadCount)', isDark: isDark, primary: primary, isRed: _unreadCount > 0),
                const SizedBox(width: 6),
                _buildFilterChip(id: 'laporan', label: 'Laporan', isDark: isDark, primary: primary),
                const SizedBox(width: 6),
                _buildFilterChip(id: 'proker', label: 'Proker', isDark: isDark, primary: primary),
                const SizedBox(width: 6),
                _buildFilterChip(id: 'pelanggaran', label: 'Pelanggaran', isDark: isDark, primary: primary),
                const SizedBox(width: 6),
                _buildFilterChip(id: 'arsip', label: 'Arsip', isDark: isDark, primary: primary),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Divider(height: 1, color: isDark ? const Color(0xFF263348) : const Color(0xFFE2E8F0)),

          // Daftar Notifikasi
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: primary))
                : _filteredList.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: 10,
                        ),
                        itemCount: _filteredList.length,
                        itemBuilder: (ctx, idx) {
                          final n = _filteredList[idx];
                          return _buildNotificationCard(
                            notification: n,
                            isDark: isDark,
                            primary: primary,
                            isSmallScreen: isSmallScreen,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String id,
    required String label,
    required bool isDark,
    required Color primary,
    bool isRed = false,
  }) {
    final isSelected = _selectedCategory == id;
    final activeColor = isRed && id == 'unread' ? Colors.redAccent : primary;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_outlined,
                size: 40,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedCategory == 'unread'
                  ? 'Semua notifikasi sudah dibaca'
                  : 'Belum ada notifikasi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _selectedCategory == 'unread'
                  ? 'Tidak ada notifikasi baru yang perlu diperiksa.'
                  : 'Aktivitas pembaruan data akan muncul di sini secara otomatis.',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required AppNotification notification,
    required bool isDark,
    required Color primary,
    required bool isSmallScreen,
  }) {
    IconData iconData;
    Color iconColor;
    switch (notification.category.toLowerCase()) {
      case 'arsip':
        iconData = Icons.folder_shared_rounded;
        iconColor = primary;
        break;
      case 'laporan':
      case 'laporan_kegiatan':
        iconData = Icons.article_rounded;
        iconColor = const Color(0xFF0284C7);
        break;
      case 'proker':
        iconData = Icons.assignment_turned_in_rounded;
        iconColor = Colors.orange.shade800;
        break;
      case 'pelanggaran':
        iconData = Icons.warning_amber_rounded;
        iconColor = Colors.red.shade700;
        break;
      case 'manajemen':
      case 'siswa':
      case 'jenis_pelanggaran':
        iconData = Icons.tune_rounded;
        iconColor = Colors.indigo;
        break;
      default:
        iconData = Icons.notifications_rounded;
        iconColor = Colors.teal;
    }

    final timeStr = DateFormat('dd MMM, HH:mm', 'id').format(notification.timestamp);
    final targetTab = _getTabIndexForCategory(notification.category);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Hapus',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            SizedBox(width: 6),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
      onDismissed: (_) async {
        await NotificationService.deleteNotification(notification.id);
        setState(() {
          _notifications.removeWhere((item) => item.id == notification.id);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: notification.isRead
              ? (isDark ? const Color(0xFF182232) : Colors.white)
              : (isDark ? const Color(0xFF1E2D44) : const Color(0xFFF0FDF4)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? (isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0))
                : (isDark ? primary.withAlpha(120) : primary.withAlpha(80)),
            width: notification.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 30 : 10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              if (!notification.isRead) {
                await NotificationService.markAsRead(notification.id);
                setState(() {
                  final idx = _notifications.indexWhere((item) => item.id == notification.id);
                  if (idx != -1) {
                    _notifications[idx] = AppNotification(
                      id: notification.id,
                      title: notification.title,
                      body: notification.body,
                      timestamp: notification.timestamp,
                      category: notification.category,
                      actor: notification.actor,
                      isRead: true,
                    );
                  }
                });
              }
              if (targetTab != null && widget.onNavigateToTab != null && mounted) {
                Navigator.pop(context);
                widget.onNavigateToTab!(targetTab);
              }
            },
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Category dengan status unread dot
                  Stack(
                    children: [
                      Container(
                        width: isSmallScreen ? 36 : 40,
                        height: isSmallScreen ? 36 : 40,
                        decoration: BoxDecoration(
                          color: iconColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(iconData, color: iconColor, size: isSmallScreen ? 18 : 22),
                      ),
                      if (!notification.isRead)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF1E2D44) : Colors.white,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),

                  // Isi Notifikasi (Text responsif)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Judul & Tanggal
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 9 : 10,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Body Notifikasi
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Footer (Actor & Shortcut Buka Modul)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 12,
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      notification.actor.isNotEmpty ? notification.actor : 'Sistem',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 9 : 10,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (targetTab != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Buka Modul',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 9 : 10,
                                        fontWeight: FontWeight.bold,
                                        color: primary,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 8, color: primary),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
