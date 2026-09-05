import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _autoNavigate();
  }

  void _autoNavigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.phoneInput);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(
              minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Top Header: FeedTrack Logo & Tagline
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FeedTrack',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'Good food. Fast track.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fade(duration: 600.ms).slideY(begin: -0.2, end: 0),

                  const Spacer(),

                  // Hero 3D Illustration / Graphic
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: size.width * 0.7,
                          height: size.width * 0.7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primaryLight.withValues(alpha: 0.3),
                                AppColors.primary.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.asset(
                            'assets/images/delivery_rider_hero.jpg',
                            width: size.width * 0.7,
                            height: size.width * 0.7,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: size.width * 0.7,
                              height: size.width * 0.7,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: const Icon(
                                Icons.delivery_dining_rounded,
                                size: 90,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 800.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),

                  const Spacer(),

                  // Content Card at Bottom
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your cravings delivered.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Instant delivery from your favorite restaurants and great deals sent to you daily.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed(AppRoutes.phoneInput);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shadowColor: AppColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get Started',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 800.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
