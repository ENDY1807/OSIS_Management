import 'dart:math' as math;
import 'package:flutter/material.dart';

class ColorWheelPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const ColorWheelPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<ColorWheelPicker> createState() => _ColorWheelPickerState();
}

class _ColorWheelPickerState extends State<ColorWheelPicker> {
  late HSVColor _hsv;
  late TextEditingController _hexController;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(text: _colorToHex(_hsv.toColor()));
  }

  @override
  void didUpdateWidget(ColorWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialColor.toARGB32() != widget.initialColor.toARGB32()) {
      _hsv = HSVColor.fromColor(widget.initialColor);
      _hexController.text = _colorToHex(_hsv.toColor());
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) {
    return '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  void _updateColor(HSVColor newHsv) {
    setState(() {
      _hsv = newHsv;
      _hexController.text = _colorToHex(newHsv.toColor());
    });
    widget.onColorChanged(newHsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentColor = _hsv.toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Interactive Color Wheel (Hue Ring & Saturation)
        SizedBox(
          width: 220,
          height: 220,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final center = Offset(size.width / 2, size.height / 2);
              final radius = size.width / 2 - 14;

              return GestureDetector(
                onPanDown: (details) => _handleTouch(details.localPosition, center, radius),
                onPanUpdate: (details) => _handleTouch(details.localPosition, center, radius),
                child: CustomPaint(
                  size: size,
                  painter: _ColorWheelPainter(hsv: _hsv, radius: radius),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // 2. Brightness / Value Slider
        Row(
          children: [
            const Icon(Icons.brightness_6_rounded, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: currentColor,
                  thumbColor: currentColor,
                  overlayColor: currentColor.withAlpha(40),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: _hsv.value,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (val) => _updateColor(_hsv.withValue(val)),
                ),
              ),
            ),
            Text(
              '${(_hsv.value * 100).round()}%',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. Hex Code Input & Preview Swatch
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white38 : Colors.black26, width: 2),
                boxShadow: [
                  BoxShadow(color: currentColor.withAlpha(120), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _hexController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Kode Warna HEX',
                  prefixText: '# ',
                  prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.colorize_rounded, size: 20),
                    onPressed: () {},
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (val) {
                  String clean = val.trim().replaceAll('#', '');
                  if (clean.length == 6) {
                    try {
                      final parsed = int.parse('0xFF$clean');
                      final col = Color(parsed);
                      final hsv = HSVColor.fromColor(col);
                      setState(() => _hsv = hsv);
                      widget.onColorChanged(col);
                    } catch (_) {}
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleTouch(Offset localPos, Offset center, double radius) {
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Calculate angle for Hue (0..360)
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;

    // Saturation based on distance from center (0..1)
    double sat = (dist / radius).clamp(0.0, 1.0);

    _updateColor(_hsv.withHue(angle).withSaturation(sat));
  }
}

class _ColorWheelPainter extends CustomPainter {
  final HSVColor hsv;
  final double radius;

  _ColorWheelPainter({required this.hsv, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw Wheel Gradient using SweepGradient
    final sweepGradient = SweepGradient(
      colors: const [
        Color(0xFFFF0000), // Red
        Color(0xFFFFFF00), // Yellow
        Color(0xFF00FF00), // Green
        Color(0xFF00FFFF), // Cyan
        Color(0xFF0000FF), // Blue
        Color(0xFFFF00FF), // Magenta
        Color(0xFFFF0000), // Red
      ],
    );

    final wheelPaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, wheelPaint);

    // Radial white-to-transparent overlay for saturation
    final radialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withAlpha((hsv.value * 255).round()),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, radialPaint);

    // Outer border
    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw Thumb / Selector Position
    final rad = hsv.hue * math.pi / 180;
    final dist = hsv.saturation * radius;
    final thumbPos = Offset(center.dx + dist * math.cos(rad), center.dy + dist * math.sin(rad));

    final thumbShadow = Paint()
      ..color = Colors.black45
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(thumbPos, 11, thumbShadow);

    final thumbOuter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbPos, 9, thumbOuter);

    final thumbInner = Paint()
      ..color = hsv.toColor()
      ..style = PaintingStyle.fill;
    canvas.drawCircle(thumbPos, 6.5, thumbInner);
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.hsv != hsv || oldDelegate.radius != radius;
  }
}
