import 'package:flutter/material.dart';
import 'call_launcher.dart';
import 'call_models.dart';
import 'call_navigator.dart';
import 'call_service.dart';
import 'incoming_call_screen.dart';

/// ─── INCOMING CALL ROUTER ───────────────────────────────────────────────────
/// Opens the full-screen incoming-call UI from a notification tap (or any
/// context-less entry point: terminated app, locked phone). The payload
/// carries orderId + callId; the invite is re-fetched from Firestore so
/// Accept/Decline act on the live doc — never on stale push data.
class IncomingCallRouter {
  IncomingCallRouter._();

  /// Set once from main() to the live app navigator (riderNavigatorKey).
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Payload keys sent by the backend ring push:
  /// { type: 'incoming_call', orderId, callId, callerRole, receiverRole }.
  static Future<void> openFromPayload(
    Map<String, String> data, {
    required String myId,
    required String myRole,
  }) async {
    final orderId = (data['orderId'] ?? '').trim();
    final callId = (data['callId'] ?? '').trim();
    if (orderId.isEmpty || myId.isEmpty) return;
    final nav = navigatorKey?.currentState;
    if (nav == null) return;

    // Re-fetch the live invite — the push may be seconds old.
    CallInvite? invite;
    try {
      final invites = await CallService.instance
          .incomingCallStream(orderId: orderId, myId: myId)
          .first
          .timeout(const Duration(seconds: 8));
      for (final i in invites) {
        if (callId.isNotEmpty && i.callId == callId) {
          invite = i;
          break;
        }
      }
      invite ??= invites.isNotEmpty ? invites.first : null;
    } catch (_) {}

    final callerRole = (data['callerRole'] ?? '').toLowerCase();
    final resolved = invite ??
        CallInvite(
          callId: callId,
          orderId: orderId,
          channelName: 'fm_$orderId',
          callerId: '',
          callerRole: callerRole.isNotEmpty ? callerRole : 'customer',
          receiverId: myId,
          receiverRole: myRole,
          status: CallStatus.ringing,
          createdAt: DateTime.now(),
        );

    if (resolved.status != CallStatus.ringing) return; // ended/missed already
    nav.push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(
        orderId: resolved!.orderId,
        callerLabel: resolved.callerLabel,
        onAccept: () {
          nav.pop();
          final ctx = navigatorKey?.currentContext;
          if (ctx != null) {
            CallLauncher.answerCall(
              context: ctx, invite: resolved!, myId: myId, myRole: myRole);
          }
        },
        onDecline: () {
          nav.pop();
          CallLauncher.declineCall(resolved!);
        },
      ),
    ));
  }
}
