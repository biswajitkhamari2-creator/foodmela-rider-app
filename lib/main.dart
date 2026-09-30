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
  // Draw the first frame IMMEDIATELY — heavy init (permissions, Firebase,
  // theme) runs after, so the user never stares at a blank native splash
  // while the network is slow. FCM background handler above is the only
  // thing that must run before runApp.
  riderThemeState = RiderThemeState.fallback();
  runApp(const FoodMelaRiderApp());
  // Heavy init after first frame — failures are silent, features degrade
  // gracefully (dashboard retries auth/stream on its own).
  _backgroundInit();
}

/// Post-first-frame init: permissions, Firebase, call routing, saved theme.
/// Never blocks the UI; each step has its own timeout/guard.
Future<void> _backgroundInit() async {
  try {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      if (prefs.getBool('startupPermsAsked') != true) {
        if (!await Permission.notification.isGranted) {
          await Permission.notification.request().timeout(const Duration(seconds: 10));
        }
        if (!await Permission.microphone.isGranted) {
          await Permission.microphone.request().timeout(const Duration(seconds: 10));
        }
        try {
          await Permission.ignoreBatteryOptimizations
              .request()
              .timeout(const Duration(seconds: 10));
        } catch (_) {}
        await prefs.setBool('startupPermsAsked', true);
      }
    } catch (_) {}
    await FirebaseService.initialize().timeout(const Duration(seconds: 25));
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
  // Apply saved theme once loaded (default light shown until then).
  try {
    final saved = await RiderThemeState.load().timeout(const Duration(seconds: 5));
    riderThemeState.setMode(saved.mode);
  } catch (_) {}
}

class FoodMelaRiderApp extends StatelessWidget {
  const FoodMelaRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: riderThemeState,
      // 🛠️ Maintenance ON (admin panel → Settings) → poori app ki jagah animated screen.
      // Stream attaches lazily AFTER first frame (post-frame callback) so a
      // slow Firestore handshake can never white-screen the app on cold start.
      builder: (context, _) => _MaintenanceGate(),
    );
  }
}

/// Wraps the app in the maintenance stream WITHOUT blocking first paint.
/// Shows the normal app immediately; only swaps to the maintenance screen
/// if/when Firestore actually reports maintenance ON.
class _MaintenanceGate extends StatefulWidget {
  @override
  State<_MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<_MaintenanceGate> {
  Stream<({bool enabled, String eta})>? _stream;

  @override
  void initState() {
    super.initState();
    // Attach AFTER first frame — Firestore handshake happens off-screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        setState(() => _stream = MaintenanceService.instance.watch());
      } catch (_) {}
    });
  }

  Widget _app(bool maintenance, String eta) {
    if (maintenance) {
      return MaterialApp(
        title: 'FOOD MELA Partner',
        debugShowCheckedModeBanner: false,
        theme: RiderTheme.light(),
        darkTheme: RiderTheme.dark(),
        themeMode: riderThemeState.mode,
        home: RiderMaintenanceScreen(eta: eta),
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
  }

  @override
  Widget build(BuildContext context) {
    final s = _stream;
    if (s == null) return _app(false, '30 min'); // first paint: normal app
    return StreamBuilder<({bool enabled, String eta})>(
      stream: s,
      initialData: (enabled: false, eta: '30 min'),
      builder: (context, snap) {
        final m = snap.data ?? (enabled: false, eta: '30 min');
        return _app(m.enabled, m.eta);
      },
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
    // HARD CAP: the whole check must finish in 8s. Whatever hasn't answered
    // by then (slow storage, hanging Firestore, dead network), the user
    // gets the login screen — a stuck check can never hold the app hostage.
    try {
      await _checkSessionInner().timeout(const Duration(seconds: 8));
    } catch (_) {
      if (mounted && _loading) {
        setState(() { _isLoggedIn = false; _loading = false; });
      }
    }
  }

  Future<void> _checkSessionInner() async {
    // Fast path: saved session exists → show dashboard IMMEDIATELY (~1s),
    // then silently refresh the token in the background. The dashboard
    // tolerates a stale token (reconnecting banner) instead of a spinner.
    var session = await RiderAuthService.instance
        .getSession()
        .timeout(const Duration(seconds: 3), onTimeout: () => null);

    if (session != null && session['uid']!.isNotEmpty) {
      if (mounted) {
        setState(() { _isLoggedIn = true; _riderData = session; _loading = false; });
      }
      // Background refresh: fire-and-forget ONLY. The dashboard's own stream
      // handles re-auth/retry on permission-denied. Awaiting it here would make
      // the 8s hard-cap in _checkSession fire on slow networks (Firebase init
      // still running from _backgroundInit), falsely nuking a valid session
      // into the login screen — the exact auto-logout-again-and-again loop.
      RiderAuthService.refreshFirestoreToken()
          .then((ok) => debugPrint(ok ? 'Session refreshed in background' : 'Background refresh failed — dashboard will retry'))
          // ignore: avoid_catches_without_on_clauses
          .catchError((_) => debugPrint('Background refresh threw — dashboard will retry'));
      return;
    }

    // No saved session — one short recovery attempt, then login screen.
    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(const Duration(seconds: 3));
      }
    } catch (_) {}

    session = await RiderAuthService.instance.recoverSessionFromFirebase();
    if (!mounted) return;
    if (session != null && session['uid']!.isNotEmpty) {
      setState(() { _isLoggedIn = true; _riderData = session; _loading = false; });
    } else {
      setState(() { _isLoggedIn = false; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Branded splash: full red + big logo while session resolves.
      return Scaffold(
        backgroundColor: const Color(0xFFD62828),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/app_logo.webp',
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    if (_isLoggedIn) return RiderDashboardScreen(riderData: _riderData);
    return const RiderLoginScreen();
  }
}
