// ─── Food Mela — Premium outgoing (ringing) call screen ───────────────────────
// WhatsApp-style full-screen ringing UI shown to the CALLER while waiting for
// the peer to accept. Matches IncomingCallScreen's premium look: gradient
// backdrop, pulsing avatar rings, glass order chip, big red cancel button.
// Shows peer ROLE + order id only — never phone numbers (privacy).
// Cancel pops with `false` (caller hangs up before answer).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String orderId;
  final String peerLabel; // 'Assigned Rider' | 'Customer'
  final VoidCallback onCancel;

  const OutgoingCallScreen({
    super.key,
    required this.orderId,
    required this.peerLabel,
    required this.onCancel,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
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
    final isCustomer = widget.peerLabel.toLowerCase().contains('customer');
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
                          widget.peerLabel.isNotEmpty
                              ? widget.peerLabel[0].toUpperCase()
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
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Ringing…',
                        style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.peerLabel,
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
              // Cancel button
              Column(
                children: [
                  GestureDetector(
                    onTap: widget.onCancel,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFEF4444),
                            Color(0xFFB91C1C)
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.5),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end_rounded,
                          color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Cancel',
                      style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }
}
