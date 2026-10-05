import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/theme/rider_theme.dart';
import 'package:food_track/core/state/rider_theme_state.dart';
import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/services/incoming_order_call.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'package:food_track/features/rider/rider_login_screen.dart';
import 'package:food_track/features/rider/rider_dashboard_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Rider entry point (alternative) ────────────────────────────────────────
// Canonical entry is lib/main.dart — this file mirrors it so
// `flutter run -t lib/main_rider.dart` also works. Keep them in sync.

final GlobalKey<NavigatorState> riderNavigatorKeyAlt =
    GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandlerAlt(
    RemoteMessage message) async {
  return firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandlerAlt);
  try {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('startupPermsAsked') != true) {
        if (!await Permission.notification.isGranted) {
          await Permission.notification.request();
        }
        if (!await Permission.microphone.isGranted) {
          await Permission.microphone.request();
        }
        try {
          await Permission.ignoreBatteryOptimizations.request();
        } catch (_) {}
        await prefs.setBool('startupPermsAsked', true);
      }
    } catch (_) {}
    await FirebaseService.initialize();
    // Full-screen incoming-order call UI (foreground FCM + tap-to-open).
    IncomingOrderCall.navigatorKey = riderNavigatorKeyAlt;
    IncomingOrderCall.ensureInitialized();
  } catch (e) {
    debugPrint('Init notice: $e');
  }
  riderThemeState = await RiderThemeState.load();
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
      themeMode: riderThemeState.mode,
      theme: RiderTheme.light(),
      darkTheme: RiderTheme.dark(),
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
    // 1. Prefs session check — instant paint, never throws gate to login if saved
    try {
      final session = await RiderAuthService.instance.getSession();
      debugPrint('[AUTHGATE] cold-start prefs uid=${session?['uid'] ?? 'EMPTY'}');
      if (!mounted) return;
      if (session != null && (session['uid'] ?? '').isNotEmpty) {
        setState(() {
          _isLoggedIn = true;
          _riderData = session;
          _loading = false;
        });
        if (FirebaseAuth.instance.currentUser == null) {
          RiderAuthService.instance.recoverSessionFromFirebase().ignore();
        } else {
          RiderAuthService.refreshFirestoreToken().ignore();
        }
        return;
      }
    } catch (_) {}
    // 2. Silent recovery / auto-reauthentication
    try {
      final recovered = await RiderAuthService.instance
          .recoverSessionFromFirebase()
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
      if (!mounted) return;
      if (recovered != null && (recovered['uid'] ?? '').isNotEmpty) {
        setState(() {
          _isLoggedIn = true;
          _riderData = recovered;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    // 3. Ultimate fallback: check local session once more before login screen
    try {
      final fallbackSession = await RiderAuthService.instance.getSession();
      if (mounted && fallbackSession != null && (fallbackSession['uid'] ?? '').isNotEmpty) {
        setState(() {
          _isLoggedIn = true;
          _riderData = fallbackSession;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
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
        body: Center(
            child:
                CircularProgressIndicator(color: FoodMelaaColors.riderPrimary)),
      );
    }
    if (_isLoggedIn) return RiderDashboardScreen(riderData: _riderData);
    return const RiderLoginScreen();
  }
}
