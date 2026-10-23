import 'package:flutter/material.dart';

/// Palet warna Khas Nusantara Tradisional Modern
class NusantaraColors {
  // Soga & Songket Gold / Kuning Kunyit
  static const Color gold = Color(0xFFD97706);
  static const Color goldLight = Color(0xFFFBBF24);
  static const Color goldDark = Color(0xFF92400E);
  static const Color goldWarm = Color(0xFFC27803);

  // Deep Indigo / Navy Tradisional
  static const Color batikNavy = Color(0xFF1E3A8A);
  static const Color batikDeep = Color(0xFF0F172A);
  static const Color batikMidnight = Color(0xFF0A0F1D);

  // Kayu Jati / Terakota Nusantara / Bata Merah
  static const Color terracotta = Color(0xFFB45309);
  static const Color jatiWood = Color(0xFF78350F);
  static const Color bataMerah = Color(0xFF991B1B);

  // Daun Pandan / Hijau Pupus
  static const Color pandanGreen = Color(0xFF059669);
  static const Color pandanLight = Color(0xFF10B981);
  static const Color pandanDark = Color(0xFF065F46);

  // Pringgondani Ivory / Krem Tradisional Lembut
  static const Color ivoryLight = Color(0xFFFAF7F2);
  static const Color ivoryCard = Color(0xFFF5EFE6);
}

/// Custom Painter kosong (Seluruh motif batik dihapus sesuai permintaan).
class ModernKawungPainter extends CustomPainter {
  final Color color;
  final double scale;

  const ModernKawungPainter({
    required this.color,
    this.scale = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Motif batik dihapus
  }

  @override
  bool shouldRepaint(covariant ModernKawungPainter oldDelegate) => false;
}

/// Custom Painter kosong (Seluruh motif batik dihapus sesuai permintaan).
class BatikParangPainter extends CustomPainter {
  final Color color;
  final double scale;

  const BatikParangPainter({
    required this.color,
    this.scale = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Motif batik dihapus
  }

  @override
  bool shouldRepaint(covariant BatikParangPainter oldDelegate) => false;
}

/// Custom Painter motif Batik Sekar Jagad kosong (Seluruh motif batik dihapus sesuai permintaan).
class BatikSekarJagadPainter extends CustomPainter {
  final Color? baseColor;
  final double scale;
  final bool isDarkBackground;

  const BatikSekarJagadPainter({
    this.baseColor,
    this.scale = 80.0,
    this.isDarkBackground = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Motif batik dihapus
  }

  @override
  bool shouldRepaint(covariant BatikSekarJagadPainter oldDelegate) => false;
}

/// Custom Painter motif Mega Mendung kosong (Seluruh motif batik dihapus sesuai permintaan).
class ModernMegaMendungPainter extends CustomPainter {
  final Color color;
  final double scale;
  final bool fillMode;
  final bool usePhotoPalette;

  const ModernMegaMendungPainter({
    required this.color,
    this.scale = 90.0,
    this.fillMode = false,
    this.usePhotoPalette = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Motif batik dihapus
  }

  @override
  bool shouldRepaint(covariant ModernMegaMendungPainter oldDelegate) => false;
}

/// Pita Aksen Halus di bagian atas card atau header (tanpa motif batik)
class BatikAccentBar extends StatelessWidget {
  final double height;
  final Color? color1;
  final Color? color2;

  const BatikAccentBar({
    super.key,
    this.height = 3,
    this.color1,
    this.color2,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c1 = color1 ?? NusantaraColors.gold;
    final c2 = color2 ?? theme.colorScheme.primary;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c1, c2, c1],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

/// Kartu Modern Bersih & Elegan (Tanpa Motif Batik)
class BatikCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool showBatikPattern;
  final double batikOpacity;
  final Color? borderColor;
  final Color? backgroundColor;

  const BatikCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.showBatikPattern = false,
    this.batikOpacity = 0.0,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ?? (isDark ? const Color(0xFF131B2A) : Colors.white);
    final border = borderColor ?? (isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0));

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    return content;
  }
}

/// Banner Header Modern & Bersih (Tanpa Motif Batik)
class NusantaraHeaderBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? trailing;
  final String? badgeText;
  final Color? accentColor;
  final bool showBatik;

  const NusantaraHeaderBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.trailing,
    this.badgeText,
    this.accentColor,
    this.showBatik = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = accentColor ?? theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? primary.withAlpha(40) : primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primary.withAlpha(120),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Icon(icon, color: primary, size: 24),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badgeText != null && badgeText!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: primary.withAlpha(isDark ? 45 : 30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: primary.withAlpha(140), width: 0.9),
                    ),
                    child: Text(
                      badgeText!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: primary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Lencana / Badge Modern
class NusantaraBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isGold;

  const NusantaraBadge({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = color ?? (isGold ? NusantaraColors.gold : theme.colorScheme.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: baseColor.withAlpha(isDark ? 40 : 25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: baseColor.withAlpha(130),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: baseColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: baseColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero Banner Modern Elegan (Tanpa Motif Batik)
class MegaMendungHeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;
  final String? badgeText;
  final Color? accentColor;

  const MegaMendungHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.badgeText,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A),
                  const Color(0xFF1E293B),
                ]
              : [
                  const Color(0xFF1E293B),
                  const Color(0xFF334155),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFF475569),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Icon Avatar Modern
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withAlpha(40),
                width: 1.1,
              ),
            ),
            child: Center(
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
          const SizedBox(width: 14),

          // Judul & Keterangan
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badgeText != null && badgeText!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(60),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accent.withAlpha(140), width: 0.8),
                    ),
                    child: Text(
                      badgeText!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCBD5E1),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Kartu Modern Bersih & Rapi (Tanpa Motif Batik)
class MegaMendungCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool showPattern;

  const MegaMendungCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
    this.backgroundColor,
    this.showPattern = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ?? (isDark ? const Color(0xFF131B2A) : Colors.white);
    final border = borderColor ?? (isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0));

    Widget content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 30 : 6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      );
    }
    return content;
  }
}
