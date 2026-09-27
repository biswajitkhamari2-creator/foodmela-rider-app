// ─── Food Mela — CallLauncher: caller-side orchestration ──────────────────────
// Call this from any call button. Shows ringing → joins on accept → handles
// reject/miss/timeout. Usage:
//
//   await CallLauncher.placeCall(
//     context: context,
//     orderId: orderId,
//     myId: FoodMelaState().userPhone,   // customer phone, or rider partnerId
//     myRole: 'customer',                // or 'rider'
//     peerLabel: 'Assigned Rider',       // or 'Customer'
//   );
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_track/core/services/rider_auth_service.dart';
import 'call_config.dart';
import 'call_models.dart';
import 'call_permissions.dart';
import 'call_service.dart';
import 'active_call_screen.dart';
import 'outgoing_call_screen.dart';

/// Readable error snackbar: dark background + white text on every theme.
SnackBar _callSnack(String msg) => SnackBar(
      content: Text(msg, style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white)),
      backgroundColor: const Color(0xFF1C1815),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

class CallLauncher {
  CallLauncher._();

  static Future<void> placeCall({
    required BuildContext context,
    required String orderId,
    required String myId,
    required String myRole,
    required String peerLabel,
  }) async {
    if (!context.mounted) return;
    final earlyMessenger = ScaffoldMessenger.of(context);
    if (!CallConfig.isConfigured) {
      earlyMessenger.showSnackBar(const SnackBar(
          content: Text('Calling not set up yet — add your Agora App ID in call_config.dart')));
      return;
    }
    if (myId.isEmpty) {
      earlyMessenger.showSnackBar(
          const SnackBar(content: Text('Please login first to place a call')));
      return;
    }

    // MANDATORY permissions (mic + notifications + lock-screen ring).
    if (!context.mounted) return;
    final allowed = await CallPermissions.ensureForCall(context);
    if (!allowed) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Call permissions are required — grant them to call')));
      }
      return;
    }

    // 1. Create invite (backend access-checks + logs).
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Self-repair: the stored apiToken is HMAC-signed and can expire or be
    // minted against a rotated secret — a present-but-dead token also 401s.
    // Probe it with a cheap no-op call; re-mint from the live Firebase
    // session when the probe fails, so old sessions don't die with a 401.
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('rider_api_token') ?? '';
      if (stored.isEmpty || !await RiderAuthService.probeCallToken(stored)) {
        final user = FirebaseAuth.instance.currentUser;
        final phone = prefs.getString('rider_phone') ?? '';
        if (user != null && phone.isNotEmpty) {
          final repaired = await RiderAuthService.refreshFirestoreToken();
          if (!repaired) {
            messenger.showSnackBar(_callSnack('Session expired — please logout and login again, then retry the call'));
            return;
          }
        } else {
          messenger.showSnackBar(_callSnack('Session expired — please logout and login again, then retry the call'));
          return;
        }
      }
    } catch (_) {}
    if (!context.mounted) return;
    late CallInvite invite;
    try {
      invite = await CallService.instance.startCall(
        orderId: orderId,
        callerId: myId,
        callerRole: myRole,
      );
    } catch (e) {
      debugPrint('📞 CALL ERROR RAW: $e');
      messenger.showSnackBar(_callSnack(_friendlyError(e)));
      return;
    }

    // 2. Premium ringing screen + answer watch race.
    // OutgoingCallScreen pops with `false` on Cancel; _waitForAnswer resolves
    // on accept/reject/timeout. Whichever finishes first wins.
    if (!context.mounted) return;
    final ringingCompleter = Completer<bool>(); // true=cancelled
    final ringingFuture = navigator.push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => OutgoingCallScreen(
        orderId: orderId,
        peerLabel: peerLabel,
        onCancel: () {
          if (!ringingCompleter.isCompleted) ringingCompleter.complete(true);
          Navigator.of(context).pop(false);
        },
      ),
    ));
    // If the route pops any other way, unblock the race.
    ringingFuture.then((_) {
      if (!ringingCompleter.isCompleted) ringingCompleter.complete(false);
    });
    final answerFuture = _waitForAnswer(invite);
    await Future.any([ringingCompleter.future, answerFuture]);
    final cancelledByCaller =
        ringingCompleter.isCompleted && await ringingCompleter.future;
    if (cancelledByCaller) {
      await CallService.instance.cancelOrTimeout(
          orderId: orderId, callId: invite.callId, isTimeout: false);
      return;
    }
    final accepted = await answerFuture;
    // Close ringing screen (answered / rejected / timeout).
    try {
      navigator.pop();
    } catch (_) {}
    await ringingFuture;
    if (accepted == null) {
      await CallService.instance.cancelOrTimeout(
          orderId: orderId, callId: invite.callId, isTimeout: true);
      messenger.showSnackBar(
          _callSnack('No answer — $peerLabel did not pick up'));
      return;
    }
    if (!accepted) {
      messenger.showSnackBar(
          _callSnack('$peerLabel declined the call'));
      return;
    }

    // 3. Fetch token + join.
    try {
      final token = await CallService.instance.fetchToken(orderId: orderId, userId: myId, role: myRole);
      await navigator.push(MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          orderId: orderId,
          callId: invite.callId,
          peerLabel: peerLabel,
          channelName: token.channelName,
          token: token.token,
          uid: token.uid,
        ),
      ));
    } catch (e) {
      debugPrint('📞 CALL ERROR RAW: $e');
      messenger.showSnackBar(_callSnack(_friendlyError(e)));
    }
  }

  // ── Receiver side: accept an invite ──
  static Future<void> answerCall({
    required BuildContext context,
    required CallInvite invite,
    required String myId,
    required String myRole,
  }) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!CallConfig.isConfigured) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Calling not set up yet — add your Agora App ID in call_config.dart')));
      return;
    }
    try {
      await CallService.instance.setStatus(
          orderId: invite.orderId, callId: invite.callId, status: CallStatus.accepted);
      final token =
          await CallService.instance.fetchToken(orderId: invite.orderId, userId: myId, role: myRole);
      await navigator.push(MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          orderId: invite.orderId,
          callId: invite.callId,
          peerLabel: invite.callerLabel,
          channelName: token.channelName,
          token: token.token,
          uid: token.uid,
          startRecording: true, // accepter triggers S3 recording
        ),
      ));
    } catch (e) {
      debugPrint('📞 CALL ERROR RAW: $e');
      messenger.showSnackBar(_callSnack(_friendlyError(e)));
    }
  }

  static Future<void> declineCall(CallInvite invite) {
    return CallService.instance.setStatus(
        orderId: invite.orderId, callId: invite.callId, status: CallStatus.rejected);
  }

  // ── internals ──
  static Future<bool?> _waitForAnswer(CallInvite invite) {
    final completer = Completer<bool?>();
    late StreamSubscription sub;
    final timer = Timer(const Duration(seconds: 45), () {
      if (!completer.isCompleted) completer.complete(null);
    });
    sub = CallService.instance
        .watchCall(orderId: invite.orderId, callId: invite.callId)
        .listen((u) {
      if (u == null) return;
      if (u.status == CallStatus.accepted && !completer.isCompleted) completer.complete(true);
      if ((u.status == CallStatus.rejected ||
              u.status == CallStatus.ended ||
              u.status == CallStatus.missed) &&
          !completer.isCompleted) {
        completer.complete(false);
      }
    });
    return completer.future.whenComplete(() {
      timer.cancel();
      sub.cancel();
    });
  }

  static String _friendlyError(Object e) {
    final m = e.toString();
    if (m.contains('SessionExpiredException') || m.contains('Login required')) {
      return 'Session expired — please logout and login again, then retry the call';
    }
    if (m.contains('must be your own')) return 'Authentication error — please logout and login again';
    if (m.contains('Not part of this order')) return 'Only the assigned customer & rider can call on this order';
    if (m.contains('not active')) return 'Calling is available only while the order is active';
    if (m.contains('No rider assigned')) return 'No delivery partner assigned yet — cannot call';
    if (m.contains('Microphone')) return 'Microphone permission is needed for calls';
    return 'Call failed — please try again';
  }
}
