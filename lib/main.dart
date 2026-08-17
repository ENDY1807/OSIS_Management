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
import 'services/notification_service.dart';
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
    return MaterialApp(
      title: 'OSIS Management',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
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
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _idx = 0;
  String _username = '';
  List<Widget>? _cachedScreens;

  static const _superUsers = ['KETUA', 'WAKIL', 'SEKRETARIS', 'BENDAHARA'];

  bool get _isPembina   => _username == 'PEMBINA' || _username == 'KESISWAAN';
  bool get _isSuperUser => _superUsers.contains(_username);
  bool get _canAccessManajemen => _isSuperUser || _isPembina || _username == 'SEKBID2';
  bool get _canReceiveNotifications => NotificationService.isTargetRole(_username);

  static const _roleLabel = {
    'PEMBINA'    : 'Pembina OSIS',
    'KESISWAAN'  : 'Staf Kesiswaan',
    'KETUA'      : 'Ketua OSIS',
    'WAKIL'      : 'Wakil Ketua OSIS',
    'SEKRETARIS' : 'Sekretaris OSIS',
    'BENDAHARA'  : 'Bendahara OSIS',
    'SEKBID1'    : 'Sekbid Keimanan & Takwa',
    'SEKBID2'    : 'Sekbid Budi Pekerti',
    'SEKBID3'    : 'Sekbid Kepribadian',
    'SEKBID4'    : 'Sekbid Prestasi Akademik',
    'SEKBID5'    : 'Sekbid Demokrasi',
    'SEKBID6'    : 'Sekbid Kreativitas',
    'SEKBID7'    : 'Sekbid Kesehatan',
    'SEKBID8'    : 'Sekbid Sastra & Budaya',
    'SEKBID9'    : 'Sekbid Teknologi Informasi',
    'SEKBID10'   : 'Sekbid Komunikasi & Bahasa',
  };

  String get _roleDisplay => _roleLabel[_username] ?? _username;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.getUserName().then((v) => setState(() {
      _username = v ?? '';
      _cachedScreens = [
        ProkerScreen(username: _username),
        LaporanScreen(username: _username),
        ArsipScreen(username: _username),
        PelanggaranScreen(username: _username),
        const RekapScreen(),
      ];
    }));
  }

  @override
  void dispose() {
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
    ArsipScreen(username: _username),
    PelanggaranScreen(username: _username),
    const RekapScreen(),
  ];

  static const _navItems = [
    (title: 'Proker',      icon: Icons.assignment_outlined,    activeIcon: Icons.assignment_rounded),
    (title: 'Laporan',     icon: Icons.article_outlined,       activeIcon: Icons.article_rounded),
    (title: 'Arsip',       icon: Icons.folder_outlined,        activeIcon: Icons.folder_rounded),
    (title: 'Pelanggaran', icon: Icons.warning_amber_rounded,  activeIcon: Icons.warning_rounded),
    (title: 'Rekap',       icon: Icons.bar_chart_outlined,     activeIcon: Icons.bar_chart_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF03045E), Color(0xFF0077B6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: Row(
          children: [
            Image.asset('assets/logo.png', width: 34, height: 34, fit: BoxFit.contain),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('OSIS Management',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                  if (_username.isNotEmpty)
                    Text('Login sebagai: $_roleDisplay',
                      style: const TextStyle(fontSize: 10.5, color: Colors.white60, letterSpacing: 0.2)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Notification Bell untuk KETUA, WAKIL, SEKRETARIS, BENDAHARA, PEMBINA, KESISWAAN
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
                      tooltip: 'Notifikasi Update',
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
          // Tombol Manajemen untuk superUser, Pembina, dan SEKBID2
          if (_canAccessManajemen)
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 22),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManajemenScreen())),
              tooltip: 'Manajemen',
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 22),
            tooltip: 'Logout',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Konfirmasi Logout'),
                  content: Text('Logout dari akun $_username?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await AuthService.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(// ignore: use_build_context_synchronously
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
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
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 16, offset: const Offset(0, -2))],
        ),
        child: NavigationBar(
          selectedIndex: _idx,
          onDestinationSelected: (i) {
            setState(() => _idx = i);
            DataService.notifyDataChanged('all');
          },
          backgroundColor: Colors.transparent,
          indicatorColor: Theme.of(context).colorScheme.primary.withAlpha(35),
          elevation: 0,
          destinations: _navItems.map((item) => NavigationDestination(
            icon: Icon(item.icon, size: 22, color: Colors.grey),
            selectedIcon: Icon(item.activeIcon, size: 22, color: Theme.of(context).colorScheme.primary),
            label: item.title,
          )).toList(),
        ),
      ),
    );
  }

  void _showNotificationCenter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: kAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pusat Notifikasi & Update',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark)),
                        Text('Riwayat aktivitas Arsip, Laporan, & Proker',
                            style: TextStyle(fontSize: 11, color: kTextMid)),
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
                      return const Center(child: CircularProgressIndicator(color: kAccent));
                    }
                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            const Text('Belum ada notifikasi update',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kTextMid)),
                            const SizedBox(height: 4),
                            const Text('Aktivitas penambahan & perubahan data akan tampil di sini',
                                style: TextStyle(fontSize: 11, color: kTextLight), textAlign: TextAlign.center),
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
                            iconColor = kAccent;
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
                            iconColor = kTextDark;
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
                                color: kTextDark,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(n.body, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                const SizedBox(height: 4),
                                Text('$timeStr • Oleh: ${n.actor}',
                                    style: const TextStyle(fontSize: 10, color: kTextMid)),
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
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
                  Container(
                    width: 90, height: 90,
                    decoration: BoxDecoration(color: Colors.white.withAlpha(40), shape: BoxShape.circle),
                    padding: const EdgeInsets.all(14),
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 20),
                  const Text('OSIS Manager',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text('Sistem Manajemen OSIS Digital',
                    style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
