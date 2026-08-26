import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/app_settings_service.dart';
import '../services/localization_service.dart';
import '../main.dart';

const _grad1 = Color(0xFF67F3CE);
const _grad2 = Color(0xFF4899EA);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _userC = TextEditingController();
  final _passC = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  late AnimationController _anim;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _userC.dispose();
    _passC.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final rawUsername = _userC.text.trim();
    if (rawUsername.isEmpty) {
      setState(() => _error = 'Username tidak boleh kosong.');
      return;
    }
    if (_passC.text.isEmpty) {
      setState(() => _error = 'Password tidak boleh kosong.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final uname = AuthService.normalizeUsername(rawUsername);
    final ok = await AuthService.authenticate(uname, _passC.text);
    if (!mounted) return;

    if (ok) {
      AuthService.saveSession(uname);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => const HomeScreen(),
          transitionsBuilder: (_, anim, _, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      setState(() {
        _error = 'Username atau password salah.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                : [_grad1, _grad2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              height: h - MediaQuery.of(context).padding.top,
              child: Column(
                children: [
                  // Top controls (Quick Theme & Lang)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Language switcher button
                        InkWell(
                          onTap: () {
                            final current = LocalizationService.currentLocale.value.languageCode;
                            LocalizationService.setLanguage(current == 'id' ? 'en' : 'id');
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(40),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  LocalizationService.currentLocale.value.languageCode == 'id' ? '🇮🇩 ID' : '🇬🇧 EN',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Dark/Light switcher button
                        IconButton(
                          icon: Icon(
                            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                            color: Colors.white,
                            size: 20,
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

                  // Top section / Logo & Title
                  Expanded(
                    flex: 4,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ValueListenableBuilder<String>(
                            valueListenable: AppSettingsService.logoUrlNotifier,
                            builder: (context, logoUrl, _) {
                              if (logoUrl.isNotEmpty && Uri.tryParse(logoUrl)?.hasScheme == true) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    logoUrl,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Image.asset('assets/logo.png', width: 80, height: 80, fit: BoxFit.contain),
                                  ),
                                );
                              }
                              return Image.asset('assets/logo.png', width: 80, height: 80, fit: BoxFit.contain);
                            },
                          ),
                          const SizedBox(height: 16),
                          ValueListenableBuilder<String>(
                            valueListenable: AppSettingsService.appNameNotifier,
                            builder: (context, appName, _) => Text(
                              appName,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                                  color: Colors.white, letterSpacing: 0.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ValueListenableBuilder<String>(
                            valueListenable: AppSettingsService.appSubtitleNotifier,
                            builder: (context, sub, _) => Text(
                              sub,
                              style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card form
                  SlideTransition(
                    position: _slide,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 80 : 30),
                              blurRadius: 20,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              LocalizationService.tr('btn_login'),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Masukkan username dan password',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Username field
                            _inputBox(
                              controller: _userC,
                              hint: LocalizationService.tr('username'),
                              icon: Icons.person_outline_rounded,
                              capitalization: TextCapitalization.characters,
                              isDark: isDark,
                              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 12),

                            // Password field
                            _passwordBox(isDark: isDark),
                            const SizedBox(height: 12),

                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(isDark ? 40 : 25),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!,
                                      style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700, fontSize: 12))),
                                ]),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Login button
                            SizedBox(
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primary.withAlpha(180)]
                                        : [_grad1, _grad2],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _grad2.withAlpha(80),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  child: _loading
                                      ? const SizedBox(width: 22, height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                      : Text(
                                          LocalizationService.tr('btn_login'),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.black : Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            ValueListenableBuilder<String>(
                              valueListenable: AppSettingsService.appNameNotifier,
                              builder: (_, appName, _) => Center(
                                child: Text('$appName © ${DateTime.now().year}',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey.shade400)),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _inputBox({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    TextCapitalization capitalization = TextCapitalization.none,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E8E8)),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: capitalization,
        onSubmitted: onSubmitted,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _passwordBox({required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE8E8E8)),
      ),
      child: TextField(
        controller: _passC,
        obscureText: _obscure,
        onSubmitted: (_) => _login(),
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: LocalizationService.tr('password'),
          hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
