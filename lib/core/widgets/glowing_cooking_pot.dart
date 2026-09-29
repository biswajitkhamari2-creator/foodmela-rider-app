import 'dart:math' as math;
import 'package:flutter/material.dart';

/// An animated cooking pot with warm radiant glow and live rising steam particles.
/// Used in Rider App when food is being prepared in the kitchen (Stage 1).
class GlowingCookingPot extends StatefulWidget {
  final double size;
  final String? subtitle;

  const GlowingCookingPot({
    super.key,
    this.size = 140.0,
    this.subtitle = 'Kitchen is cooking this fresh order...',
  });

  @override
  State<GlowingCookingPot> createState() => _GlowingCookingPotState();
}

class _GlowingCookingPotState extends State<GlowingCookingPot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_SteamParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Initialize 24 steam particles with staggered lifespans
    for (int i = 0; i < 24; i++) {
      _particles.add(_SteamParticle(
        x: (_random.nextDouble() - 0.5) * 40.0,
        initialY: _random.nextDouble(),
        speed: 0.18 + _random.nextDouble() * 0.22,
        maxRadius: 6.0 + _random.nextDouble() * 8.0,
        driftPhase: _random.nextDouble() * math.pi * 2,
        driftSpeed: 1.5 + _random.nextDouble() * 2.0,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            // Pulsing glow factor (0.8 to 1.15)
            final glowPulse = 0.85 + 0.15 * math.sin(t * math.pi * 2);
            // Gentle simmering pot tilt (-1 to 1 degree)
            final potSimmer = 0.02 * math.sin(t * math.pi * 8);

            return SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Radiant Glowing Flame Aura behind the pot
                  Container(
                    width: widget.size * glowPulse,
                    height: widget.size * glowPulse,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFF6535).withValues(alpha: 0.45),
                          const Color(0xFFFFB95F).withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),

                  // 2. Live Rising Steam / Smoke Layer
                  Positioned(
                    top: 0,
                    bottom: widget.size * 0.35,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      painter: _SteamPainter(
                        progress: t,
                        particles: _particles,
                      ),
                    ),
                  ),

                  // 3. Simmering Pot + Food Icon
                  Positioned(
                    bottom: widget.size * 0.12,
                    child: Transform.rotate(
                      angle: potSimmer,
                      child: Container(
                        width: widget.size * 0.56,
                        height: widget.size * 0.52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFCC4900), Color(0xFFA33900)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(28),
                            top: Radius.circular(10),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA33900).withValues(alpha: 0.5),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pot Rim Highlight
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFB599),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            // Pot Handles
                            Positioned(
                              left: -6,
                              child: Container(
                                width: 8,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7F2B00),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            Positioned(
                              right: -6,
                              child: Container(
                                width: 8,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7F2B00),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            // Cooking Spoon / Flame Emblem
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Color(0xFFFFDBCE),
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.subtitle!,
            style: const TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5A4138),
            ),
          ),
        ],
      ],
    );
  }
}

class _SteamParticle {
  final double x;
  final double initialY;
  final double speed;
  final double maxRadius;
  final double driftPhase;
  final double driftSpeed;

  _SteamParticle({
    required this.x,
    required this.initialY,
    required this.speed,
    required this.maxRadius,
    required this.driftPhase,
    required this.driftSpeed,
  });
}

class _SteamPainter extends CustomPainter {
  final double progress;
  final List<_SteamParticle> particles;

  _SteamPainter({
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final bottomY = size.height;

    for (final p in particles) {
      // Calculate current cycle progress
      final cycleY = (p.initialY + progress * p.speed) % 1.0;
      final currentY = bottomY - cycleY * size.height;

      // Sinusoidal lateral sway
      final driftX = p.x + math.sin(progress * p.driftSpeed * math.pi * 2 + p.driftPhase) * 14.0;
      final currentX = centerX + driftX;

      // Scale radius as smoke rises
      final radius = p.maxRadius * (0.3 + 0.7 * cycleY);

      // Bell-curve opacity: 0 at spawn, peaks at mid-flight, fades to 0 at top
      final opacity = math.sin(cycleY * math.pi) * 0.45;

      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

      canvas.drawCircle(Offset(currentX, currentY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SteamPainter oldDelegate) => true;
}
