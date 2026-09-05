import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/features/auth/screens/role_selection_screen.dart';
import 'package:food_track/features/auth/screens/admin_login_screen.dart';

class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();

  void _onSignIn() {
    Navigator.of(context).pushNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              Text(
                'Welcome Back 👋',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'Sign in with your registered phone number',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),

              // Phone Field Box
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Enter mobile number',
                    hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.primary),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Sign In Button
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFF4A1A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6B35).withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _onSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Don't have an account? Sign Up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RoleSelectionScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign Up',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Dedicated Admin Portal Link
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AdminLoginScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.security_rounded, color: Color(0xFF0EA5E9), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Are you an Admin? Login as Admin',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
