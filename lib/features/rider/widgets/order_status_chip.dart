// Reusable order-status chip — tinted per status, adapts to light/dark
// via Theme.of(context). Presentation only; no logic changes.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip({super.key, required this.status});

  /// Maps known statuses (case-insensitive) to a base color.
  static Color colorFor(String status) {
    final s = status.trim().toUpperCase();
    if (s == 'NEW' || s == 'NEW ORDER') return const Color(0xFFD4AF37);
    if (s == 'ACCEPTED') return const Color(0xFFD97706);
    if (s == 'PREPARING') return const Color(0xFFF59E0B);
    if (s == 'READY') return const Color(0xFF3B82F6);
    if (s == 'PICKED UP' || s == 'PICKEDUP') return const Color(0xFF8B5CF6);
    if (s == 'OUT FOR DELIVERY' || s == 'OUT FOR DELIVERY'.replaceAll(' ', '')) {
      return const Color(0xFF059669);
    }
    if (s == 'DELIVERED') return const Color(0xFF10B981);
    if (s.contains('CANCEL')) return const Color(0xFFEF4444);
    return const Color(0xFFD4AF37);
  }

  @override
  Widget build(BuildContext context) {
    final base = colorFor(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? base.withValues(alpha: 0.18)
        : base.withValues(alpha: 0.12);
    final fg = isDark ? _lighten(base) : _darken(base);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: base.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Color _lighten(Color c) => Color.fromARGB(
        255,
        (c.r * 255 + (255 - c.r * 255) * 0.35).round(),
        (c.g * 255 + (255 - c.g * 255) * 0.35).round(),
        (c.b * 255 + (255 - c.b * 255) * 0.35).round(),
      );

  Color _darken(Color c) => Color.fromARGB(
        255,
        (c.r * 255 * 0.75).round(),
        (c.g * 255 * 0.75).round(),
        (c.b * 255 * 0.75).round(),
      );
}

/// Staggered entrance wrapper: fade + slide on first build.
class EntranceItem extends StatefulWidget {
  final int index;
  final Widget child;
  const EntranceItem({super.key, required this.index, required this.child});

  @override
  State<EntranceItem> createState() => _EntranceItemState();
}

class _EntranceItemState extends State<EntranceItem> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 * widget.index.clamp(0, 8)), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 350),
      opacity: _visible ? 1 : 0,
      child: Transform.translate(
        offset: Offset(0, _visible ? 0 : 24),
        child: widget.child,
      ),
    );
  }
}

/// Press-feedback wrapper: subtle scale on tap down.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const Pressable({super.key, required this.child, this.onTap});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: widget.child,
      ),
    );
  }
}
