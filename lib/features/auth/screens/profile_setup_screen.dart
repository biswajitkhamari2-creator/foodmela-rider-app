import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/app_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/features/auth/models/auth_state.dart';

class ProfileSetupScreen extends StatefulWidget {
  final UserAuthData authData;

  const ProfileSetupScreen({super.key, required this.authData});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _errorMessage;

  void _onContinue() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }

    widget.authData.fullName = name;
    widget.authData.emailAddress = email;

    Navigator.of(context).pushNamed(
      AppRoutes.locationSetup,
      arguments: widget.authData,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // Title
              Text(
                "Let's get to know you",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),

              // Full Name Label & Field
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Full name',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _nameController,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Full Name',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (val) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Email Address Label & Field
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Email Address',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Email Address',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: (val) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Add Photo Avatar Picker (Matching Screenshot Center Avatar Picker)
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo upload coming soon!')),
                  );
                },
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade200,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 56,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add Photo',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.error),
                ),
              ],

              const SizedBox(height: 40),

              // Primary Orange Action Button "Continue"
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _onContinue,
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
