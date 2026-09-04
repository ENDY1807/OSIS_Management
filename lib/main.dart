import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/pelanggaran_screen.dart';
import 'screens/rekap_screen.dart';
import 'screens/manajemen_screen.dart';
import 'screens/proker_screen.dart';
import 'screens/arsip_screen.dart';
import 'screens/laporan_screen.dart';
import 'services/data_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/app_settings_service.dart';
import 'services/localization_service.dart';
import 'widgets/user_settings_sheet.dart';
import 'widgets/sync_status_dialog.dart';
import 'widgets/notification_center_sheet.dart';
import 'screens/login_screen.dart';
import 'app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initializeDateFormatting('id', null);
  } catch (e) {
    debugPrint('DateFormatting init error: $e');
  }
  try {
    await AuthService.init();
  } catch (e) {
    debugPrint('AuthService init error: $e');
  }
  try {
    await AppSettingsService.init();
  } catch (e) {
    debugPrint('AppSettingsService init error: $e');
  }
  try {
    await SyncService.init();
  } catch (e) {
    debugPrint('SyncService init error: $e');
  }
  try {
    await DataService.initializeSupabase();
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }
  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('NotificationService init error: $e');
  }
  runApp(const OsisApp());
}

class OsisApp extends StatelessWidget {
  const OsisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocalizationService.currentLocale,
      builder: (context, currentLocale, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: AppSettingsService.themeModeNotifier,
          builder: (context, currentThemeMode, _) {
            return ValueListenableBuilder<Color>(
              valueListenable: AppSettingsService.accentColorNotifier,
              builder: (context, accentColor, _) {
                return ValueListenableBuilder<String>(
                  valueListenable: AppSettingsService.appNameNotifier,
                  builder: (context, appName, _) {
                    return MaterialApp(
                      title: appName,
                      debugShowCheckedModeBanner: false,
                      locale: currentLocale,
                      themeMode: currentThemeMode,
                      theme: buildAppTheme(isDark: false, primaryColor: accentColor),
                      darkTheme: buildAppTheme(isDark: true, primaryColor: accentColor),
                      scrollBehavior: const MaterialScrollBehavior().copyWith(
                        dragDevices: {
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.touch,
                          PointerDeviceKind.trackpad,
                          PointerDeviceKind.stylus,
                        },
                      ),
                      localizationsDelegates: const [
                        GlobalMaterialLocalizations.delegate,
                        GlobalWidgetsLocalizations.delegate,
                        GlobalCupertinoLocalizations.delegate,
                      ],
                      supportedLocales: const [
                        Locale('id', 'ID'),
                        Locale('en', 'US'),
                      ],
                      home: FutureBuilder<bool>(
                        future: AuthService.isLoggedIn(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const _SplashScreen();
                          }
                          return (snapshot.data ?? false) ? const HomeScreen() : const LoginScreen();
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _idx = 0;
  final List<int> _tabHistory = [0];
  DateTime? _lastBackPressTime;
  String _username = '';

  static const _superUsers = ['KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA'];

  bool get _isReadOnly  => AuthService.isReadOnly(_username);
  bool get _isAdmin     => !_isReadOnly && (_username == 'ADMIN' || AuthService.getRole(_username) == 'ADMIN');
  bool get _isPembina   => !_isReadOnly && (_isAdmin || _username == 'PEMBINA' || _username == 'KESISWAAN' || AuthService.getRole(_username) == 'PEMBINA' || AuthService.getRole(_username) == 'KESISWAAN');
  bool get _isSuperUser => !_isReadOnly && (_isAdmin || _isPembina || _superUsers.contains(_username) || _superUsers.contains(AuthService.getRole(_username)));
  bool get _isSekbid2   => !_isReadOnly && (_username == 'SEKBID2' || AuthService.getRole(_username) == 'SEKBID2');
  bool get _canAccessManajemen => !_isReadOnly && (_isSuperUser || _isSekbid2);
  bool get _canReceiveNotifications => !_isReadOnly && (NotificationService.isTargetRole(_username) || _isAdmin);

  String _displayName = '';
  StreamSubscription<String>? _dataSub;

  String get _roleDisplay => _displayName.isNotEmpty ? _displayName : AuthService.getDisplayName(_username);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.cancelAllSystemNotifications();
    _refreshUser();
    _dataSub = DataService.onDataChanged.listen((table) {
      if (table == 'accounts' || table == 'all') {
        _refreshUser();
      }
    });
  }

  final GlobalKey<ArsipScreenState> _arsipKey = GlobalKey<ArsipScreenState>();

  Future<void> _refreshUser() async {
    final u = await AuthService.getUserName() ?? '';
    final d = await AuthService.getCurrentDisplayName();
    await NotificationService.refreshUnreadCount(forUser: u);
    if (mounted) {
      setState(() {
        _username = u;
        _displayName = d.isNotEmpty ? d : AuthService.getDisplayName(u);
      });
    }
  }

  void _onTabSelected(int index) {
    if (_idx != index) {
      setState(() {
        _tabHistory.remove(index);
        _tabHistory.add(index);
        _idx = index;
      });
    }
  }

  void _handleBackPress() {
    // 1. If on Arsip tab and inside a subfolder, go up one folder level first
    if (_idx == 2 && _arsipKey.currentState?.canGoUp == true) {
      _arsipKey.currentState?.goUp();
      return;
    }

    // 2. Navigate back to previous tab if any in history
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
        _idx = _tabHistory.last;
      });
    } else if (_idx != 0) {
      setState(() {
        _idx = 0;
        _tabHistory.clear();
        _tabHistory.add(0);
      });
    } else {
      final now = DateTime.now();
      if (_lastBackPressTime == null || now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
        _lastBackPressTime = now;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    LocalizationService.tr('press_back_again_to_exit'),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService.cancelAllSystemNotifications();
      DataService.notifyDataChanged('all');
      SyncService.checkAndSync();
    }
  }

  List<Widget> get _screens => [
    ProkerScreen(key: ValueKey('proker_${_username}_${LocalizationService.currentLocale.value.languageCode}'), username: _username),
    LaporanScreen(key: ValueKey('laporan_${_username}_${LocalizationService.currentLocale.value.languageCode}'), username: _username),
    ArsipScreen(key: _arsipKey, username: _username),
    PelanggaranScreen(key: ValueKey('pelanggaran_${_username}_${LocalizationService.currentLocale.value.languageCode}'), username: _username),
    RekapScreen(key: ValueKey('rekap_${LocalizationService.currentLocale.value.languageCode}')),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final navItems = [
      (title: LocalizationService.tr('nav_proker'),      icon: Icons.assignment_outlined,    activeIcon: Icons.assignment_rounded),
      (title: LocalizationService.tr('nav_laporan'),     icon: Icons.article_outlined,       activeIcon: Icons.article_rounded),
      (title: LocalizationService.tr('nav_arsip'),       icon: Icons.folder_outlined,        activeIcon: Icons.folder_rounded),
      (title: LocalizationService.tr('nav_pelanggaran'), icon: Icons.warning_amber_rounded,  activeIcon: Icons.warning_rounded),
      (title: LocalizationService.tr('nav_rekap'),       icon: Icons.bar_chart_outlined,     activeIcon: Icons.bar_chart_rounded),
    ];

    if (isDesktop) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBackPress();
        },
        child: Scaffold(
          body: Row(
            children: [
              // Desktop Sidebar
              _buildDesktopSidebar(context, theme, isDark, primary, navItems),

              // Desktop Main Content
              Expanded(
                child: Column(
                  children: [
                    // Desktop Top Navigation Bar
                    Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            navItems[_idx].activeIcon,
                            size: 22,
                            color: primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            navItems[_idx].title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          // Quick Language Switcher
                          InkWell(
                            onTap: () {
                              final cur = LocalizationService.currentLocale.value.languageCode;
                              LocalizationService.setLanguage(cur == 'id' ? 'en' : 'id');
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                LocalizationService.currentLocale.value.languageCode == 'id' ? '🇮🇩 ID' : '🇬🇧 EN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Quick Theme Toggle
                          IconButton(
                            icon: Icon(
                              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              size: 20,
                              color: isDark ? Colors.amberAccent : const Color(0xFF64748B),
                            ),
                            tooltip: 'Ganti Tema',
                            onPressed: () {
                              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                              AppSettingsService.setThemeMode(newMode);
                            },
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(index: _idx, children: _screens),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPress();
      },
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0B0F17), const Color(0xFF131A26)]
                    : [primary, primary.withAlpha(210)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF263348) : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              AppSettingsService.buildLogoWidget(width: 32, height: 32, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: AppSettingsService.appNameNotifier,
                      builder: (context, appName, _) {
                        return Text(
                          appName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    if (_displayName.isNotEmpty || _username.isNotEmpty)
                      Text(
                        _roleDisplay,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70, letterSpacing: 0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // 1. Minimalist Single Dot Status (Kuning = Offline, Hijau = Online)
            ValueListenableBuilder<SyncStatus>(
              valueListenable: SyncService.statusNotifier,
              builder: (context, syncStatus, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: SyncService.pendingCountNotifier,
                  builder: (context, pendingCount, _) {
                    final isOnline = syncStatus == SyncStatus.online;
                    final isSyncing = syncStatus == SyncStatus.syncing;

                    // Hijau (#10B981) saat Online, Kuning (#F59E0B) saat Offline
                    final dotColor = isSyncing
                        ? Colors.lightBlueAccent
                        : (isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

                    final tooltipMsg = isSyncing
                        ? 'Sedang menyinkronkan data...'
                        : (isOnline
                            ? (pendingCount > 0 ? 'Online • $pendingCount antrean' : 'Online (Terhubung)')
                            : (pendingCount > 0 ? 'Offline • $pendingCount data tersimpan' : 'Mode Offline'));

                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Tooltip(
                          message: tooltipMsg,
                          child: InkWell(
                            onTap: () => SyncStatusDialog.show(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: dotColor.withAlpha(isDark ? 35 : 45),
                                shape: BoxShape.circle,
                                border: Border.all(color: dotColor.withAlpha(140), width: 1.2),
                              ),
                              child: Center(
                                child: isSyncing
                                    ? SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(strokeWidth: 1.8, color: dotColor),
                                      )
                                    : Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: dotColor.withAlpha(220),
                                              blurRadius: 5,
                                              spreadRadius: 0.8,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // 2. Notification Bell (Reaktif Real-time)
            if (_canReceiveNotifications)
              ValueListenableBuilder<int>(
                valueListenable: NotificationService.unreadCountNotifier,
                builder: (context, unread, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                          color: unread > 0 ? Colors.amberAccent : Colors.white70,
                          size: 22,
                        ),
                        tooltip: LocalizationService.tr('notifications'),
                        onPressed: _showNotificationCenter,
                      ),
                      if (unread > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),


            // 3. Tombol Manajemen (Akses Super Admin ada di pojok kanan atas layar Manajemen)
            if (_canAccessManajemen)
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 21),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManajemenScreen())),
                tooltip: LocalizationService.tr('nav_manajemen'),
              ),

            // 4. Settings Sheet Toggle untuk semua user (berisi Tema, Bahasa, Info Akun & Log Out)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 21),
              tooltip: LocalizationService.tr('nav_settings'),
              onPressed: () => UserSettingsSheet.show(context, username: _username),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: IndexedStack(index: _idx, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.navigationBarTheme.backgroundColor,
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 50 : 15),
                blurRadius: 16,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _idx,
            onDestinationSelected: (i) {
              _onTabSelected(i);
              DataService.notifyDataChanged('all');
            },
            backgroundColor: Colors.transparent,
            indicatorColor: primary.withAlpha(isDark ? 50 : 35),
            elevation: 0,
            destinations: navItems.map((item) => NavigationDestination(
              icon: Icon(item.icon, size: 22, color: isDark ? const Color(0xFF64748B) : Colors.grey),
              selectedIcon: Icon(item.activeIcon, size: 22, color: primary),
              label: item.title,
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color primary,
    List<({String title, IconData icon, IconData activeIcon})> navItems,
  ) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // App Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                AppSettingsService.buildLogoWidget(width: 40, height: 40, fit: BoxFit.contain),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ValueListenableBuilder<String>(
                        valueListenable: AppSettingsService.appNameNotifier,
                        builder: (context, appName, _) => Text(
                          appName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      ValueListenableBuilder<String>(
                        valueListenable: AppSettingsService.appSubtitleNotifier,
                        builder: (context, sub, _) => Text(
                          sub,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Navigation Destination Items
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final item = navItems[i];
                final isSelected = _idx == i;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _onTabSelected(i);
                      DataService.notifyDataChanged('all');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primary.withAlpha(isDark ? 50 : 25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: primary.withAlpha(isDark ? 140 : 80), width: 1)
                            : Border.all(color: Colors.transparent, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? item.activeIcon : item.icon,
                            size: 21,
                            color: isSelected
                                ? primary
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : primary)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Action Bar & User Profile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Actions Row (Sync status, Notifications, Management, Settings)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Sync Status
                    ValueListenableBuilder<SyncStatus>(
                      valueListenable: SyncService.statusNotifier,
                      builder: (context, syncStatus, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: SyncService.pendingCountNotifier,
                          builder: (context, pendingCount, _) {
                            final isOnline = syncStatus == SyncStatus.online;
                            final isSyncing = syncStatus == SyncStatus.syncing;
                            final dotColor = isSyncing
                                ? Colors.lightBlueAccent
                                : (isOnline ? const Color(0xFF10B981) : const Color(0xFFF59E0B));
                            final tooltipMsg = isSyncing
                                ? 'Sedang menyinkronkan data...'
                                : (isOnline
                                    ? (pendingCount > 0 ? 'Online • $pendingCount antrean' : 'Online')
                                    : (pendingCount > 0 ? 'Offline • $pendingCount data tersimpan' : 'Offline'));

                            return Tooltip(
                              message: tooltipMsg,
                              child: IconButton(
                                icon: Icon(
                                  isSyncing
                                      ? Icons.sync_rounded
                                      : (isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded),
                                  color: dotColor,
                                  size: 20,
                                ),
                                onPressed: () => SyncStatusDialog.show(context),
                                splashRadius: 18,
                              ),
                            );
                          },
                        );
                      },
                    ),

                    // Notifications
                    if (_canReceiveNotifications)
                      ValueListenableBuilder<int>(
                        valueListenable: NotificationService.unreadCountNotifier,
                        builder: (context, unread, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              IconButton(
                                icon: Icon(
                                  unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_outlined,
                                  color: unread > 0 ? Colors.amberAccent : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                  size: 20,
                                ),
                                tooltip: LocalizationService.tr('notifications'),
                                onPressed: _showNotificationCenter,
                                splashRadius: 18,
                              ),
                              if (unread > 0)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                    // Manajemen
                    if (_canAccessManajemen)
                      IconButton(
                        icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 20),
                        tooltip: LocalizationService.tr('nav_manajemen'),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManajemenScreen())),
                        splashRadius: 18,
                      ),

                    // Settings
                    IconButton(
                      icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 20),
                      tooltip: LocalizationService.tr('nav_settings'),
                      onPressed: () => UserSettingsSheet.show(context, username: _username),
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // User Info Card
                InkWell(
                  onTap: () => UserSettingsSheet.show(context, username: _username),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: primary.withAlpha(isDark ? 60 : 35),
                          child: Text(
                            _username.isNotEmpty ? _username[0].toUpperCase() : 'U',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _displayName.isNotEmpty ? _displayName : _username,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _roleDisplay,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNotificationCenter() {
    NotificationCenterSheet.show(
      context,
      username: _username,
      onNavigateToTab: (idx) {
        setState(() => _idx = idx);
      },
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();
  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _gradShift;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)));
    _gradShift = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(const Color(0xFF67F3CE), const Color(0xFF4899EA), _gradShift.value)!,
              Color.lerp(const Color(0xFF4899EA), const Color(0xFF03045E), _gradShift.value)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/logo.png', width: 100, height: 100, fit: BoxFit.contain),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<String>(
                    valueListenable: AppSettingsService.appNameNotifier,
                    builder: (context, appName, _) => Text(
                      appName,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ValueListenableBuilder<String>(
                    valueListenable: AppSettingsService.appSubtitleNotifier,
                    builder: (context, sub, _) => Text(
                      sub,
                      style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200)),
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
