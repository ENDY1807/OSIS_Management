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
  bool _isDragging = false;

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

  void _handleTouch(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;

    // Hitung sudut rotasi Hue (0..360 derajat) secara mulus
    double angle = math.atan2(dy, dx) * 180 / math.pi;
    if (angle < 0) angle += 360;

    _updateColor(_hsv.withHue(angle));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentColor = _hsv.toColor();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Interactive Rotatable 360° Color Wheel Ring
        Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final outerRadius = size.width / 2 - 12;
                final innerRadius = outerRadius - 38;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) {
                    setState(() => _isDragging = true);
                    _handleTouch(details.localPosition, size);
                  },
                  onPanStart: (details) {
                    setState(() => _isDragging = true);
                    _handleTouch(details.localPosition, size);
                  },
                  onPanUpdate: (details) {
                    _handleTouch(details.localPosition, size);
                  },
                  onPanEnd: (_) => setState(() => _isDragging = false),
                  onPanCancel: () => setState(() => _isDragging = false),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _handleTouch(e.localPosition, size),
                    onPointerMove: (e) => _handleTouch(e.localPosition, size),
                    child: CustomPaint(
                      size: size,
                      painter: _DonutColorWheelPainter(
                        hsv: _hsv,
                        outerRadius: outerRadius,
                        innerRadius: innerRadius,
                        isDark: isDark,
                        isDragging: _isDragging,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '💡 Putar roda warna untuk memilih corak (Hue: ${_hsv.hue.round()}°)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 16),

        // 2. Saturation Slider
        Row(
          children: [
            Icon(Icons.gradient_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
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
                  value: _hsv.saturation,
                  min: 0.1,
                  max: 1.0,
                  onChanged: (val) => _updateColor(_hsv.withSaturation(val)),
                ),
              ),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '${(_hsv.saturation * 100).round()}% S',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),

        // 3. Brightness / Value Slider
        Row(
          children: [
            Icon(Icons.brightness_6_rounded, size: 20, color: isDark ? Colors.white70 : Colors.black54),
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
            SizedBox(
              width: 46,
              child: Text(
                '${(_hsv.value * 100).round()}% V',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4. Hex Code Input & Preview Swatch
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: currentColor,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white70 : Colors.black26, width: 2.5),
                boxShadow: [
                  BoxShadow(color: currentColor.withAlpha(140), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: _hexController,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Kode Warna HEX',
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  prefixText: '# ',
                  prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: currentColor),
                  suffixIcon: Icon(Icons.colorize_rounded, size: 20, color: currentColor),
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
}

class _DonutColorWheelPainter extends CustomPainter {
  final HSVColor hsv;
  final double outerRadius;
  final double innerRadius;
  final bool isDark;
  final bool isDragging;

  _DonutColorWheelPainter({
    required this.hsv,
    required this.outerRadius,
    required this.innerRadius,
    required this.isDark,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringThickness = outerRadius - innerRadius;
    final midRadius = (outerRadius + innerRadius) / 2;

    // 1. Draw Ring Sweep Gradient
    final sweepGradient = SweepGradient(
      colors: const [
        Color(0xFFFF0000), // 0° Red
        Color(0xFFFFFF00), // 60° Yellow
        Color(0xFF00FF00), // 120° Green
        Color(0xFF00FFFF), // 180° Cyan
        Color(0xFF0000FF), // 240° Blue
        Color(0xFFFF00FF), // 300° Magenta
        Color(0xFFFF0000), // 360° Red
      ],
    );

    final ringPaint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: outerRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness;

    canvas.drawCircle(center, midRadius, ringPaint);

    // 2. Draw Subtle Border for the Ring
    final ringBorderPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, outerRadius, ringBorderPaint);
    canvas.drawCircle(center, innerRadius, ringBorderPaint);

    // 3. Draw Center Preview Circle with dynamic color
    final currentColor = hsv.toColor();
    final centerPaint = Paint()
      ..color = currentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius - 8, centerPaint);

    final centerBorder = Paint()
      ..color = isDark ? Colors.white38 : Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, innerRadius - 8, centerBorder);

    // Center icon/indicator
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${hsv.hue.round()}°',
        style: TextStyle(
          color: (hsv.value > 0.5 && hsv.saturation < 0.7) ? Colors.black87 : Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: const [
            Shadow(color: Colors.black45, blurRadius: 4),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    // 4. Draw Rotational Knob on the Ring
    final rad = hsv.hue * math.pi / 180;
    final knobPos = Offset(center.dx + midRadius * math.cos(rad), center.dy + midRadius * math.sin(rad));

    final knobShadow = Paint()
      ..color = Colors.black54
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isDragging ? 8 : 5);
    canvas.drawCircle(knobPos, isDragging ? 16 : 14, knobShadow);

    final knobOuter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobPos, isDragging ? 14 : 12, knobOuter);

    final knobInner = Paint()
      ..color = currentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobPos, isDragging ? 10 : 8.5, knobInner);
  }

  @override
  bool shouldRepaint(covariant _DonutColorWheelPainter oldDelegate) {
    return oldDelegate.hsv != hsv ||
        oldDelegate.outerRadius != outerRadius ||
        oldDelegate.innerRadius != innerRadius ||
        oldDelegate.isDark != isDark ||
        oldDelegate.isDragging != isDragging;
  }
}
