import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_track/core/theme/rider_theme.dart';
import 'package:food_track/core/state/rider_theme_state.dart';
import 'package:food_track/core/services/firebase_service.dart';
import 'package:food_track/core/services/maintenance_service.dart';
import 'package:food_track/features/rider/maintenance_screen.dart';
import 'package:food_track/core/services/incoming_order_call.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'package:food_track/features/rider/rider_login_screen.dart';
import 'package:food_track/features/rider/rider_dashboard_screen.dart';
import 'package:food_track/features/calling/callkit_service.dart';
import 'package:food_track/features/calling/incoming_call_router.dart';
import 'package:food_track/core/services/order_ringtone_service.dart';
import 'package:food_track/core/services/native_order_alert.dart';
import 'package:food_track/features/calling/call_service.dart';
import 'package:food_track/features/calling/call_launcher.dart';
import 'package:food_track/features/calling/call_models.dart';
import 'package:food_track/core/services/force_update_service.dart';
import 'package:food_track/features/splash/force_update_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> riderNavigatorKey = GlobalKey<NavigatorState>();

/// Resolve the live navigator, waiting briefly for the first frame.
///
/// A call push can arrive before `runApp`'s tree has mounted (killed → tap, or
/// a foreground FCM delivered while the engine is still warming up). Polling
/// for up to ~2s is the difference between "ring" and "silently nothing" —
/// this is exactly the race that made calls intermittent on killed apps.
Future<NavigatorState?> _awaitNavigator({int tries = 10}) async {
  for (var i = 0; i < tries; i++) {
    final nav = riderNavigatorKey.currentState;
    if (nav != null) return nav;
    await Future.delayed(const Duration(milliseconds: 200));
  }
  return riderNavigatorKey.currentState;
}

/// Voice-call push (terminated/background tap) → full-screen call UI.
/// Rider identity resolves from the saved session; logged-out → no-op.
Future<void> _openVoiceCallFromPush(Map<String, String> data) async {
  try {
    // Wait for the tree before giving up: on a killed-app cold start the push
    // can beat the first frame, and a null navigator used to end the call here.
    final nav = await _awaitNavigator();
    if (nav == null) {
      debugPrint('📞 [RIDER] voice call push dropped — navigator never appeared');
      return;
    }
    final session = await RiderAuthService.instance.getSession();
    var partnerId = session?['partnerId'] ?? '';
    var phone = session?['phone'] ?? '';
    var uid = session?['uid'] ?? '';
    if (partnerId.isEmpty || phone.isEmpty || uid.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      partnerId = partnerId.isNotEmpty ? partnerId : (prefs.getString('rider_partner_id') ?? '');
      phone = phone.isNotEmpty ? phone : (prefs.getString('rider_phone') ?? prefs.getString('phone') ?? '');
      uid = uid.isNotEmpty ? uid : (prefs.getString('rider_uid') ?? '');
    }
    final receiverId = data['receiverId'] ?? '';
    final myId = partnerId.isNotEmpty
        ? partnerId
        : (phone.isNotEmpty
            ? phone
            : (receiverId.isNotEmpty ? receiverId : 'rider'));
    await IncomingCallRouter.openFromPayload(data, myId: myId, myRole: 'rider');
  } catch (e) {
    debugPrint('Voice call push router notice: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // MUST be registered at top-level before any Firebase init — handles FCM when app is killed
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  riderThemeState = RiderThemeState.fallback();

  // ── SHOW THE FIRST FRAME IMMEDIATELY ────────────────────────────────────
  // Never `await` before runApp(). This used to await FirebaseService.initialize()
  // (up to 10s on a slow network) BEFORE the app tree existed — so on a cold
  // start from a killed state the navigator, the CallKit listener and the
  // notification-tap hooks were all still unregistered when the ring arrived,
  // and the call was silently dropped. The tree now exists instantly; every
  // async step below runs against a live navigator.
  runApp(const FoodMelaRiderApp());
  _backgroundInit();
}

/// Post-first-frame init: call routing, permissions, Firebase, saved theme.
/// Never blocks the UI; each step has its own timeout/guard.
Future<void> _backgroundInit() async {
  // ── 1. CALL ROUTING FIRST — before ANY await ────────────────────────────
  // This block used to sit AFTER `await FirebaseService.initialize().timeout(25s)`.
  // On a cold start from a killed state that await can take many seconds, and
  // for its whole duration the navigator key was null, the CallKit event
  // listener was unregistered and the notification-tap hooks were unset. A
  // ring arriving in that window hit `nav == null` inside
  // IncomingCallRouter.openFromPayload and returned silently — no ring, no
  // error. Registering synchronously here closes that gap: nothing below can
  // delay it, and it needs no Firebase (routing reads SharedPreferences and
  // the global navigator key only).
  try {
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
    // Native CallKit events: Accept → full-screen call UI + Agora join;
    // Decline/Timeout → mark rejected so the caller stops ringing.
    CallKitService.listenEvents(
      onAccept: (data) async {
        try {
          final callId = (data['callId'] ?? '').toString();
          final orderId = (data['orderId'] ?? '').toString();
          CallKitService.stopWatchingCall(callId);
          await cancelCallNotifications(callId);
          await CallKitService.endAllCalls();
          final session = await RiderAuthService.instance.getSession();
          final partnerId = session?['partnerId'] ?? '';
          final phone = session?['phone'] ?? '';
          final myId = partnerId.isNotEmpty ? partnerId : (phone.isNotEmpty ? phone : 'rider');
          if (myId.isEmpty) return;
          final callerRole = (data['callerRole'] ?? 'customer').toString().toLowerCase();
          final invite = CallInvite(
            callId: callId,
            orderId: orderId,
            channelName: 'order_$orderId',
            callerId: '',
            callerRole: callerRole,
            receiverId: myId,
            receiverRole: 'rider',
            status: CallStatus.ringing,
            createdAt: DateTime.now(),
          );
          final ctx = riderNavigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            await CallLauncher.answerCall(
              context: ctx,
              invite: invite,
              myId: myId,
              myRole: 'rider',
            );
          }
        } catch (_) {}
      },
      onDecline: (data) {
        final callId = (data['callId'] ?? '').toString();
        final orderId = (data['orderId'] ?? '').toString();
        CallKitService.stopWatchingCall(callId);
        cancelCallNotifications(callId);
        OrderRingtoneService.stopRinging(callId);
        CallKitService.declineFromPush(data);
      },
      onTimeout: (data) async {
        final callId = (data['callId'] ?? '').toString();
        final orderId = (data['orderId'] ?? '').toString();
        debugPrint('⏰ [RIDER MAIN] Call timeout: $callId — marking missed + cleanup');
        CallKitService.stopWatchingCall(callId);
        await cancelCallNotifications(callId);
        OrderRingtoneService.stopRinging(callId);
        await CallService.instance.setStatus(
          orderId: orderId,
          callId: callId,
          status: CallStatus.missed,
        );
        await CallKitService.endCall(callId);
      },
    );
  } catch (e) {
    debugPrint('Call routing setup notice: $e');
  }

  // ── 2. FIREBASE + FCM (first await; call routing is already live) ───────
  try {
    await FirebaseService.initialize().timeout(const Duration(seconds: 25));
  } catch (e) {
    debugPrint('Firebase init notice: $e');
  }
  // Consume a call that arrived while we were cold-starting (notification tap
  // or the background isolate's `pending_voice_call` handoff). Safe now: the
  // tap hooks and navigator key were registered in step 1.
  try {
    await FirebaseService.routeLaunchCallIfAny();
  } catch (e) {
    debugPrint('launch call route notice: $e');
  }

  // ── 3. PERMISSIONS ─────────────────────────────────────────────────────
  try {
    final prefs = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 5));
    if (prefs.getBool('startupPermsAsked') != true) {
      // ONLY the two permissions a call genuinely needs, both the plain
      // Android "Allow / Don't allow" dialog. Nothing else (2026-10-15):
      //   • overlay (draw over other apps) — REMOVED. Only the CallKit
      //     full-screen path needed it, and that path is gone.
      //   • battery-optimization exemption — REMOVED. Opened a system dialog
      //     riders could not reason about; the heads-up ring does not need it.
      //   • full-screen intent — REMOVED. Required a hidden Settings page.
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request().timeout(const Duration(seconds: 10));
      }
      if (!await Permission.microphone.isGranted) {
        await Permission.microphone.request().timeout(const Duration(seconds: 10));
      }
      await prefs.setBool('startupPermsAsked', true);
    }

    // Calls now arrive as a ringing heads-up banner that connects on tap. That
    // path needs no special permission, so the "Manage full-screen intents"
    // Settings page — which riders could not navigate, and whose refusal
    // silently downgraded calls to a silent banner — is gone entirely.
  } catch (_) {}

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

class _MaintenanceGateState extends State<_MaintenanceGate> with WidgetsBindingObserver {
  Stream<({bool enabled, String eta})>? _stream;
  bool _forceUpdate = false;
  bool _isOwnerBypass = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOwnerBypass();
    // Attach AFTER first frame — Firestore handshake happens off-screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        setState(() => _stream = MaintenanceService.instance.watch());
      } catch (_) {}
    });
    // Force-update gate: block the whole app when installed < server min.
    ForceUpdateService.check(app: 'rider').then((d) {
      if (mounted && d == UpdateDecision.force) {
        setState(() => _forceUpdate = true);
      }
    });
  }

  Future<void> _checkOwnerBypass() async {
    final bypass = await MaintenanceService.isOwnerBypassActive();
    if (mounted && bypass != _isOwnerBypass) {
      setState(() => _isOwnerBypass = bypass);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkOwnerBypass();
      FirebaseService.routeLaunchCallIfAny();
    }
  }

  Widget _homeWidget(bool maintenance, String eta) {
    if (_forceUpdate) {
      return const ForceUpdateScreen(app: 'rider');
    }
    if (maintenance && !_isOwnerBypass) {
      return RiderMaintenanceScreen(
        eta: eta,
        onOwnerBypass: () => setState(() => _isOwnerBypass = true),
      );
    }
    return const _AuthGate();
  }

  @override
  Widget build(BuildContext context) {
    final s = _stream;
    return MaterialApp(
      navigatorKey: riderNavigatorKey,
      title: 'FOOD MELA Partner',
      debugShowCheckedModeBanner: false,
      theme: RiderTheme.light(),
      darkTheme: RiderTheme.dark(),
      themeMode: riderThemeState.mode,
      home: s == null
          ? _homeWidget(false, '30 min')
          : StreamBuilder<({bool enabled, String eta})>(
              stream: s,
              initialData: (enabled: false, eta: '30 min'),
              builder: (context, snap) {
                final m = snap.data ?? (enabled: false, eta: '30 min');
                return _homeWidget(m.enabled, m.eta);
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
