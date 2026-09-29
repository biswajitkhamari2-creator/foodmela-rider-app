import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/sound_feedback_service.dart';

/// Wraps any card or container with interactive 3D perspective tilt and dynamic specular shine.
class Interactive3DCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double maxTiltAngle;
  final BorderRadius? borderRadius;

  const Interactive3DCard({
    super.key,
    required this.child,
    this.onTap,
    this.maxTiltAngle = 0.12, // radians (~7 degrees)
    this.borderRadius,
  });

  @override
  State<Interactive3DCard> createState() => _Interactive3DCardState();
}

class _Interactive3DCardState extends State<Interactive3DCard>
    with SingleTickerProviderStateMixin {
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _isPressed = false;
  late AnimationController _springController;
  late Animation<double> _springAnimX;
  late Animation<double> _springAnimY;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        setState(() {
          _tiltX = _springAnimX.value;
          _tiltY = _springAnimY.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(Offset localPosition, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final normX = ((localPosition.dx / size.width) - 0.5) * 2.0;
    final normY = ((localPosition.dy / size.height) - 0.5) * 2.0;

    setState(() {
      _tiltX = normX.clamp(-1.0, 1.0);
      _tiltY = normY.clamp(-1.0, 1.0);
    });
  }

  void _handlePanEnd() {
    setState(() => _isPressed = false);
    _springAnimX = Tween<double>(begin: _tiltX, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _springAnimY = Tween<double>(begin: _tiltY, end: 0.0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
    );
    _springController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            SoundFeedbackService.tap();
            setState(() => _isPressed = true);
            _handlePanUpdate(details.localPosition, constraints.biggest);
          },
          onTapUp: (_) {
            _handlePanEnd();
            widget.onTap?.call();
          },
          onTapCancel: () => _handlePanEnd(),
          onPanUpdate: (details) =>
              _handlePanUpdate(details.localPosition, constraints.biggest),
          onPanEnd: (_) => _handlePanEnd(),
          onPanCancel: () => _handlePanEnd(),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0014) // 3D perspective field
              ..rotateX(-_tiltY * widget.maxTiltAngle)
              ..rotateY(_tiltX * widget.maxTiltAngle)
              ..scale(_isPressed ? 0.98 : 1.0),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  widget.child,
                  // Dynamic 3D specular shine layer tracking touch angle
                  if (_isPressed || _tiltX.abs() > 0.05 || _tiltY.abs() > 0.05)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: RadialGradient(
                              center: Alignment(_tiltX, _tiltY),
                              radius: 0.85,
                              colors: [
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
