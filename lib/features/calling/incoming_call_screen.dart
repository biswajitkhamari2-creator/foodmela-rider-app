// ─── Food Mela — Incoming call screen ─────────────────────────────────────────
// Shows caller ROLE + order id only — never phone numbers (privacy).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IncomingCallScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_rounded, color: Color(0xFF4ADE80), size: 64),
            ),
            const SizedBox(height: 24),
            Text('Incoming call', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 6),
            Text(callerLabel,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Order #$orderId • Food Mela',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 56),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallButton(
                  icon: Icons.call_end_rounded,
                  color: const Color(0xFFDC2626),
                  label: 'Decline',
                  onTap: onDecline,
                ),
                _CallButton(
                  icon: Icons.call_rounded,
                  color: const Color(0xFF16A34A),
                  label: 'Accept',
                  onTap: onAccept,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _CallButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FloatingActionButton(
          heroTag: label,
          backgroundColor: color,
          onPressed: onTap,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
