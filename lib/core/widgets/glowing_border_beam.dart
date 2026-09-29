import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// GLOWING BORDER BEAM CARD (Rider Version)
/// A luxury 3D card featuring a continuous glowing light beam
/// that travels around the card boundary perimeter with radiant light trails.
/// ─────────────────────────────────────────────────────────────────────────────
class GlowingBorderBeam extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double borderWidth;
  final double glowWidth;
  final Duration duration;
  final List<Color>? beamColors;
  final Color? backgroundColor;
  final Color? baseBorderColor;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GlowingBorderBeam({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.borderWidth = 2.4,
    this.glowWidth = 7.0,
    this.duration = const Duration(milliseconds: 3200),
    this.beamColors,
    this.backgroundColor,
    this.baseBorderColor,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
  });

  @override
  State<GlowingBorderBeam> createState() => _GlowingBorderBeamState();
}

class _GlowingBorderBeamState extends State<GlowingBorderBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.beamColors ??
        const [
          Colors.transparent,
          Colors.transparent,
          Color(0x00FFB300),
          Color(0x33FFB300),
          Color(0x99FFD54F),
          Color(0xFFFFE082),
          Colors.white,
          Color(0x66FFD54F),
          Colors.transparent,
          Colors.transparent,
        ];

    return Padding(
      padding: widget.margin,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            foregroundPainter: _BorderBeamPainter(
              progress: _ctrl.value,
              radius: widget.borderRadius,
              borderWidth: widget.borderWidth,
              glowWidth: widget.glowWidth,
              beamColors: colors,
              baseBorderColor: widget.baseBorderColor ?? const Color(0xFFFFB300).withValues(alpha: 0.25),
            ),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.transparent,
                borderRadius: widget.borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

class _BorderBeamPainter extends CustomPainter {
  final double progress;
  final BorderRadius radius;
  final double borderWidth;
  final double glowWidth;
  final List<Color> beamColors;
  final Color baseBorderColor;

  _BorderBeamPainter({
    required this.progress,
    required this.radius,
    required this.borderWidth,
    required this.glowWidth,
    required this.beamColors,
    required this.baseBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect.deflate(borderWidth / 2));

    // 1. Base subtle luxury border track
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = baseBorderColor;
    canvas.drawRRect(rrect, basePaint);

    final angle = progress * 2 * math.pi;

    final sweepShader = SweepGradient(
      center: const Alignment(-0.10, 0.0),
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      transform: GradientRotation(angle),
      colors: beamColors,
      stops: const [
        0.0,
        0.75,
        0.80,
        0.88,
        0.94,
        0.98,
        1.0,
        1.0,
        1.0,
        1.0,
      ],
    ).createShader(rect);

    // 2. Outer soft specular glow halo
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0)
      ..shader = sweepShader;
    canvas.drawRRect(rrect, glowPaint);

    // 3. Sharp, radiant laser beam core
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = sweepShader;
    canvas.drawRRect(rrect, corePaint);
  }

  @override
  bool shouldRepaint(covariant _BorderBeamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
