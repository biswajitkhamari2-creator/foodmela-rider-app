import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _askPermissionUpfront());
  }

  Future<void> _askPermissionUpfront() async {
    if (!mounted || _askedPermission) return;
    _askedPermission = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('hasAskedRiderAlertPermission') == true ||
          prefs.getBool('permExplainerShown') == true ||
          prefs.getBool('startupPermsAsked') == true) {
        return;
      }
      final allowed = await NativeOrderAlert.canUseFullScreenIntent();
      if (allowed) {
        await prefs.setBool('hasAskedRiderAlertPermission', true);
        await prefs.setBool('permExplainerShown', true);
        return;
      }
    } catch (_) {}

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
                fontSize: 14,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.7)),
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
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasAskedRiderAlertPermission', true);
      await prefs.setBool('permExplainerShown', true);
    } catch (_) {}
    if (go == true && mounted) {
      await NativeOrderAlert.openFullScreenIntentSettings();
    }
  }

  Future<void> _signIn() async {
    final id = _identifierCtrl.text.trim();
    final pw = _passwordCtrl.text;
    if (id.isEmpty) {
      setState(() => _error = 'Please enter email or phone number');
      return;
    }
    if (pw.isEmpty) {
      setState(() => _error = 'Please enter password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rider =
          await RiderAuthService.instance.login(identifier: id, password: pw);
      try {
        await FirebaseService.subscribeToRiderNotifications();
      } catch (_) {}
      if (!mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final alreadyAsked = prefs.getBool('hasAskedRiderAlertPermission') == true ||
            prefs.getBool('permExplainerShown') == true;
        if (!alreadyAsked) {
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
                      fontSize: 14,
                      height: 1.6,
                      color: Colors.white.withValues(alpha: 0.7)),
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
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
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
            await prefs.setBool('hasAskedRiderAlertPermission', true);
            await prefs.setBool('permExplainerShown', true);
            if (go == true) {
              await NativeOrderAlert.openFullScreenIntentSettings();
            }
          }
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              RiderDashboardScreen(riderData: rider),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF8C5E00),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Text('Welcome, ${rider['name'] ?? 'Partner'}!',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ),
      );
    } on RiderAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Login failed. Please try again';
          _loading = false;
        });
      }
    }
    if (mounted && _loading) {
      setState(() => _loading = false);
    }
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        cursorColor: const Color(0xFFD4AF37),
        style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white),
        decoration: InputDecoration(
          prefixIcon:
              Icon(prefixIcon, color: const Color(0xFFD4AF37), size: 22),
          suffixIcon: suffixIcon,
          hintText: hintText,
          hintStyle:
              GoogleFonts.inter(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.45)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _signIn(),
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
            )
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                    duration: const Duration(seconds: 4),
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2))
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
            )
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scale(
                    duration: const Duration(seconds: 5),
                    begin: const Offset(1.2, 1.2),
                    end: const Offset(1, 1))
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
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1))),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2),
                  const SizedBox(height: 40),

                  // 3D Moving Delivery Bike Hero
                  const Center(
                    child: Moving3DBikeStage(),
                  ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('FOOD MELA',
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFD4AF37),
                            letterSpacing: 1.5)),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2).shimmer(
                      delay: 1000.ms,
                      duration: 1500.ms,
                      color: Colors.white.withValues(alpha: 0.5)),
                  Center(
                    child: Text('Delivery Partner',
                        style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Sign in to start delivering',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.5))),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
                  const SizedBox(height: 40),

                  // Form Fields
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email or Phone Number',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9))),
                      const SizedBox(height: 10),
                      _buildGlassField(
                        controller: _identifierCtrl,
                        hintText: 'Enter your email or phone',
                        prefixIcon: Icons.person_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      Text('Password',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9))),
                      const SizedBox(height: 10),
                      _buildGlassField(
                        controller: _passwordCtrl,
                        hintText: 'Enter your password',
                        prefixIcon: Icons.lock_rounded,
                        obscureText: _obscure,
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: Colors.white.withValues(alpha: 0.55),
                              size: 22),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.3))),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 20, color: Color(0xFFEF4444)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(_error!,
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFFEF4444)))),
                              ]),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button — golden
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        disabledBackgroundColor:
                            Colors.white.withValues(alpha: 0.1),
                        elevation: 8,
                        shadowColor:
                            const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('SIGN IN',
                                    style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 1.5)),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 20),
                              ],
                            ),
                    ),
                  )
                      .animate(
                          onPlay: (controller) =>
                              controller.repeat(reverse: true))
                      .shimmer(
                          delay: 2.seconds,
                          duration: 2.seconds,
                          color: Colors.white.withValues(alpha: 0.2)),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Contact Admin to reset your password.',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4)),
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

/// ─────────────────────────────────────────────────────────────────────────────
/// 3D MOVING BIKE HERO STAGE
/// Features 3D perspective tilt, continuous 360° spinning wheels with spokes,
/// suspension floating bounce, FoodMela delivery box, and animated moving road lines.
/// ─────────────────────────────────────────────────────────────────────────────
class Moving3DBikeStage extends StatefulWidget {
  const Moving3DBikeStage({super.key});

  @override
  State<Moving3DBikeStage> createState() => _Moving3DBikeStageState();
}

class _Moving3DBikeStageState extends State<Moving3DBikeStage>
    with TickerProviderStateMixin {
  late final AnimationController _wheelCtrl;
  late final AnimationController _bounceCtrl;
  late final AnimationController _roadCtrl;

  late final Animation<double> _bounceAnim;
  late final Animation<double> _tiltAnim;

  @override
  void initState() {
    super.initState();
    // Continuous wheel spin (~400ms per full 360° rotation)
    _wheelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat();

    // Suspension road bounce / motorcycle vibration
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: -3.5, end: 3.5).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
    _tiltAnim = Tween<double>(begin: -0.025, end: 0.025).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );

    // Continuous high-speed road stripes sliding
    _roadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    )..repeat();
  }

  @override
  void dispose() {
    _wheelCtrl.dispose();
    _bounceCtrl.dispose();
    _roadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 3D Perspective Stage
        SizedBox(
          width: 220,
          height: 125,
          child: AnimatedBuilder(
            animation: Listenable.merge([_bounceCtrl, _wheelCtrl, _roadCtrl]),
            builder: (context, _) {
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0018) // 3D perspective depth
                  ..rotateY(-0.14)          // 3D angle facing right
                  ..rotateX(0.04),          // Slight elevation tilt
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Dynamic Golden Ground Glow / Shadow
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 140 + (_bounceAnim.value * 2),
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Aerodynamic wind drift streaks behind bike
                    Positioned(
                      left: 10,
                      top: 40,
                      child: Opacity(
                        opacity: 0.7,
                        child: Row(
                          children: [
                            Container(width: 18, height: 2, decoration: BoxDecoration(color: const Color(0xFFD4AF37).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 5),
                            Container(width: 12, height: 2, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2))),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 18,
                      top: 56,
                      child: Opacity(
                        opacity: 0.6,
                        child: Container(width: 22, height: 2, decoration: BoxDecoration(color: const Color(0xFFD4AF37).withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2))),
                      ),
                    ),

                    // Motorcycle Body with Suspension Bounce
                    Transform.translate(
                      offset: Offset(0, _bounceAnim.value),
                      child: Transform.rotate(
                        angle: _tiltAnim.value,
                        child: SizedBox(
                          width: 160,
                          height: 95,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // ── REAR WHEEL (Spinning 360°) ──
                              Positioned(
                                left: 6,
                                bottom: 4,
                                child: _buildSpinningWheel(),
                              ),

                              // ── FRONT WHEEL (Spinning 360°) ──
                              Positioned(
                                right: 6,
                                bottom: 4,
                                child: _buildSpinningWheel(),
                              ),

                              // ── MOTORCYCLE CHASSIS / FRAME ──
                              Positioned(
                                left: 24,
                                top: 22,
                                child: Container(
                                  width: 108,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF8C5E00),
                                        Color(0xFFD4AF37),
                                        Color(0xFFFFDF73),
                                        Color(0xFFB8860B),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(24),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(8),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    children: [
                                      // Metallic highlight stripe
                                      Positioned(
                                        top: 6,
                                        left: 10,
                                        right: 14,
                                        height: 3,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── FOOD MELA DELIVERY BOX (Mounted on Rear) ──
                              Positioned(
                                left: 16,
                                top: 4,
                                child: Container(
                                  width: 48,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF1E1710), Color(0xFF2C2215)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lunch_dining_rounded, size: 16, color: Color(0xFFD4AF37)),
                                      const SizedBox(height: 1),
                                      Text(
                                        'FOOD',
                                        style: GoogleFonts.poppins(
                                          fontSize: 6.5,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFD4AF37),
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      Text(
                                        'MELA',
                                        style: GoogleFonts.poppins(
                                          fontSize: 6.5,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ── WINDSHIELD & FRONT FORK ──
                              Positioned(
                                right: 18,
                                top: 10,
                                child: Transform.rotate(
                                  angle: 0.25,
                                  child: Container(
                                    width: 10,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.cyanAccent.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
                                    ),
                                  ),
                                ),
                              ),

                              // ── HEADLIGHT BEAM ──
                              Positioned(
                                right: -4,
                                top: 22,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.amberAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amberAccent.withValues(alpha: 0.9),
                                        blurRadius: 14,
                                        spreadRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 2),

        // Animated High-Speed Road with moving dash marks
        SizedBox(
          width: 180,
          height: 8,
          child: AnimatedBuilder(
            animation: _roadCtrl,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.06),
                  child: Stack(
                    children: [
                      // Moving dashed stripes
                      Positioned(
                        left: -(_roadCtrl.value * 30),
                        right: -30,
                        top: 2,
                        bottom: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(8, (i) {
                            return Container(
                              width: 14,
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpinningWheel() {
    return RotationTransition(
      turns: _wheelCtrl,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1917),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFD4AF37), width: 2.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
              blurRadius: 6,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer tire treads
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
              ),
            ),
            // Spokes (4 crossing lines = 8 spokes)
            Transform.rotate(
              angle: 0,
              child: Container(width: 24, height: 1.5, color: const Color(0xFFD4AF37)),
            ),
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(width: 24, height: 1.5, color: const Color(0xFFD4AF37)),
            ),
            Transform.rotate(
              angle: math.pi / 2,
              child: Container(width: 24, height: 1.5, color: const Color(0xFFD4AF37)),
            ),
            Transform.rotate(
              angle: 3 * math.pi / 4,
              child: Container(width: 24, height: 1.5, color: const Color(0xFFD4AF37)),
            ),
            // Center Gold Axle Hub
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDF73),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

