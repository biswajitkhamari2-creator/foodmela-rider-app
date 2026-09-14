// ─── Food Mela — Premium incoming call screen ─────────────────────────────────
// WhatsApp-style: gradient backdrop, pulsing avatar rings, glass order chip,
// slide-to-answer style accept/decline buttons.
// Shows caller ROLE + order id only — never phone numbers (privacy).
// LOGIC UNCHANGED: same constructor, same onAccept/onDecline callbacks.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IncomingCallScreen extends StatefulWidget {
  final String orderId;
  final String callerLabel; // 'Assigned Rider' | 'Customer'
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallScreen({
    super.key,
    required this.orderId,
    required this.callerLabel,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.callerLabel.toLowerCase().contains('customer');
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B3D24),
              Color(0xFF0A1F16),
              Color(0xFF060D0A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),
              // Brand row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF16A34A), Color(0xFF0B7A3C)],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text('F',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  Text('FoodMela',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                ],
              ),
              const Spacer(),
              // Pulsing avatar
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Container(
                          width: 150 + (((_pulse.value + i / 3) % 1) * 90),
                          height: 150 + (((_pulse.value + i / 3) % 1) * 90),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4ADE80).withValues(
                                alpha: 0.35 * (1 - ((_pulse.value + i / 3) % 1)),
                              ),
                              width: 2,
                            ),
                          ),
                        ),
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isCustomer
                                ? const [Color(0xFF16A34A), Color(0xFF065F31)]
                                : const [Color(0xFFF59E0B), Color(0xFFB45309)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (isCustomer
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFF59E0B))
                                  .withValues(alpha: 0.45),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.callerLabel.isNotEmpty
                              ? widget.callerLabel[0].toUpperCase()
                              : 'F',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Incoming call',
                        style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.callerLabel,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 10),
              // Glass order chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        color: Color(0xFFFFC531), size: 17),
                    const SizedBox(width: 8),
                    Text('Order #${widget.orderId}',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Spacer(),
              // Accept / decline
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PremiumCallButton(
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      gradient: const [
                        Color(0xFFEF4444),
                        Color(0xFFB91C1C)
                      ],
                      glow: const Color(0xFFEF4444),
                      onTap: widget.onDecline,
                    ),
                    _PremiumCallButton(
                      icon: Icons.call_rounded,
                      label: 'Accept',
                      gradient: const [
                        Color(0xFF22C55E),
                        Color(0xFF15803D)
                      ],
                      glow: const Color(0xFF22C55E),
                      onTap: widget.onAccept,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Swipe-free • tap to answer',
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumCallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final Color glow;
  final VoidCallback onTap;
  const _PremiumCallButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.glow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              boxShadow: [
                BoxShadow(
                  color: glow.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
