import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/utils/routes.dart';
import 'package:food_track/features/auth/models/auth_state.dart';

class OtpVerifyScreen extends StatefulWidget {
  final UserAuthData authData;

  const OtpVerifyScreen({super.key, required this.authData});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  int _resendTimerSeconds = 30;
  Timer? _timer;
  bool _canResend = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Auto fill Demo OTP "1234"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFillDemoOtp();
    });
  }

  void _autoFillDemoOtp() {
    const demoCode = '1234';
    for (int i = 0; i < 4; i++) {
      _controllers[i].text = demoCode[i];
    }
  }

  void _startResendTimer() {
    setState(() {
      _resendTimerSeconds = 30;
      _canResend = false;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        setState(() => _resendTimerSeconds--);
      } else {
        setState(() => _canResend = true);
        _timer?.cancel();
      }
    });
  }

  void _verifyOtp() {
    final enteredCode = _controllers.map((c) => c.text).join();
    if (enteredCode.length < 4) {
      setState(() => _errorMessage = 'Please enter all 4 digits');
      return;
    }

    if (enteredCode == '1234' || enteredCode == widget.authData.generatedOtp) {
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in successfully as +91 9876543210! 🎉')),
      );
    } else {
      setState(() => _errorMessage = 'Invalid OTP. Use Demo OTP: 1234');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
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

              Text(
                'Verify OTP 🔑',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: FoodMelaaColors.textDark,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Enter 4-digit Demo OTP sent to +91 ${widget.authData.phoneNumber}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: FoodMelaaColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // DEMO OTP BANNER
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade400),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DEMO OTP: 1234 💡', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                          Text('Auto-filled automatically for quick demo login!', style: GoogleFonts.inter(fontSize: 11, color: Colors.green.shade900)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 4-Digit Input Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) {
                  return SizedBox(
                    width: 60,
                    height: 60,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: FoodMelaaColors.primary),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: FoodMelaaColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (val.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // VERIFY & LOGIN Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FoodMelaaColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'VERIFY & LOGIN ➔',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Resend Timer
              Center(
                child: _canResend
                    ? TextButton(
                        onPressed: () {
                          _autoFillDemoOtp();
                          _startResendTimer();
                        },
                        child: Text('Resend Demo OTP', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: FoodMelaaColors.primary)),
                      )
                    : Text(
                        'Resend OTP in $_resendTimerSeconds seconds',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
