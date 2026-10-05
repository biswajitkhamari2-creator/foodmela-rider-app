// ─── Food Mela — IncomingCallListener mixin ───────────────────────────────────
// Drop onto any screen that lives while a call may arrive (tracking screens,
// dashboards). Shows IncomingCallScreen for invites addressed to myId.
//
//   class _MyState extends State<MyScreen> with IncomingCallListener {
//     @override String get listenOrderId => widget.orderId;
//     @override String get listenMyId => FoodMelaState().userPhone;
//     @override String get listenMyRole => 'customer';
//   }
import 'dart:async';
import 'package:flutter/material.dart';
import 'call_engine.dart';
import 'call_launcher.dart';
import 'call_models.dart';
import 'call_service.dart';
import 'call_session.dart';
import 'call_waiting_banner.dart';
import 'incoming_call_guard.dart';
import 'incoming_call_screen.dart';

mixin IncomingCallListener<T extends StatefulWidget> on State<T> {
  String get listenOrderId;
  String get listenMyId;
  String get listenMyRole;

  StreamSubscription<List<CallInvite>>? _incomingSub;
  final Set<String> _shownFor = {};

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  /// Call when [listenOrderId] changes (e.g. dashboard picks up a new active order).
  void refreshCallListening() {
    _incomingSub?.cancel();
    _incomingSub = null;
    _subscribe();
  }

  void _subscribe() {
    if (listenOrderId.isNotEmpty && listenMyId.isNotEmpty) {
      _incomingSub = CallService.instance
          .incomingCallStream(orderId: listenOrderId, myId: listenMyId)
          .listen(_onInvites);
    }
  }

  void _onInvites(List<CallInvite> invites) {
    if (!mounted) return;
    final fresh = invites.where((i) =>
        i.status == CallStatus.ringing &&
        i.callerRole != listenMyRole &&
        !_shownFor.contains(i.callId) &&
        // Ignore stale echo of the call already live on this device.
        !CallSession.isCurrent(i.orderId, i.callId) &&
        DateTime.now().difference(i.createdAt).inSeconds < 60);
    for (final invite in fresh) {
      _shownFor.add(invite.callId);
      // BUSY: waiting banner (active call untouched). FREE: full screen.
      if (CallSession.inCall) {
        _showWaiting(invite);
      } else {
        _showIncoming(invite);
      }
    }
  }

  /// New call while busy — banner with Decline / End & Accept.
  void _showWaiting(CallInvite invite) {
    CallWaiting.show(
      context,
      invite: invite,
      myId: listenMyId,
      onActiveEnded: () async {
        CallEngine.instance.requestEnd();
        for (var i = 0; i < 50 && CallSession.inCall; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        if (!mounted) return;
        await CallLauncher.answerCall(
          context: context,
          invite: invite,
          myId: listenMyId,
          myRole: listenMyRole,
        );
      },
    );
  }

  void _showIncoming(CallInvite invite) {
    if (!IncomingCallGuard.shouldShow(invite.callId)) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(
        orderId: invite.orderId,
        callerLabel: invite.callerLabel,
        callId: invite.callId,
        onAccept: () {
          Navigator.of(context).pop();
          CallLauncher.answerCall(
            context: context,
            invite: invite,
            myId: listenMyId,
            myRole: listenMyRole,
          );
        },
        onDecline: () {
          Navigator.of(context).pop();
          CallLauncher.declineCall(invite);
        },
      ),
    ));
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    super.dispose();
  }
}
