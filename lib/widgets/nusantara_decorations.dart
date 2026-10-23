import 'package:flutter/material.dart';

/// Palet warna Khas Nusantara Tradisional Modern
class NusantaraColors {
  // Soga & Songket Gold / Kuning Kunyit
  static const Color gold = Color(0xFFD97706);
  static const Color goldLight = Color(0xFFFBBF24);
  static const Color goldDark = Color(0xFF92400E);

  // Deep Indigo / Navy Batik Tradisional
  static const Color batikNavy = Color(0xFF1E3A8A);
  static const Color batikDeep = Color(0xFF0F172A);

  // Kayu Jati / Terakota Nusantara
  static const Color terracotta = Color(0xFFB45309);
  static const Color jatiWood = Color(0xFF78350F);

  // Daun Pandan / Hijau Pupus (Simbol kesuburan alam nusantara)
  static const Color pandanGreen = Color(0xFF059669);
  static const Color pandanLight = Color(0xFF10B981);
}

/// Custom Painter motif Batik Kawung Minimalis Modern.
/// Didesain sangat halus, elegan, dan subtle agar tidak ramai/cluttered.
class ModernKawungPainter extends CustomPainter {
  final Color color;
  final double scale;

  const ModernKawungPainter({
    required this.color,
    this.scale = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    final dotPaint = Paint()
      ..color = color.withAlpha(200)
      ..style = PaintingStyle.fill;

    final step = scale;
    final r = step * 0.45;

    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        // Lingkaran kelopak kawung lembut
        canvas.drawCircle(Offset(x, y), r, paint);
        // Titik pusat motif (isen-isen cecek)
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ModernKawungPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.scale != scale;
}

/// Banner Header Khas Tradisional Indonesia Modern.
/// Menggabungkan sentuhan motif batik halus dengan layout modern dan simple.
class NusantaraHeaderBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? trailing;
  final String? badgeText;
  final Color? accentColor;

  const NusantaraHeaderBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.trailing,
    this.badgeText,
    this.accentColor,
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
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Latar belakang ornamen Batik Kawung tipis dan berkelas
          Positioned.fill(
            child: CustomPaint(
              painter: ModernKawungPainter(
                color: isDark
                    ? primary.withAlpha(16)
                    : primary.withAlpha(14),
                scale: 30.0,
              ),
            ),
          ),

          // Garis aksen vertikal songket khas di kiri
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    NusantaraColors.gold,
                    primary,
                  ],
                ),
              ),
            ),
          ),

          // Konten Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [primary.withAlpha(50), primary.withAlpha(30)]
                            : [primary.withAlpha(35), primary.withAlpha(20)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: primary.withAlpha(100),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(icon, color: primary, size: 22),
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
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: NusantaraColors.gold.withAlpha(isDark ? 40 : 30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: NusantaraColors.gold.withAlpha(120),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badgeText!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? NusantaraColors.goldLight : NusantaraColors.goldDark,
                              letterSpacing: 0.5,
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
          ),
        ],
      ),
    );
  }
}

/// Badge bernuansa ornamen Nusantara
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: baseColor.withAlpha(isDark ? 35 : 25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: baseColor.withAlpha(110),
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
