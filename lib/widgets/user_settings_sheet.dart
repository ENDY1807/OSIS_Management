import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../screens/admin_settings_screen.dart';

class UserSettingsSheet extends StatefulWidget {
  final String username;
  const UserSettingsSheet({super.key, required this.username});

  static void show(BuildContext context, {required String username}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserSettingsSheet(username: username),
    );
  }

  @override
  State<UserSettingsSheet> createState() => _UserSettingsSheetState();
}

class _UserSettingsSheetState extends State<UserSettingsSheet> {
  void _showChangePasswordDialog() {
    final passC = TextEditingController();
    final confirmC = TextEditingController();
    bool obscure1 = true;
    bool obscure2 = true;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(LocalizationService.tr('change_password')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passC,
                obscureText: obscure1,
                decoration: InputDecoration(
                  labelText: LocalizationService.tr('new_password'),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setD(() => obscure1 = !obscure1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmC,
                obscureText: obscure2,
                decoration: InputDecoration(
                  labelText: 'Konfirmasi Password',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setD(() => obscure2 = !obscure2),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(LocalizationService.tr('btn_cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                if (passC.text.trim().isEmpty) {
                  setD(() => error = 'Password tidak boleh kosong');
                  return;
                }
                if (passC.text != confirmC.text) {
                  setD(() => error = 'Konfirmasi password tidak cocok');
                  return;
                }
                await AuthService.changePassword(widget.username, passC.text.trim());
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(LocalizationService.tr('msg_saved')),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              child: Text(LocalizationService.tr('btn_save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final role = AuthService.getRole(widget.username);
    final displayName = AuthService.getDisplayName(widget.username);
    final isAdmin = role == 'ADMIN' || widget.username == 'ADMIN';

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettingsService.themeModeNotifier,
        builder: (context, currentThemeMode, _) {
          return ValueListenableBuilder<Locale>(
            valueListenable: LocalizationService.currentLocale,
            builder: (context, currentLocale, _) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primary.withAlpha(isDark ? 50 : 25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.settings_rounded, color: primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationService.tr('settings_title'),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                '$displayName (${widget.username})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SECTION 1: TEMA (DARK / WHITE / SYSTEM)
                    Text(
                      LocalizationService.tr('theme_mode').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          _themeOptionButton(
                            title: LocalizationService.tr('theme_light'),
                            icon: Icons.light_mode_rounded,
                            selected: currentThemeMode == ThemeMode.light,
                            onTap: () => AppSettingsService.setThemeMode(ThemeMode.light),
                            primary: primary,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _themeOptionButton(
                            title: LocalizationService.tr('theme_dark'),
                            icon: Icons.dark_mode_rounded,
                            selected: currentThemeMode == ThemeMode.dark,
                            onTap: () => AppSettingsService.setThemeMode(ThemeMode.dark),
                            primary: primary,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 6),
                          _themeOptionButton(
                            title: LocalizationService.tr('theme_system'),
                            icon: Icons.brightness_auto_rounded,
                            selected: currentThemeMode == ThemeMode.system,
                            onTap: () => AppSettingsService.setThemeMode(ThemeMode.system),
                            primary: primary,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SECTION 2: BAHASA (LANGUAGE ID / EN)
                    Text(
                      LocalizationService.tr('language').toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Text('🇮🇩', style: TextStyle(fontSize: 20)),
                            title: const Text('Bahasa Indonesia', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            trailing: currentLocale.languageCode == 'id'
                                ? Icon(Icons.check_circle_rounded, color: primary, size: 20)
                                : Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey.shade400, size: 20),
                            onTap: () => LocalizationService.setLanguage('id'),
                          ),
                          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ListTile(
                            leading: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                            title: const Text('English', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            trailing: currentLocale.languageCode == 'en'
                                ? Icon(Icons.check_circle_rounded, color: primary, size: 20)
                                : Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey.shade400, size: 20),
                            onTap: () => LocalizationService.setLanguage('en'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SECTION 3: AKUN & KEAMANAN
                    Text(
                      'AKUN & KEAMANAN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.password_rounded, color: primary, size: 22),
                            title: Text(LocalizationService.tr('change_password'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            onTap: _showChangePasswordDialog,
                          ),
                          if (isAdmin) ...[
                            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ListTile(
                              leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 24),
                              title: const Text('Konfigurasi Super Admin', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber)),
                              subtitle: const Text('Ganti tema, warna, logo, branding & kelola seluruh akun', style: TextStyle(fontSize: 11)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.amber),
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AdminSettingsScreen()),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // FOOTER APP INFO
                    Center(
                      child: ValueListenableBuilder<String>(
                        valueListenable: AppSettingsService.appNameNotifier,
                        builder: (context, appName, child) {
                          return Text(
                            '$appName • v1.0.1+6\nMade for OSIS Management System',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                              height: 1.4,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _themeOptionButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color primary,
    required bool isDark,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? primary.withAlpha(isDark ? 60 : 35) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: selected ? Border.all(color: primary, width: 1.5) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? primary : (isDark ? Colors.white60 : Colors.black54),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                title.replaceAll(' Mode', '').replaceAll(' (Light)', ''),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? primary : (isDark ? Colors.white70 : Colors.black87),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
