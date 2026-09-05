import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/features/auth/models/auth_state.dart';

class AuthSuccessScreen extends StatelessWidget {
  final UserAuthData authData;

  const AuthSuccessScreen({super.key, required this.authData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Large Animated Green Checkmark Badge (Matching Screen 6)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4CAF50),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 64,
                color: Colors.white,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

            const SizedBox(height: 32),

            // Title
            Text(
              "You're all set!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ).animate().fade(duration: 600.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),

            const SizedBox(height: 10),

            // Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Get ready to explore delicious food!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ).animate().fade(duration: 600.ms, delay: 300.ms),

            if (authData.fullName.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Welcome, ${authData.fullName}! 👋',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ).animate().fade(duration: 600.ms, delay: 400.ms),
            ],

            const Spacer(flex: 3),

            // Primary Orange Action Button "Continue" (Matching Screen 6)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.home,
                      (route) => false,
                    );
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
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
