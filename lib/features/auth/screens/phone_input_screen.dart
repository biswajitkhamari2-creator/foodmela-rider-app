import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/features/auth/models/auth_state.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController(text: '9876543210');
  final String _selectedCountryCode = '+91';
  String? _errorMessage;

  void _onSendOtp() {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit mobile number';
      });
      return;
    }

    final authData = UserAuthData(
      countryCode: _selectedCountryCode,
      phoneNumber: phone,
      generatedOtp: '1234',
    );

    Navigator.of(context).pushNamed(
      AppRoutes.otpVerify,
      arguments: authData,
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodMelaaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: FoodMelaaColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Brand Header
              Row(
                children: [
                  const Icon(Icons.delivery_dining_rounded, color: FoodMelaaColors.primary, size: 36),
                  const SizedBox(width: 10),
                  Text(
                    'FOOD MELA',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: FoodMelaaColors.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Text(
                'Sign In / Sign Up 🔑',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: FoodMelaaColors.textDark,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter your 10-digit mobile number to receive your 4-digit Demo OTP.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: FoodMelaaColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // DEMO LOGIN BANNER (1-Click Auto Fill)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DEMO LOGIN DETAILS 💡', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                          Text('Demo Mobile: 9876543210 • Demo OTP: 1234', style: GoogleFonts.inter(fontSize: 11, color: Colors.amber.shade900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Mobile Input Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _errorMessage != null ? Colors.red : Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      '🇮🇳 +91',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Container(width: 1, height: 24, color: Colors.grey.shade300),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Enter Phone Number',
                          border: InputBorder.none,
                          errorText: _errorMessage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // GET OTP Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _onSendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FoodMelaaColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'GET DEMO OTP ➔',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Skip & Browse Button
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.home);
                  },
                  child: Text(
                    'Skip Login & Browse Food ➔',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: FoodMelaaColors.primary),
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
