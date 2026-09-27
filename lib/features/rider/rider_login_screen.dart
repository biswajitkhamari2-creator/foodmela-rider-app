import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/services/native_order_alert.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'package:food_track/features/rider/rider_dashboard_screen.dart';

class RiderLoginScreen extends StatefulWidget {
  const RiderLoginScreen({super.key});

  @override
  State<RiderLoginScreen> createState() => _RiderLoginScreenState();
}

class _RiderLoginScreenState extends State<RiderLoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _askedPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissionUpfront());
  }

  Future<void> _askPermissionUpfront() async {
    if (!mounted || _askedPermission) return;
    _askedPermission = true;
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF141210),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.phone_in_talk_rounded,
                  color: Color(0xFFD4AF37), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
                child: Text('Required Alert Permission',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white))),
          ]),
          content: Text(
            'New orders will ring on your phone like a WhatsApp call — '
            'full screen with ACCEPT / REJECT, even when the app is closed.\n\n'
            'Without this, orders come as silent notifications only.\n\n'
            'Tap ALLOW to switch it ON.',
            style: TextStyle(
                fontSize: 14, height: 1.6, color: Colors.white.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: Text('LATER',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.5))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ALLOW',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
    if (go == true && mounted) {
      await NativeOrderAlert.openFullScreenIntentSettings();
    }
  }

  Future<void> _signIn() async {
    final id = _identifierCtrl.text.trim();
    final pw = _passwordCtrl.text;
    if (id.isEmpty) { setState(() => _error = 'Please enter email or phone number'); return; }
    if (pw.isEmpty) { setState(() => _error = 'Please enter password'); return; }

    setState(() { _loading = true; _error = null; });
    try {
      final rider = await RiderAuthService.instance.login(identifier: id, password: pw);
      try { await FirebaseService.subscribeToRiderNotifications(); } catch (_) {}
      if (!mounted) return;
      try {
        final allowed = await NativeOrderAlert.canUseFullScreenIntent();
        if (mounted && !allowed) {
          final go = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dctx) => AlertDialog(
              backgroundColor: const Color(0xFF141210),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.phone_in_talk_rounded,
                      color: Color(0xFFD4AF37), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                    child: Text('Enable Call Alerts',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))),
              ]),
              content: Text(
                'New orders will ring on your phone like a WhatsApp call — '
                'full screen with ACCEPT / REJECT, even when the app is closed.\n\n'
                'Tap ALLOW on the next screen to switch it ON.',
                style: TextStyle(
                    fontSize: 14, height: 1.6, color: Colors.white.withValues(alpha: 0.7)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx, false),
                  child: Text('SKIP',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.5))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ALLOW',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ],
            ),
          );
          if (go == true) {
            await NativeOrderAlert.openFullScreenIntentSettings();
          }
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => RiderDashboardScreen(riderData: rider),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text('Welcome, ${rider['name'] ?? 'Partner'}!',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      );
    } on RiderAuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Login failed. Please try again'; _loading = false; });
    }
    if (mounted && _loading) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(prefixIcon, color: const Color(0xFF10B981), size: 22),
              suffixIcon: suffixIcon,
              hintText: hintText,
              hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.4)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            onChanged: (_) { if (_error != null) setState(() => _error = null); },
            onSubmitted: (_) => _signIn(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14100A),
      body: Stack(
        children: [
          // Background ambient gold glows
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.16),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(duration: const Duration(seconds: 4), begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
             .blur(),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8C5E00).withValues(alpha: 0.18),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(duration: const Duration(seconds: 5), begin: const Offset(1.2, 1.2), end: const Offset(1, 1))
             .blur(),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                  const SizedBox(height: 40),
                  
                  // Brand Header — golden
                  Center(
                    child: Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF8C5E00), Color(0xFFD4AF37)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8))
                        ],
                      ),
                      child: const Icon(Icons.delivery_dining_rounded, size: 44, color: Colors.white),
                    ),
                  ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack).fadeIn(),
                  const SizedBox(height: 24),
                  Center(
                    child: Text('FOOD MELA',
                        style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFFD4AF37), letterSpacing: 1.5)),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2).shimmer(delay: 1000.ms, duration: 1500.ms, color: Colors.white.withOpacity(0.5)),
                  Center(
                    child: Text('Delivery Partner',
                        style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Sign in to start delivering',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: 0.5))),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                  const SizedBox(height: 40),

                  // Form Fields
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email or Phone Number', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                      const SizedBox(height: 10),
                      _buildGlassField(
                        controller: _identifierCtrl,
                        hintText: 'Enter your email or phone',
                        prefixIcon: Icons.person_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      Text('Password', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                      const SizedBox(height: 10),
                      _buildGlassField(
                        controller: _passwordCtrl,
                        hintText: 'Enter your password',
                        prefixIcon: Icons.lock_rounded,
                        obscureText: _obscure,
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white.withValues(alpha: 0.4), size: 22),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),

                  // Animated Error Banner
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3))),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded, size: 20, color: Color(0xFFEF4444)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)))),
                              ]),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button — golden
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB8860B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor: const Color(0xFFB8860B).withOpacity(0.5),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : Text('SIGN IN', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                   .shimmer(delay: 2.seconds, duration: 2.seconds, color: Colors.white.withOpacity(0.2)),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Contact Admin to reset your password.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
                      textAlign: TextAlign.center,
                    ),
                  ).animate().fadeIn(delay: 700.ms),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
