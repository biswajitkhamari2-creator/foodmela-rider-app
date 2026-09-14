import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
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
    // Upfront permission prompt RIGHT on the login screen — no login needed.
    // Every fresh install asks here itself: new orders ring like a WhatsApp
    // call only when this is ON.
    WidgetsBinding.instance.addPostFrameCallback((_) => _askPermissionUpfront());
  }

  Future<void> _askPermissionUpfront() async {
    if (!mounted || _askedPermission) return;
    _askedPermission = true;
    // UNCONDITIONAL: the native check has proven unreliable (returns true
    // while the OS still blocks full-screen), so ALWAYS ask. Granted users
    // tap LATER once; denied users get the exact Settings page.
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => PopScope(
        canPop: false,
        child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.phone_in_talk_rounded,
                color: Color(0xFFB45309), size: 22),
          ),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Incoming-call alerts REQUIRED',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
        ]),
        content: const Text(
          'New orders will ring on your phone like a WhatsApp call — '
          'full screen with ACCEPT / REJECT, even when the app is closed.\n\n'
          'Without this, orders come as silent notifications only.\n\n'
          'Tap ALLOW on the next screen to switch it ON.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('LATER',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF047857),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ALLOW',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.white)),
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
      // Re-subscribe to FCM topic immediately after login (was unsubscribed on logout)
      try { await FirebaseService.subscribeToRiderNotifications(); } catch (_) {}
      if (!mounted) return;
      // Upfront full-screen permission: ask BEFORE the dashboard, explaining
      // new orders will ring like a WhatsApp call. Skipped if already granted.
      try {
        final allowed = await NativeOrderAlert.canUseFullScreenIntent();
        if (mounted && !allowed) {
          final go = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.phone_in_talk_rounded,
                      color: Color(0xFFB45309), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Incoming-call alerts',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800))),
              ]),
              content: const Text(
                'New orders will ring on your phone like a WhatsApp call — '
                'full screen with ACCEPT / REJECT, even when the app is closed.\n\n'
                'Tap ALLOW on the next screen to switch it ON.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dctx, false),
                  child: const Text('SKIP',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('ALLOW',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: Colors.white)),
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
        MaterialPageRoute(builder: (_) => RiderDashboardScreen(riderData: rider)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: FoodMelaaColors.riderPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text('Welcome, ${rider['name'] ?? 'Partner'}!', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: FoodMelaaColors.background, shape: BoxShape.circle),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: FoodMelaaColors.textDark, size: 20),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              const SizedBox(height: 20),
              // ── Brand ──────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: const Icon(Icons.delivery_dining_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              Center(child: Text('FOOD MELA', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: FoodMelaaColors.riderPrimary, letterSpacing: 1))),
              Center(child: Text('Delivery Partner', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: FoodMelaaColors.textDark))),
              const SizedBox(height: 6),
              Center(child: Text('Sign in to start delivering', style: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textSecondary))),
              const SizedBox(height: 28),

              // ── Email or Phone ─────────────────────────────────────────
              Text('Email or Phone Number', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _error != null ? FoodMelaaColors.error.withValues(alpha: 0.5) : FoodMelaaColors.borderGrey),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: TextField(
                  controller: _identifierCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_rounded, color: FoodMelaaColors.riderPrimary, size: 20),
                    hintText: 'Email or phone number',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textGrey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (_) { if (_error != null) setState(() => _error = null); },
                  onSubmitted: (_) => _signIn(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Password ───────────────────────────────────────────────
              Text('Password', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _error != null ? FoodMelaaColors.error.withValues(alpha: 0.5) : FoodMelaaColors.borderGrey),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: FoodMelaaColors.textDark),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_rounded, color: FoodMelaaColors.riderPrimary, size: 20),
                    hintText: 'Enter password',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: FoodMelaaColors.textGrey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: FoodMelaaColors.textGrey, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onChanged: (_) { if (_error != null) setState(() => _error = null); },
                  onSubmitted: (_) => _signIn(),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: FoodMelaaColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: FoodMelaaColors.error.withValues(alpha: 0.2))),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: FoodMelaaColors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.error))),
                  ]),
                ),
              ],

              const SizedBox(height: 24),

              // ── Sign In ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FoodMelaaColors.riderPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: FoodMelaaColors.riderPrimary.withValues(alpha: 0.5),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('SIGN IN', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5)),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Contact Admin if you forgot your password.',
                  style: GoogleFonts.inter(fontSize: 12, color: FoodMelaaColors.textSecondary),
                  textAlign: TextAlign.center,
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
