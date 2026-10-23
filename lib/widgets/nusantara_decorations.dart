import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Palet warna Khas Nusantara Tradisional Modern
class NusantaraColors {
  // Soga & Songket Gold / Kuning Kunyit
  static const Color gold = Color(0xFFD97706);
  static const Color goldLight = Color(0xFFFBBF24);
  static const Color goldDark = Color(0xFF92400E);
  static const Color goldWarm = Color(0xFFC27803);

  // Deep Indigo / Navy Batik Tradisional
  static const Color batikNavy = Color(0xFF1E3A8A);
  static const Color batikDeep = Color(0xFF0F172A);
  static const Color batikMidnight = Color(0xFF0A0F1D);

  // Kayu Jati / Terakota Nusantara / Bata Merah
  static const Color terracotta = Color(0xFFB45309);
  static const Color jatiWood = Color(0xFF78350F);
  static const Color bataMerah = Color(0xFF991B1B);

  // Daun Pandan / Hijau Pupus (Simbol kesuburan alam nusantara)
  static const Color pandanGreen = Color(0xFF059669);
  static const Color pandanLight = Color(0xFF10B981);
  static const Color pandanDark = Color(0xFF065F46);

  // Pringgondani Ivory / Krem Tradisional Lembut
  static const Color ivoryLight = Color(0xFFFAF7F2);
  static const Color ivoryCard = Color(0xFFF5EFE6);
}

/// Custom Painter motif Batik Kawung Tradisional Modern.
/// Bentuk geometris empat lingkaran berpusat melambangkan kesucian dan kebijaksanaan.
class ModernKawungPainter extends CustomPainter {
  final Color color;
  final double scale;

  const ModernKawungPainter({
    required this.color,
    this.scale = 28.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final innerStroke = Paint()
      ..color = color.withAlpha(160)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    final dotPaint = Paint()
      ..color = color.withAlpha(210)
      ..style = PaintingStyle.fill;

    final step = scale;
    final r = step * 0.44;
    final rInner = step * 0.22;

    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        // Lingkaran luar kelopak kawung
        canvas.drawCircle(Offset(x, y), r, strokePaint);
        // Lingkaran konsentris dalam (cecek kawung)
        canvas.drawCircle(Offset(x, y), rInner, innerStroke);
        // Isen-isen cecek titik pusat
        canvas.drawCircle(Offset(x, y), 1.4, dotPaint);

        // Belah ketupat di perpotongan kelopak
        final cx = x + step * 0.5;
        final cy = y + step * 0.5;
        final p = Path()
          ..moveTo(cx, cy - 3)
          ..lineTo(cx + 3, cy)
          ..lineTo(cx, cy + 3)
          ..lineTo(cx - 3, cy)
          ..close();
        canvas.drawPath(p, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ModernKawungPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.scale != scale;
}

/// Custom Painter motif Batik Parang Tradisional Modern.
/// Motif diagonal berkesinambungan khas bangsawan Jawa yang melambangkan
/// keteguhan hati, kepemimpinan, dan perjuangan tiada henti.
class BatikParangPainter extends CustomPainter {
  final Color color;
  final double scale;

  const BatikParangPainter({
    required this.color,
    this.scale = 32.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final mlinjonPaint = Paint()
      ..color = color.withAlpha(180)
      ..style = PaintingStyle.fill;

    final spacing = scale;
    final angle = -math.pi / 4; // 45 derajat miring khas Parang

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-size.width, -size.height);

    final diagLen = math.sqrt(size.width * size.width + size.height * size.height) * 2;

    for (double x = -diagLen; x < diagLen; x += spacing) {
      canvas.drawLine(
        Offset(x, -diagLen),
        Offset(x, diagLen),
        linePaint,
      );

      // Ornamen Mlinjon (Canting belah ketupat runcing sepanjang garis)
      for (double y = -diagLen; y < diagLen; y += spacing * 1.4) {
        final mPath = Path()
          ..moveTo(x, y)
          ..lineTo(x + 4, y + 6)
          ..lineTo(x, y + 12)
          ..lineTo(x - 4, y + 6)
          ..close();
        canvas.drawPath(mPath, mlinjonPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BatikParangPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.scale != scale;
}

/// Pita Aksen Batik Nusantara di bagian atas card atau header
class BatikAccentBar extends StatelessWidget {
  final double height;
  final Color? color1;
  final Color? color2;

  const BatikAccentBar({
    super.key,
    this.height = 4,
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

/// Kartu Elegan Bernuansa Tradisional Batik Modern (Sangat Nyaman Digunakan)
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
    this.showBatikPattern = true,
    this.batikOpacity = 0.05,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final bg = backgroundColor ??
        (isDark ? const Color(0xFF131B2A) : Colors.white);
    final border = borderColor ??
        (isDark ? const Color(0xFF223048) : const Color(0xFFE2E8F0));

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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (showBatikPattern)
            Positioned.fill(
              child: Opacity(
                opacity: batikOpacity,
                child: CustomPaint(
                  painter: ModernKawungPainter(
                    color: primary,
                    scale: 30.0,
                  ),
                ),
              ),
            ),
          // Aksen tepi emas tipis di kiri
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3.5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [NusantaraColors.gold, primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
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

/// Banner Header Khas Tradisional Indonesia Modern.
/// Menggabungkan sentuhan motif batik halus dengan layout modern dan simple.
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
    this.showBatik = true,
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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Latar belakang ornamen Batik Kawung tipis dan berkelas
          if (showBatik)
            Positioned.fill(
              child: CustomPaint(
                painter: ModernKawungPainter(
                  color: isDark ? primary.withAlpha(20) : primary.withAlpha(16),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    NusantaraColors.gold,
                    NusantaraColors.terracotta,
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [primary.withAlpha(60), primary.withAlpha(35)]
                            : [primary.withAlpha(40), primary.withAlpha(20)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: NusantaraColors.gold.withAlpha(140),
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
                            color: NusantaraColors.gold.withAlpha(isDark ? 45 : 30),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: NusantaraColors.gold.withAlpha(140),
                              width: 0.9,
                            ),
                          ),
                          child: Text(
                            badgeText!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? NusantaraColors.goldLight : NusantaraColors.goldDark,
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
          ),
        ],
      ),
    );
  }
}

/// Lencana / Badge bernuansa ornamen Nusantara
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

/// Custom Painter motif Batik Mega Mendung Tradisional Modern khas Cirebon.
/// Karakteristik awan bergradasi horisontal dengan lengkungan bertingkat,
/// pilin spiral di pusat inti awan (khas motif Mega Mendung asli pada kain),
/// dan ujung meruncing lancip halus yang melambangkan ketenangan batin,
/// kesabaran, serta kepemimpinan yang mengayomi seluruh lapisan.
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
    // Palet warna autentik Cirebon sesuai foto referensi user (Pink - Lilac - Indigo)
    final Color outerCol = usePhotoPalette ? const Color(0xFF4338CA) : color;
    final Color midCol = usePhotoPalette ? const Color(0xFF818CF8) : color.withValues(alpha: (color.a * 0.7).clamp(0.0, 1.0));
    final Color innerCol = usePhotoPalette ? const Color(0xFFEC4899) : color.withValues(alpha: (color.a * 0.45).clamp(0.0, 1.0));
    final Color spiralCol = usePhotoPalette ? const Color(0xFFF472B6) : color;
    final Color waxCol = usePhotoPalette ? const Color(0xFFFAF5FF) : color.withValues(alpha: (color.a * 0.9).clamp(0.0, 1.0));

    final strokeOuter = Paint()
      ..color = outerCol
      ..style = fillMode ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final strokeMid = Paint()
      ..color = midCol
      ..style = fillMode ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final strokeInner = Paint()
      ..color = innerCol
      ..style = fillMode ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final strokeSpiral = Paint()
      ..color = spiralCol
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final waxOutline = Paint()
      ..color = waxCol
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    final dotPaint = Paint()
      ..color = waxCol
      ..style = PaintingStyle.fill;

    final w = scale;
    final h = scale * 0.48;
    final stepX = w * 0.92;
    final stepY = h * 1.35;

    int row = 0;
    for (double y = -h * 0.5; y < size.height + h; y += stepY) {
      final offsetX = (row % 2 == 1) ? stepX * 0.5 : 0.0;
      for (double x = -w * 0.5 + offsetX; x < size.width + w; x += stepX) {
        _drawMegaMendungCloudWithSpiral(
          canvas,
          x,
          y,
          w,
          h,
          strokeOuter,
          strokeMid,
          strokeInner,
          strokeSpiral,
          waxOutline,
          dotPaint,
        );
      }
      row++;
    }
  }

  void _drawMegaMendungCloudWithSpiral(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Paint outerPaint,
    Paint middlePaint,
    Paint innerPaint,
    Paint spiralPaint,
    Paint waxPaint,
    Paint dotPaint,
  ) {
    // 1. Layer Luar Awan Mega Mendung
    final outerPath = _createCloudPath(x, y, w, h);
    canvas.drawPath(outerPath, outerPaint);
    canvas.drawPath(outerPath, waxPaint);

    // 2. Layer Tengah (Lavender / Blue-violet)
    final midW = w * 0.72;
    final midH = h * 0.72;
    final midX = x + (w - midW) * 0.35;
    final midY = y + (h - midH) * 0.45;
    final midPath = _createCloudPath(midX, midY, midW, midH);
    canvas.drawPath(midPath, middlePaint);

    // 3. Layer Inti (Pink / Magenta pastel)
    final inW = w * 0.44;
    final inH = h * 0.44;
    final inX = x + (w - inW) * 0.38;
    final inY = y + (h - inH) * 0.50;
    final inPath = _createCloudPath(inX, inY, inW, inH);
    canvas.drawPath(inPath, innerPaint);

    // 4. PILIN SPIRAL PUSAT (Khas Mega Mendung Cirebon asli seperti Gambar 1)
    final spiralCenter = Offset(inX + inW * 0.42, inY + inH * 0.46);
    final spiralPath = Path();
    const double turns = 1.35;
    const int points = 32;
    final double maxR = inW * 0.22;

    for (int i = 0; i <= points; i++) {
      final t = i / points;
      final angle = t * turns * 2 * math.pi;
      final r = maxR * (1.0 - t * 0.85);
      final px = spiralCenter.dx + r * math.cos(angle);
      final py = spiralCenter.dy + r * math.sin(angle);
      if (i == 0) {
        spiralPath.moveTo(px, py);
      } else {
        spiralPath.lineTo(px, py);
      }
    }
    canvas.drawPath(spiralPath, spiralPaint);

    // Isen-isen batik cecek (titisan titik putih canting malam)
    canvas.drawCircle(Offset(x + w * 0.94, y + h * 0.50), 1.2, dotPaint);
    canvas.drawCircle(Offset(x + w * 0.48, y + h * 0.20), 1.1, dotPaint);
    canvas.drawCircle(Offset(x + w * 0.22, y + h * 0.75), 1.0, dotPaint);
  }

  Path _createCloudPath(double x, double y, double w, double h) {
    final p = Path();
    // Titik awal dari pangkal kiri
    p.moveTo(x + w * 0.05, y + h * 0.65);

    // Lengkungan dasar mengalir ke kanan bawah meruncing lancip
    p.cubicTo(
      x + w * 0.28, y + h * 0.88,
      x + w * 0.60, y + h * 0.82,
      x + w * 0.94, y + h * 0.52, // Ujung lancip khas Mega Mendung
    );

    // Lekukan tirus balik di ujung horizontal
    p.quadraticBezierTo(
      x + w * 0.99, y + h * 0.42,
      x + w * 0.82, y + h * 0.38,
    );

    // Punggung kubah awan tengah
    p.cubicTo(
      x + w * 0.68, y + h * 0.12,
      x + w * 0.42, y + h * 0.08,
      x + w * 0.30, y + h * 0.28,
    );

    // Kubah awan pangkal kiri
    p.cubicTo(
      x + w * 0.18, y + h * 0.16,
      x + w * 0.02, y + h * 0.32,
      x + w * 0.05, y + h * 0.65,
    );

    p.close();
    return p;
  }

  @override
  bool shouldRepaint(covariant ModernMegaMendungPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.scale != scale ||
      oldDelegate.fillMode != fillMode ||
      oldDelegate.usePhotoPalette != usePhotoPalette;
}

/// Hero Banner Mega Mendung Elegan Berestetika Tinggi (Human-Crafted).
/// Desain modern, bersih, bebas dari tabrakan layout, dengan ornamen Cirebon.
class MegaMendungHeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? badgeText;
  final Widget? trailing;
  final Color? accentColor;
  final double height;

  const MegaMendungHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badgeText,
    this.trailing,
    this.accentColor,
    this.height = 100,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = accentColor ?? NusantaraColors.gold;

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
                  const Color(0xFF0F172A),
                  const Color(0xFF1E3A8A),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withAlpha(120),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 20),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Motif Mega Mendung
          Positioned.fill(
            child: Opacity(
              opacity: 0.14,
              child: CustomPaint(
                painter: ModernMegaMendungPainter(
                  color: accent,
                  scale: 110,
                ),
              ),
            ),
          ),

          // Aksen Garis Emas Puncak
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2.5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withAlpha(50),
                    accent,
                    NusantaraColors.goldLight,
                    accent.withAlpha(50),
                  ],
                ),
              ),
            ),
          ),

          // Konten Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon Avatar Ornamen
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: accent.withAlpha(150),
                      width: 1.2,
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: accent, size: 26),
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
                            color: accent.withAlpha(45),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accent.withAlpha(140), width: 0.8),
                          ),
                          child: Text(
                            badgeText!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: NusantaraColors.goldLight,
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
          ),
        ],
      ),
    );
  }
}

/// Kartu Mega Mendung Modern dengan Struktur Rapi & Spacing Human-Centric
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
    this.showPattern = true,
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
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (showPattern)
            Positioned(
              right: -30,
              top: -15,
              width: 180,
              height: 120,
              child: Opacity(
                opacity: isDark ? 0.05 : 0.04,
                child: CustomPaint(
                  painter: ModernMegaMendungPainter(
                    color: NusantaraColors.gold,
                    scale: 75,
                  ),
                ),
              ),
            ),
          // Aksen Emas Lembut di Kiri
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 3.5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [NusantaraColors.gold, NusantaraColors.batikNavy],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
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

