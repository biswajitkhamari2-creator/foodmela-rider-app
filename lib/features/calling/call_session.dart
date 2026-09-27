// ─── Food Mela — CallSession: single live-call tracker (rider) ────────────────
// The Agora engine handles ONE voice call at a time. This singleton records
// which call is currently live so incoming-call paths can show a non-intrusive
// call-waiting banner instead of popping a full-screen UI over the active call.
//
// Lifecycle: ActiveCallScreen sets it on join, clears it on end/dispose.
// CallWaiting reads it to decide banner-vs-fullscreen.
class ActiveCallInfo {
  final String orderId;
  final String callId;
  final DateTime startedAt;
  const ActiveCallInfo({
    required this.orderId,
    required this.callId,
    required this.startedAt,
  });
}

class CallSession {
  CallSession._();
  static ActiveCallInfo? _current;

  static ActiveCallInfo? get current => _current;
  static bool get inCall => _current != null;

  static void start({required String orderId, required String callId}) {
    _current = ActiveCallInfo(
      orderId: orderId,
      callId: callId,
      startedAt: DateTime.now(),
    );
  }

  static void end() => _current = null;

  /// Safety clear (e.g. route disposed) — only clears if it's our call.
  static void endIf(String callId) {
    if (_current?.callId == callId) _current = null;
  }

  /// True when this invite IS the live call (stale echo — ignore, don't banner).
  static bool isCurrent(String orderId, String callId) =>
      _current?.orderId == orderId && _current?.callId == callId;

  static int get elapsedSeconds => _current == null
      ? 0
      : DateTime.now().difference(_current!.startedAt).inSeconds;
}
