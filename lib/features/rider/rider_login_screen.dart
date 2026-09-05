import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/services/firebase_service.dart';
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
