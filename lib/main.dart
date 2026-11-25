import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/karakter_siswa_screen.dart';
import 'screens/manajemen_screen.dart';
import 'screens/proker_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profil_osis_screen.dart';
import 'screens/administrasi_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/informasi_dokumentasi_screen.dart';
import 'screens/evaluasi_screen.dart';
import 'services/data_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/app_settings_service.dart';
import 'services/localization_service.dart';
import 'widgets/notification_center_sheet.dart';
import 'widgets/user_settings_sheet.dart';
import 'screens/kas_osis_screen.dart';
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
  bool get _isKepsek    => !_isReadOnly && AuthService.isKepalaSekolah(_username);
  bool get _isPembina   => !_isReadOnly && (_isAdmin || _isKepsek || _username == 'PEMBINA' || _username == 'KESISWAAN' || AuthService.getRole(_username) == 'PEMBINA' || AuthService.getRole(_username) == 'KESISWAAN');
  bool get _isSuperUser => !_isReadOnly && (_isAdmin || _isKepsek || _isPembina || _superUsers.contains(_username) || _superUsers.contains(AuthService.getRole(_username)));
  bool get _isSekbid2   => !_isReadOnly && (_username == 'SEKBID2' || AuthService.getRole(_username) == 'SEKBID2');
  bool get _canAccessManajemen => !_isReadOnly && (_isSuperUser || _isSekbid2 || _isKepsek);
  bool get _canReceiveNotifications => !_isReadOnly && (NotificationService.isTargetRole(_username) || _isAdmin || _isKepsek);

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

  final GlobalKey<AdministrasiScreenState> _administrasiKey = GlobalKey<AdministrasiScreenState>();

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
    // 1. If on Administrasi tab and inside a subfolder, go up one folder level first
    if (_idx == 4 && _administrasiKey.currentState?.canGoUp == true) {
      _administrasiKey.currentState?.goUp();
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
    DashboardScreen(key: ValueKey('dash_$_username'), username: _username, onNavigateTab: _onTabSelected),
    ProfilOsisScreen(key: ValueKey('profil_$_username'), username: _username),
    ProkerScreen(key: ValueKey('proker_${_username}_${LocalizationService.currentLocale.value.languageCode}'), username: _username),
    AgendaScreen(key: ValueKey('agenda_$_username'), username: _username),
    AdministrasiScreen(key: _administrasiKey, username: _username),
    KasOsisScreen(key: ValueKey('kas_${_username}_${LocalizationService.currentLocale.value.languageCode}'), username: _username),
    InformasiDokumentasiScreen(key: ValueKey('infodok_$_username'), username: _username),
    EvaluasiScreen(key: ValueKey('evaluasi_$_username'), username: _username),
    KarakterSiswaScreen(key: ValueKey('karakter_${_username}_${LocalizationService.currentLocale.value.languageCode}'), username: _username),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final navItems = [
      (title: 'Beranda',           icon: Icons.dashboard_outlined,             activeIcon: Icons.dashboard_rounded),
      (title: 'Profil & Pengurus', icon: Icons.badge_outlined,                 activeIcon: Icons.badge_rounded),
      (title: 'Program Kerja',     icon: Icons.assignment_outlined,            activeIcon: Icons.assignment_rounded),
      (title: 'Kalender & Agenda', icon: Icons.calendar_month_outlined,        activeIcon: Icons.calendar_month_rounded),
      (title: 'Administrasi',      icon: Icons.folder_shared_outlined,         activeIcon: Icons.folder_shared_rounded),
      (title: 'Kas & Absensi',     icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
      (title: 'Pengumuman & Media',icon: Icons.campaign_outlined,              activeIcon: Icons.campaign_rounded),
      (title: 'Evaluasi & Rekap',  icon: Icons.rate_review_outlined,           activeIcon: Icons.rate_review_rounded),
      (title: 'Karakter Siswa',    icon: Icons.verified_user_outlined,         activeIcon: Icons.verified_user_rounded),
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
              _buildSidebarContent(context, theme, isDark, primary, navItems, isDrawer: false),

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

                          // 1. Notification Center Bell
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
                                        size: 21,
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
                                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
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

                          // 3. Manajemen Button
                          if (_canAccessManajemen)
                            IconButton(
                              icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 21),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManajemenScreen())),
                              tooltip: LocalizationService.tr('nav_manajemen'),
                            ),

                          // 4. Quick Language Switcher
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
                                LocalizationService.currentLocale.value.languageCode == 'id' ? 'ID' : 'EN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),

                          // 5. Quick Theme Toggle
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

                          // 6. Settings & Log Out Toggle
                          IconButton(
                            icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 21),
                            tooltip: LocalizationService.tr('nav_settings'),
                            onPressed: () => UserSettingsSheet.show(context, username: _username),
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
        drawer: Drawer(
          width: 295,
          child: _buildSidebarContent(
            context,
            theme,
            isDark,
            primary,
            navItems,
            isDrawer: true,
          ),
        ),
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0B0F17), const Color(0xFF131A26)]
                    : [primary, primary.withAlpha(215)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          leading: Builder(
            builder: (scaffoldCtx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
              tooltip: 'Buka Menu Navigasi',
              onPressed: () => Scaffold.of(scaffoldCtx).openDrawer(),
            ),
          ),
          title: Row(
            children: [
              AppSettingsService.buildLogoWidget(width: 30, height: 30, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      navItems[_idx].title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.2),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: AppSettingsService.appNameNotifier,
                      builder: (context, appName, _) {
                        return Text(
                          appName,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // 1. Notification Bell (Reaktif Real-time)
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
      ),
    );
  }

  Widget _buildSidebarContent(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    Color primary,
    List<({String title, IconData icon, IconData activeIcon})> navItems, {
    required bool isDrawer,
  }) {
    // Menu grouped into clear categories
    final menuCategories = [
      (
        title: 'MENU UTAMA',
        indices: [0, 1], // Beranda, Profil & Pengurus
      ),
      (
        title: 'PROGRAM & KEGIATAN',
        indices: [2, 3, 6], // Program Kerja, Kalender & Agenda, Pengumuman & Media
      ),
      (
        title: 'TATA KELOLA & KEUANGAN',
        indices: [4, 5], // Administrasi, Kas & Absensi
      ),
      (
        title: 'EVALUASI & MONITORING',
        indices: [7, 8], // Evaluasi & Rekap, Karakter Siswa
      ),
    ];

    return Container(
      width: isDrawer ? double.infinity : 260,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: isDrawer
            ? null
            : Border(
                right: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
      ),
      child: SafeArea(
        top: isDrawer,
        bottom: true,
        child: Column(
          children: [
            // App Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF131C2E)
                    : primary.withAlpha(12),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  AppSettingsService.buildLogoWidget(width: 42, height: 42, fit: BoxFit.contain),
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
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: 0.2,
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
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDrawer)
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                      tooltip: 'Tutup Menu',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),

            // Navigation Destination Categories
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  for (final group in menuCategories) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 12, bottom: 6),
                      child: Text(
                        group.title,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    for (final idx in group.indices) ...[
                      Builder(builder: (context) {
                        final item = navItems[idx];
                        final isSelected = _idx == idx;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (isDrawer) {
                                Navigator.of(context).pop();
                              }
                              _onTabSelected(idx);
                              DataService.notifyDataChanged('all');
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primary.withAlpha(isDark ? 50 : 25)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(color: primary.withAlpha(isDark ? 140 : 80), width: 1)
                                    : Border.all(color: Colors.transparent, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.activeIcon : item.icon,
                                    size: 20,
                                    color: isSelected
                                        ? primary
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected
                                            ? (isDark ? Colors.white : primary)
                                            : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 2),
                    ],
                  ],
                ],
              ),
            ),

            // Bottom Action Bar & User Profile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  // Quick Actions Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Quick Theme Toggle
                      IconButton(
                        icon: Icon(
                          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          size: 19,
                          color: isDark ? Colors.amberAccent : const Color(0xFF64748B),
                        ),
                        tooltip: 'Ganti Tema',
                        onPressed: () {
                          final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                          AppSettingsService.setThemeMode(newMode);
                        },
                        splashRadius: 18,
                      ),

                      // Quick Language Switcher
                      InkWell(
                        onTap: () {
                          final cur = LocalizationService.currentLocale.value.languageCode;
                          LocalizationService.setLanguage(cur == 'id' ? 'en' : 'id');
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            LocalizationService.currentLocale.value.languageCode == 'id' ? 'ID' : 'EN',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                            ),
                          ),
                        ),
                      ),

                      // Manajemen (jika ada akses)
                      if (_canAccessManajemen)
                        IconButton(
                          icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 19),
                          tooltip: LocalizationService.tr('nav_manajemen'),
                          onPressed: () {
                            if (isDrawer) Navigator.of(context).pop();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ManajemenScreen()));
                          },
                          splashRadius: 18,
                        ),

                      // Settings
                      IconButton(
                        icon: Icon(Icons.settings_outlined, color: isDark ? Colors.white70 : const Color(0xFF64748B), size: 19),
                        tooltip: LocalizationService.tr('nav_settings'),
                        onPressed: () {
                          if (isDrawer) Navigator.of(context).pop();
                          UserSettingsSheet.show(context, username: _username);
                        },
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // User Info Card
                  InkWell(
                    onTap: () {
                      if (isDrawer) Navigator.of(context).pop();
                      UserSettingsSheet.show(context, username: _username);
                    },
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
