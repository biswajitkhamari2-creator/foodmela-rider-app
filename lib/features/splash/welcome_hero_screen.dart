import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/utils/routes.dart';

class WelcomeHeroScreen extends StatefulWidget {
  const WelcomeHeroScreen({super.key});

  @override
  State<WelcomeHeroScreen> createState() => _WelcomeHeroScreenState();
}

class _WelcomeHeroScreenState extends State<WelcomeHeroScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F5F0),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Exact 1-to-1 Food Mela Welcome Graphic Image Background
            Image.asset(
              'assets/images/food_mela_welcome.jpg',
              fit: BoxFit.cover,
              width: size.width,
              height: size.height,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFFF9F5F0),
                child: const Center(
                  child: Icon(Icons.restaurant_rounded, size: 80, color: Color(0xFFE55A2B)),
                ),
              ),
            ),

            // Interactive Buttons Overlay positioned over the Get Started area
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Get Started Primary CTA Button
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF15A24), Color(0xFFE54A15)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF15A24).withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamed(AppRoutes.phoneInput);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFFF15A24),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Explore Restaurants Secondary Outlined Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed(AppRoutes.home);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.85),
                        side: const BorderSide(color: Color(0xFF8C4A27), width: 1.5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Explore Restaurants',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5C2D16),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Trust Badges Pill Bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildTrustItem(
                          icon: Icons.verified_user_rounded,
                          iconColor: const Color(0xFFF15A24),
                          title: 'Safe & Secure',
                          subtitle: 'Your safety is our priority',
                        ),
                        Container(width: 1, height: 28, color: Colors.grey.shade300),
                        _buildTrustItem(
                          icon: Icons.soup_kitchen_rounded,
                          iconColor: const Color(0xFFE55A2B),
                          title: 'Fast Delivery',
                          subtitle: 'On time, every time',
                        ),
                        Container(width: 1, height: 28, color: Colors.grey.shade300),
                        _buildTrustItem(
                          icon: Icons.stars_rounded,
                          iconColor: const Color(0xFFD4AF37),
                          title: 'Best Quality',
                          subtitle: 'Fresh & delicious food',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 2),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2C1810),
          ),
        ),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 8,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
