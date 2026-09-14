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
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'call_config.dart';
import 'call_models.dart';
import 'call_service.dart';
import 'active_call_screen.dart';

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

    // 1. Create invite (backend access-checks + logs).
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    late CallInvite invite;
    try {
      _ringingDialog(context, peerLabel, orderId);
      invite = await CallService.instance.startCall(
        orderId: orderId,
        callerId: myId,
        callerRole: myRole,
      );
    } catch (e) {
      navigator.pop(); // close ringing
      messenger.showSnackBar(SnackBar(content: Text(_friendlyError(e))));
      return;
    }

    // 2. Wait for accept / reject / timeout (45s).
    final accepted = await _waitForAnswer(invite);
    navigator.pop(); // close ringing dialog
    if (accepted == null) {
      await CallService.instance.setStatus(
          orderId: orderId, callId: invite.callId, status: CallStatus.missed);
      messenger.showSnackBar(
          SnackBar(content: Text('No answer — $peerLabel did not pick up')));
      return;
    }
    if (!accepted) {
      messenger.showSnackBar(
          SnackBar(content: Text('$peerLabel declined the call')));
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
      messenger.showSnackBar(SnackBar(content: Text(_friendlyError(e))));
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
      messenger.showSnackBar(SnackBar(content: Text(_friendlyError(e))));
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

  static void _ringingDialog(BuildContext context, String peerLabel, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text('Calling $peerLabel…',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
              Text('Order #$orderId',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  static String _friendlyError(Object e) {
    final m = e.toString();
    if (m.contains('Not part of this order')) return 'Only the assigned customer & rider can call on this order';
    if (m.contains('not active')) return 'Calling is available only while the order is active';
    if (m.contains('No rider assigned')) return 'No delivery partner assigned yet — cannot call';
    if (m.contains('Microphone')) return 'Microphone permission is needed for calls';
    return 'Call failed — please try again';
  }
}
