import 'package:flutter/material.dart';
import '../services/auth_service.dart';
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
    final username = _userC.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Username tidak boleh kosong.');
      return;
    }
    if (_passC.text.isEmpty) {
      setState(() => _error = 'Password tidak boleh kosong.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    // Cek password dulu (instan, tidak perlu async)
    final uname = username.toUpperCase();
    final ok = AuthService.checkPassword(uname, _passC.text);
    if (!mounted) return;

    if (ok) {
      // Navigasi langsung, simpan session di background
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
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_grad1, _grad2],
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
                  // Top section
                  Expanded(
                    flex: 4,
                    child: FadeTransition(
                      opacity: _fade,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/logo.png', width: 80, height: 80, fit: BoxFit.contain),
                          const SizedBox(height: 16),
                          const Text('OSIS Manager',
                            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold,
                                color: Colors.white, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text('Sistem Manajemen OSIS Digital',
                            style: TextStyle(fontSize: 13, color: Colors.white.withAlpha(200))),
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
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Masuk',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                            const SizedBox(height: 4),
                            Text('Masukkan username dan password',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                            const SizedBox(height: 24),

                            // Username field
                            _inputBox(
                              controller: _userC,
                              hint: 'Username',
                              icon: Icons.person_outline_rounded,
                              capitalization: TextCapitalization.characters,
                              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            ),
                            const SizedBox(height: 12),

                            // Password field
                            _passwordBox(),
                            const SizedBox(height: 12),

                            if (_error != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade100),
                                ),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(_error!,
                                      style: TextStyle(color: Colors.red.shade600, fontSize: 12))),
                                ]),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Login button
                            SizedBox(
                              height: 52,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [_grad1, _grad2]),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [BoxShadow(color: _grad2.withAlpha(80), blurRadius: 12, offset: const Offset(0, 4))],
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
                                      : const Text('Masuk',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Center(child: Text('OSIS © ${DateTime.now().year}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade400))),
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
    TextCapitalization capitalization = TextCapitalization.none,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: TextField(
        controller: controller,
        textCapitalization: capitalization,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(icon, color: _grad2, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _passwordBox() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: TextField(
        controller: _passC,
        obscureText: _obscure,
        onSubmitted: (_) => _login(),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: _grad2, size: 20),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.grey.shade400, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
