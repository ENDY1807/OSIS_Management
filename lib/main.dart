import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/pelanggaran_screen.dart';
import 'screens/rekap_screen.dart';
import 'screens/manajemen_screen.dart';
import 'screens/proker_screen.dart';
import 'screens/arsip_screen.dart';
import 'screens/laporan_screen.dart';
import 'screens/admin_settings_screen.dart';
import 'services/data_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/app_settings_service.dart';
import 'services/localization_service.dart';
import 'widgets/user_settings_sheet.dart';
import 'models/models.dart';
import 'screens/login_screen.dart';
import 'app_theme.dart';
import 'package:intl/intl.dart';
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
  List<Widget>? _cachedScreens;

  static const _superUsers = ['KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA'];

  bool get _isAdmin     => _username == 'ADMIN' || AuthService.getRole(_username) == 'ADMIN';
  bool get _isPembina   => _isAdmin || _username == 'PEMBINA' || _username == 'KESISWAAN' || AuthService.getRole(_username) == 'PEMBINA' || AuthService.getRole(_username) == 'KESISWAAN';
  bool get _isSuperUser => _isAdmin || _isPembina || _superUsers.contains(_username) || _superUsers.contains(AuthService.getRole(_username));
  bool get _isSekbid2   => _username == 'SEKBID2' || AuthService.getRole(_username) == 'SEKBID2';
  bool get _canAccessManajemen => _isSuperUser || _isSekbid2;
  bool get _canReceiveNotifications => NotificationService.isTargetRole(_username) || _isAdmin;

  String _displayName = '';
  StreamSubscription<String>? _dataSub;

  String get _roleDisplay => _displayName.isNotEmpty ? _displayName : AuthService.getDisplayName(_username);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    if (mounted) {
      setState(() {
        _username = u;
        _displayName = d.isNotEmpty ? d : AuthService.getDisplayName(u);
        _cachedScreens = [
          ProkerScreen(username: _username),
          LaporanScreen(username: _username),
          ArsipScreen(key: _arsipKey, username: _username),
          PelanggaranScreen(username: _username),
          const RekapScreen(),
        ];
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
      DataService.notifyDataChanged('all');
    }
  }

  List<Widget> get _screens => _cachedScreens ?? [
    ProkerScreen(username: _username),
    LaporanScreen(username: _username),
    ArsipScreen(key: _arsipKey, username: _username),
    PelanggaranScreen(username: _username),
    const RekapScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final navItems = [
      (title: LocalizationService.tr('nav_proker'),      icon: Icons.assignment_outlined,    activeIcon: Icons.assignment_rounded),
      (title: LocalizationService.tr('nav_laporan'),     icon: Icons.article_outlined,       activeIcon: Icons.article_rounded),
      (title: LocalizationService.tr('nav_arsip'),       icon: Icons.folder_outlined,        activeIcon: Icons.folder_rounded),
      (title: LocalizationService.tr('nav_pelanggaran'), icon: Icons.warning_amber_rounded,  activeIcon: Icons.warning_rounded),
      (title: LocalizationService.tr('nav_rekap'),       icon: Icons.bar_chart_outlined,     activeIcon: Icons.bar_chart_rounded),
    ];

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
              ValueListenableBuilder<String>(
                valueListenable: AppSettingsService.logoUrlNotifier,
                builder: (context, logoUrl, _) {
                  if (logoUrl.isNotEmpty && Uri.tryParse(logoUrl)?.hasScheme == true) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        logoUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', width: 32, height: 32, fit: BoxFit.contain),
                      ),
                    );
                  }
                  return Image.asset('assets/logo.png', width: 32, height: 32, fit: BoxFit.contain);
                },
              ),
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
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    if (_username.isNotEmpty)
                      Text(
                        _roleDisplay,
                        style: const TextStyle(fontSize: 10, color: Colors.white70, letterSpacing: 0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            // Quick Toggle Theme Mode (Light / Dark)
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: isDark ? Colors.amberAccent : Colors.white70,
                size: 20,
              ),
              tooltip: isDark ? 'White Mode' : 'Dark Mode',
              onPressed: () {
                final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
                AppSettingsService.setThemeMode(newMode);
              },
            ),

            // Notification Bell
            if (_canReceiveNotifications)
              FutureBuilder<int>(
                future: NotificationService.getUnreadCount(forUser: _username),
                builder: (context, snap) {
                  final unread = snap.data ?? 0;
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

            // Tombol Manajemen untuk superUser, Pembina, Kesiswaan, Admin, dan SEKBID2
            if (_canAccessManajemen)
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 21),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManajemenScreen())),
                tooltip: LocalizationService.tr('nav_manajemen'),
              ),

            // Tombol Super Admin Panel (jika Admin)
            if (_isAdmin)
              IconButton(
                icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 22),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen())),
                tooltip: LocalizationService.tr('nav_admin'),
              ),

            // Settings Sheet Toggle untuk semua user
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 21),
              tooltip: LocalizationService.tr('nav_settings'),
              onPressed: () => UserSettingsSheet.show(context, username: _username),
            ),

            // Logout Button
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 21),
              tooltip: LocalizationService.tr('btn_logout'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(LocalizationService.tr('confirm_logout')),
                    content: Text('${LocalizationService.tr('logout_prompt')} ($_username)'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(LocalizationService.tr('btn_cancel'))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: Text(LocalizationService.tr('btn_logout')),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await AuthService.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  }
                }
              },
            ),
            const SizedBox(width: 4),
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

  void _showNotificationCenter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141D2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDark ? const Border(top: BorderSide(color: Color(0xFF243452), width: 1)) : null,
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF243452) : const Color(0xFFA2EBFB),
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
                      color: Theme.of(context).colorScheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications_active_rounded, color: Theme.of(context).colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.tr('notifications'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Text('Riwayat aktivitas Arsip, Laporan, & Proker',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await NotificationService.markAllAsRead(forUser: _username);
                      setState(() {});
                      setM(() {});
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: const Text('Baca Semua', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<AppNotification>>(
                  future: NotificationService.getNotifications(forUser: _username),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
                    }
                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            const Text('Belum ada notifikasi update',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            const Text('Aktivitas penambahan & perubahan data akan tampil di sini',
                                style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final n = list[idx];
                        IconData iconData;
                        Color iconColor;
                        switch (n.category) {
                          case 'arsip':
                            iconData = Icons.folder_shared_rounded;
                            iconColor = Theme.of(context).colorScheme.primary;
                            break;
                          case 'laporan':
                          case 'laporan_kegiatan':
                            iconData = Icons.article_rounded;
                            iconColor = const Color(0xFF0077B6);
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

                        final timeStr = DateFormat('dd MMM yyyy, HH:mm', 'id').format(n.timestamp);

                        return Dismissible(
                          key: Key(n.id),
                          direction: DismissDirection.startToEnd,
                          background: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Hapus Notifikasi',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          onDismissed: (direction) async {
                            await NotificationService.deleteNotification(n.id);
                            if (mounted) {
                              setState(() {});
                            }
                            setM(() {});
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            leading: Stack(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: iconColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 22),
                                ),
                                if (!n.isRead)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: n.isRead ? FontWeight.w600 : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(n.body, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                                const SizedBox(height: 4),
                                Text('$timeStr • Oleh: ${n.actor}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            onTap: () async {
                              await NotificationService.markAsRead(n.id);
                              setState(() {});
                              setM(() {});
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
