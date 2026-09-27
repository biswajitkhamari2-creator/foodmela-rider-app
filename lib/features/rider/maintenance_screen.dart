import 'package:flutter/material.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';

/// 🛠️ Animated maintenance screen for Rider app — same Firestore flag as
/// website + customer app + admin panel (`app_settings/maintenance`).
class RiderMaintenanceScreen extends StatefulWidget {
  final String eta;
  const RiderMaintenanceScreen({super.key, this.eta = '30 min'});

  @override
  State<RiderMaintenanceScreen> createState() => _RiderMaintenanceScreenState();
}

class _RiderMaintenanceScreenState extends State<RiderMaintenanceScreen>
    with TickerProviderStateMixin {
  late final AnimationController _gear;
  late final AnimationController _float;
  late final AnimationController _bar;

  static const _foods = ['🍕', '🍔', '🍩', '🍜', '🧁', '🌮'];

  @override
  void initState() {
    super.initState();
    _gear = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _bar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() {
    _gear.dispose();
    _float.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEFFDF5), Color(0xFFD1FAE5)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ...List.generate(_foods.length, (i) {
                final pos = [
                  const Offset(0.08, 0.10), const Offset(0.80, 0.12),
                  const Offset(0.10, 0.70), const Offset(0.82, 0.62),
                  const Offset(0.70, 0.82), const Offset(0.16, 0.36),
                ][i];
                return Positioned(
                  left: MediaQuery.of(context).size.width * pos.dx,
                  top: MediaQuery.of(context).size.height * pos.dy,
                  child: AnimatedBuilder(
                    animation: _float,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, -12 * (_float.value + i * 0.13) % 12),
                      child: Opacity(
                        opacity: 0.7,
                        child: Text(_foods[i], style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                );
              }),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 130, height: 110,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 0, top: 0,
                              child: RotationTransition(
                                turns: _gear,
                                child: const Text('⚙️', style: TextStyle(fontSize: 56)),
                              ),
                            ),
                            Positioned(
                              right: 0, bottom: 0,
                              child: RotationTransition(
                                turns: ReverseAnimation(_gear),
                                child: const Text('⚙️', style: TextStyle(fontSize: 44)),
                              ),
                            ),
                            const Positioned(
                              left: 38, top: 22,
                              child: Text('🛵', style: TextStyle(fontSize: 52)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Server Under Maintenance',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1614)),
                      ),
                      const SizedBox(height: 4),
                      const Text('🛵 FOOD MELA Partner',
                          style: TextStyle(fontWeight: FontWeight.w800, color: FoodMelaaColors.riderPrimary)),
                      const SizedBox(height: 8),
                      const Text(
                        'Hum kuch naya bana rahe hain!\nThodi der me wapas aayenge 🙏',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9E8E86), fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 192, height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1E7DD),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: AnimatedBuilder(
                            animation: _bar,
                            builder: (_, __) => Align(
                              alignment: Alignment(-1 + 2.5 * _bar.value, 0),
                              child: Container(
                                width: 77, height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  gradient: const LinearGradient(
                                    colors: [FoodMelaaColors.riderPrimary, Color(0xFFF59E0B)]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: [BoxShadow(color: FoodMelaaColors.riderPrimary.withOpacity(0.2), blurRadius: 8)],
                        ),
                        child: Text('⏳ Expected: ${widget.eta}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: FoodMelaaColors.riderPrimary)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
