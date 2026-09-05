import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // Avatar & User Details
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Icon(Icons.person_rounded, size: 48, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Alex Johnson',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '+91 98765 43210 • alex@example.com',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Options Menu
              _buildTile(Icons.location_on_rounded, 'Manage Delivery Addresses', () {}),
              _buildTile(Icons.payment_rounded, 'Payment Methods & Cards', () {}),
              _buildTile(Icons.local_offer_rounded, 'Coupons & Promo Offers', () {}),
              _buildTile(Icons.help_outline_rounded, 'Help & Customer Support', () {}),
              _buildTile(Icons.settings_rounded, 'App Settings & Preferences', () {}),

              const SizedBox(height: 20),

              // Logout Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.welcome,
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Logout',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
