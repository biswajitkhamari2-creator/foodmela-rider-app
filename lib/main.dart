import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'package:food_track/features/rider/rider_login_screen.dart';
import 'package:food_track/features/rider/rider_dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';

final GlobalKey<NavigatorState> riderNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // MUST be registered at top-level before any Firebase init — handles FCM when app is killed
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  try {
    await Permission.notification.request();
    await FirebaseService.initialize();
  } catch (e) {
    debugPrint('Init notice: $e');
  }
  runApp(const FoodMelaRiderApp());
}

class FoodMelaRiderApp extends StatelessWidget {
  const FoodMelaRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: riderNavigatorKey,
      title: 'FOOD MELA Partner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: FoodMelaaColors.riderPrimary,
          primary: FoodMelaaColors.riderPrimary,
          secondary: FoodMelaaColors.primary,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: FoodMelaaColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: FoodMelaaColors.textDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: FoodMelaaColors.riderPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loading = true;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _riderData;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await RiderAuthService.instance.getSession();
    if (session != null && session['uid']!.isNotEmpty) {
      // Verify Firebase Auth is still valid — re-authenticate silently if needed
      final isValid = await RiderAuthService.instance.isSessionValid();
      if (!isValid) {
        debugPrint('⚠️ [RIDER] Firebase Auth expired, clearing session');
        await RiderAuthService.instance.logout();
        if (mounted) setState(() { _isLoggedIn = false; _loading = false; });
        return;
      }
      if (mounted) setState(() { _isLoggedIn = true; _riderData = session; _loading = false; });
    } else {
      if (mounted) setState(() { _isLoggedIn = false; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: FoodMelaaColors.background,
        body: Center(child: CircularProgressIndicator(color: FoodMelaaColors.riderPrimary)),
      );
    }
    if (_isLoggedIn) return RiderDashboardScreen(riderData: _riderData);
    return const RiderLoginScreen();
  }
}
