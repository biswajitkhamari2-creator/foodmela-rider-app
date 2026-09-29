import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';
import 'package:food_track/core/theme/rider_theme.dart';
import 'package:food_track/core/state/rider_theme_state.dart';
import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/services/maintenance_service.dart';
import 'package:food_track/features/rider/maintenance_screen.dart';
import 'package:food_track/core/services/incoming_order_call.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'package:food_track/features/rider/rider_login_screen.dart';
import 'package:food_track/features/rider/rider_dashboard_screen.dart';
import 'package:food_track/features/calling/incoming_call_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> riderNavigatorKey = GlobalKey<NavigatorState>();

/// Voice-call push (terminated/background tap) → full-screen call UI.
/// Rider identity resolves from the saved session; logged-out → no-op.
Future<void> _openVoiceCallFromPush(Map<String, String> data) async {
  try {
    final session = await RiderAuthService.instance.getSession();
    final uid = session?['uid'] ?? '';
    if (uid.isEmpty) return;
    final partnerId = session?['partnerId'] ?? '';
    final phone = session?['phone'] ?? '';
    final myId = partnerId.isNotEmpty ? partnerId : (phone.isNotEmpty ? phone : 'rider');
    await IncomingCallRouter.openFromPayload(data, myId: myId, myRole: 'rider');
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // MUST be registered at top-level before any Firebase init — handles FCM when app is killed
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  try {
    // Startup permission bundle: asked ONCE per install (persisted flag),
    // never on every cold start. Only ungranted permissions are requested.
    // Data-clear/reinstall resets the flag (correct: OS revokes grants too).
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
    IncomingOrderCall.navigatorKey = riderNavigatorKey;
    IncomingOrderCall.ensureInitialized();
    // Person-to-person voice-call tap routing (terminated/background/lock).
    IncomingCallRouter.navigatorKey = riderNavigatorKey;
    FirebaseService.onFcmOpen = (data) {
      try {
        if ((data['type'] ?? '') == 'incoming_call') {
          _openVoiceCallFromPush(data);
        }
      } catch (_) {}
    };
    FirebaseService.onVoiceCallTap = (data) {
      try {
        if ((data['type'] ?? '') == 'incoming_call') {
          _openVoiceCallFromPush(data);
        }
      } catch (_) {}
    };
  } catch (e) {
    debugPrint('Init notice: $e');
  }
  riderThemeState = await RiderThemeState.load();
  runApp(const FoodMelaRiderApp());
}

class FoodMelaRiderApp extends StatelessWidget {
  const FoodMelaRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: riderThemeState,
      // 🛠️ Maintenance ON (admin panel → Settings) → poori app ki jagah animated screen.
      builder: (context, _) => StreamBuilder<({bool enabled, String eta})>(
        stream: MaintenanceService.instance.watch(),
        initialData: (enabled: false, eta: '30 min'),
        builder: (context, snap) {
          final m = snap.data ?? (enabled: false, eta: '30 min');
          if (m.enabled) {
            return MaterialApp(
              title: 'FOOD MELA Partner',
              debugShowCheckedModeBanner: false,
              theme: RiderTheme.light(),
              darkTheme: RiderTheme.dark(),
              themeMode: riderThemeState.mode,
              home: RiderMaintenanceScreen(eta: m.eta),
            );
          }
          return MaterialApp(
            navigatorKey: riderNavigatorKey,
            title: 'FOOD MELA Partner',
            debugShowCheckedModeBanner: false,
            theme: RiderTheme.light(),
            darkTheme: RiderTheme.dark(),
            themeMode: riderThemeState.mode,
            home: const _AuthGate(),
          );
        },
      ),
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
    // Step 1: Read the saved session from SharedPreferences FIRST.
    // SharedPreferences survives app kills and cache clears.
    var session = await RiderAuthService.instance.getSession();

    if (session != null && session['uid']!.isNotEmpty) {
      // Step 1a: SYNCHRONOUSLY restore Firebase auth BEFORE showing dashboard.
      // This prevents a race where Firestore queries start before auth is ready.
      // Wait for Firebase to restore the persisted email+password session OR
      // allow refreshFirestoreToken to re-sign in if needed.
      try {
        if (FirebaseAuth.instance.currentUser == null) {
          await FirebaseAuth.instance.authStateChanges()
              .firstWhere((u) => u != null)
              .timeout(const Duration(seconds: 2));
        }
      } catch (_) {}

      // Step 1b: Refresh the Firestore token BEFORE showing dashboard.
      // This ensures orders stream starts with valid auth.
      final refreshOk = await RiderAuthService.refreshFirestoreToken();
      if (refreshOk) {
        if (mounted) setState(() { _isLoggedIn = true; _riderData = session; _loading = false; });
        return;
      }

      // If refresh failed, fall through to Firebase recovery attempt.
    }

    // Step 2: No SharedPreferences session OR refresh failed — try to recover from Firebase Auth
    // (covers first launch after Firebase persists the user but before our
    // SharedPreferences has been written, e.g. login mid-network-drop).
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 4));
      }
    } catch (_) {}

    session = await RiderAuthService.instance.recoverSessionFromFirebase();
    if (session != null && session['uid']!.isNotEmpty) {
      if (mounted) setState(() { _isLoggedIn = true; _riderData = session; _loading = false; });
    } else {
      // Genuinely not logged in — show login screen.
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
