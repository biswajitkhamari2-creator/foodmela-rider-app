import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/features/admin/admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _adminIdController =
      TextEditingController(text: 'admin@foodtrack.com');
  final TextEditingController _pinController = TextEditingController(text: '123456');

  void _onAdminLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Admin Badge Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                  border: Border.all(color: const Color(0xFF0EA5E9), width: 2),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 44,
                  color: Color(0xFF0EA5E9),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Admin Security Portal',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Restricted login for platform administrators only',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
              ),

              const SizedBox(height: 36),

              // Admin ID Field
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Admin Email ID',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: TextField(
                  controller: _adminIdController,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.email_rounded, color: Color(0xFF0EA5E9)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Admin PIN Field
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Security Passcode / PIN',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: TextField(
                  controller: _pinController,
                  obscureText: true,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.lock_rounded, color: Color(0xFF0EA5E9)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Login Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _onAdminLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Login as Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
}
