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
import 'call_launcher.dart';
import 'call_models.dart';
import 'call_service.dart';
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
        !_shownFor.contains(i.callId) &&
        DateTime.now().difference(i.createdAt).inSeconds < 60);
    for (final invite in fresh) {
      _shownFor.add(invite.callId);
      _showIncoming(invite);
    }
  }

  void _showIncoming(CallInvite invite) {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(
        orderId: invite.orderId,
        callerLabel: invite.callerLabel,
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
