import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/services/incoming_order_call.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'package:food_track/features/rider/rider_login_screen.dart';
import 'package:food_track/features/rider/rider_dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';

// ── Rider entry point (alternative) ────────────────────────────────────────
// Canonical entry is lib/main.dart — this file mirrors it so
// `flutter run -t lib/main_rider.dart` also works. Keep them in sync.

final GlobalKey<NavigatorState> riderNavigatorKeyAlt = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandlerAlt(RemoteMessage message) async {
  return firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandlerAlt);
  try {
    await Permission.notification.request();
    await FirebaseService.initialize();
    // Full-screen incoming-order call UI (foreground FCM + tap-to-open).
    IncomingOrderCall.navigatorKey = riderNavigatorKeyAlt;
    IncomingOrderCall.ensureInitialized();
  } catch (e) {
    debugPrint('Init notice: $e');
  }
  runApp(const FoodMelaRiderAppAlt());
}

class FoodMelaRiderAppAlt extends StatelessWidget {
  const FoodMelaRiderAppAlt({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: riderNavigatorKeyAlt,
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
      home: const _AuthGateAlt(),
    );
  }
}

class _AuthGateAlt extends StatefulWidget {
  const _AuthGateAlt();
  @override
  State<_AuthGateAlt> createState() => _AuthGateAltState();
}

class _AuthGateAltState extends State<_AuthGateAlt> {
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
      setState(() {
        _isLoggedIn = true;
        _riderData = session;
        _loading = false;
      });
    } else {
      setState(() {
        _isLoggedIn = false;
        _loading = false;
      });
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
