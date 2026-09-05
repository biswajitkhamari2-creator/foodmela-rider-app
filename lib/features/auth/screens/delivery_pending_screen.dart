import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';

class DeliveryPendingScreen extends StatelessWidget {
  const DeliveryPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),

              // Pending Status Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  size: 50,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Your Request is Under Process',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Thank you for signing up as a Delivery Partner! Our onboarding team is currently verifying your documents and background check.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              // Application Ref Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildRow('Application ID', '#FT-RIDER-9821'),
                    const Divider(height: 20),
                    _buildRow('Submitted Role', 'Delivery Partner'),
                    const Divider(height: 20),
                    _buildRow('Verification Status', '⏳ In Progress'),
                  ],
                ),
              ),

              const Spacer(),

              // Return Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.welcome,
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Back to Home',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String title, String val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        Text(val, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
