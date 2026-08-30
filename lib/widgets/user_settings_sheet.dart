import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../screens/admin_settings_screen.dart';
import '../screens/login_screen.dart';

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
                          color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
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

                    if (isAdmin) ...[
                      // SECTION: WARNA AKSEN TEMA (HANYA ADMIN)
                      ValueListenableBuilder<Color>(
                        valueListenable: AppSettingsService.accentColorNotifier,
                        builder: (context, currentAccent, _) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    LocalizationService.tr('theme_color').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: currentAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: currentAccent.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Admin Saja', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 48,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: AppSettingsService.presets.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                                  itemBuilder: (context, i) {
                                    final p = AppSettingsService.presets[i];
                                    final isSel = currentAccent.toARGB32() == p.color.toARGB32();
                                    return InkWell(
                                      onTap: () => AppSettingsService.setAccentColor(p.color),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [p.color, p.darkColor],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          border: Border.all(
                                            color: isSel ? Colors.white : Colors.transparent,
                                            width: 2.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: p.color.withAlpha(isSel ? 140 : 60),
                                              blurRadius: isSel ? 10 : 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: isSel ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          );
                        },
                      ),
                    ],

                    // SECTION 2: BAHASA (DYNAMIC MULTI-LANGUAGE DARI ADMIN)
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
                    ValueListenableBuilder<List<String>>(
                      valueListenable: AppSettingsService.enabledLanguagesNotifier,
                      builder: (context, enabledCodes, _) {
                        final available = LocalizationService.allSupportedLanguages
                            .where((l) => enabledCodes.contains(l.code))
                            .toList();
                        final listToShow = available.isNotEmpty ? available : [LocalizationService.allSupportedLanguages.first];

                        return Container(
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              for (int i = 0; i < listToShow.length; i++) ...[
                                if (i > 0)
                                  Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
                                ListTile(
                                  leading: Text(listToShow[i].flag, style: const TextStyle(fontSize: 20)),
                                  title: Text(listToShow[i].name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  trailing: currentLocale.languageCode == listToShow[i].code
                                      ? Icon(Icons.check_circle_rounded, color: primary, size: 20)
                                      : Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey.shade400, size: 20),
                                  onTap: () => LocalizationService.setLanguage(listToShow[i].code),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
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
                          color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(Icons.account_circle_outlined, color: primary, size: 22),
                            title: Text(displayName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            subtitle: Text('ID: ${widget.username} • Role: $role', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
                          ),
                          if (isAdmin) ...[
                            Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
                            ListTile(
                              leading: Icon(Icons.password_rounded, color: primary, size: 22),
                              title: Text(LocalizationService.tr('change_password'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                              onTap: _showChangePasswordDialog,
                            ),
                            Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
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
                          ] else ...[
                            Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, size: 18, color: isDark ? Colors.white38 : Colors.black38),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Penggantian kata sandi dan konfigurasi akun hanya dapat dilakukan oleh Super Admin.',
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          Divider(height: 1, color: isDark ? const Color(0xFF243452) : const Color(0xFFE2E8F0)),
                          ListTile(
                            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                            title: Text(
                              LocalizationService.tr('btn_logout'),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.redAccent),
                            onTap: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(LocalizationService.tr('confirm_logout')),
                                  content: Text('${LocalizationService.tr('logout_prompt')} (${widget.username})'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(LocalizationService.tr('btn_cancel')),
                                    ),
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
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    (_) => false,
                                  );
                                }
                              }
                            },
                          ),
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
