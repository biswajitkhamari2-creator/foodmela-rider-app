import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/services/sound_feedback_service.dart';
import 'package:food_track/core/widgets/glowing_border_beam.dart';

/// Motivational 2.5-second celebration dialog shown immediately when a rider accepts an order.
class RiderAcceptCelebrationDialog extends StatefulWidget {
  final String orderId;
  final String customerName;

  const RiderAcceptCelebrationDialog({
    super.key,
    required this.orderId,
    required this.customerName,
  });

  static Future<void> show(BuildContext context, {required String orderId, required String customerName}) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RiderAcceptCelebrationDialog(
        orderId: orderId,
        customerName: customerName,
      ),
    );
  }

  @override
  State<RiderAcceptCelebrationDialog> createState() => _RiderAcceptCelebrationDialogState();
}

class _RiderAcceptCelebrationDialogState extends State<RiderAcceptCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  Timer? _autoCloseTimer;
  double _progress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    SoundFeedbackService.success();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _animCtrl.forward();

    // 2.5-second progress countdown
    const totalMs = 2500;
    const intervalMs = 50;
    _progressTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progress = (_progress + (intervalMs / totalMs)).clamp(0.0, 1.0);
      });
    });

    _autoCloseTimer = Timer(const Duration(milliseconds: totalMs), () {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _autoCloseTimer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.customerName.trim().isNotEmpty ? widget.customerName.trim() : 'Customer';

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: GlowingBorderBeam(
            borderRadius: BorderRadius.circular(28),
            borderWidth: 2.5,
            glowWidth: 8.0,
            duration: const Duration(milliseconds: 2200),
            beamColors: const [
              Colors.transparent,
              Color(0x33FFD700),
              Color(0xFFFFD700),
              Color(0xFF00FF87),
              Colors.white,
              Color(0xFF00E676),
              Colors.transparent,
            ],
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF161E1A), // Luxury obsidian dark
                    Color(0xFF1E2F26),
                    Color(0xFF12231A),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withValues(alpha: 0.25),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Animated Badge
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFFFFE082),
                          Color(0xFFFFB300),
                          Color(0xFFB8860B),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.rocket_launch_rounded,
                        color: Color(0xFF1B1B1B),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Celebration Headline
                  Text(
                    'THANKS FOR ACCEPTING! 🎉',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFFD54F),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // High-Energy Motivational Message
                  Text(
                    'Go & deliver fast! ⚡\n$displayName will be so happy!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Every on-time delivery earns high ratings & bonus rewards.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFB0BEC5),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Smooth Countdown Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Starting Navigation...',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF81C784),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF81C784)),
                        ],
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
}
