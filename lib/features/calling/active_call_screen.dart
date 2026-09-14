// ─── Food Mela — Premium active in-call screen ────────────────────────────────
// Gradient backdrop, glass peer card, big timer, glowing end button.
// Live timer, connection status, mute / speaker / end. Stops backend recording
// on end so the admin gets an mp3 URL on the call log.
// LOGIC UNCHANGED: same constructor, same engine/recording/watch flow.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'call_engine.dart';
import 'call_models.dart';
import 'call_service.dart';

class ActiveCallScreen extends StatefulWidget {
  final String orderId;
  final String callId;
  final String peerLabel; // who am I talking to ('Assigned Rider' | 'Customer')
  final String channelName;
  final String token;
  final int uid;
  final bool startRecording; // true for the accepter (first joiner)

  const ActiveCallScreen({
    super.key,
    required this.orderId,
    required this.callId,
    required this.peerLabel,
    required this.channelName,
    required this.token,
    required this.uid,
    this.startRecording = false,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  int _seconds = 0;
  bool _muted = false;
  bool _speaker = false;
  bool _ending = false;
  String _status = 'Connecting…';
  Timer? _timer;
  StreamSubscription<CallInvite?>? _watch;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final engine = CallEngine.instance;
    engine.onUserJoined = (_) => mounted ? setState(() => _status = 'Connected') : null;
    engine.onUserOffline = (_) => _endCall(remoteEnded: true);
    try {
      await engine.join(channel: widget.channelName, token: widget.token, uid: widget.uid);
      if (widget.startRecording) {
        await CallService.instance.startRecording(orderId: widget.orderId, callId: widget.callId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed to connect');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call failed: $e')));
      _endCall(remoteEnded: true, failed: true);
      return;
    }
    // Timer starts the moment WE join (call is live) — not gated on the
    // remote-join event, which can arrive late or be missed entirely.
    // Status label still flips to 'Connected' when the peer joins.
    if (mounted) setState(() => _status = 'Connected');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    // Remote hang-up → close screen.
    _watch = CallService.instance
        .watchCall(orderId: widget.orderId, callId: widget.callId)
        .listen((invite) {
      if (invite == null) return;
      if ((invite.status == CallStatus.ended ||
              invite.status == CallStatus.rejected ||
              invite.status == CallStatus.missed) &&
          mounted &&
          !_ending) {
        _endCall(remoteEnded: true);
      }
    });
  }

  String get _fmt =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  Future<void> _endCall({bool remoteEnded = false, bool failed = false}) async {
    if (_ending) return;
    _ending = true;
    _timer?.cancel();
    await _watch?.cancel();
    await CallEngine.instance.leave();
    if (!remoteEnded) {
      await CallService.instance.stopRecording(
        orderId: widget.orderId,
        callId: widget.callId,
        durationSeconds: _seconds,
      );
    }
    if (mounted) Navigator.of(context).pop(_seconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _watch?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = _status == 'Connected';
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0B3D24),
                Color(0xFF0A1F16),
                Color(0xFF060D0A),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text('FoodMela Call',
                    style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2)),
                const Spacer(),
                // Glass peer card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF16A34A),
                              Color(0xFF065F31)
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF16A34A)
                                  .withValues(alpha: 0.45),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.peerLabel.isNotEmpty
                              ? widget.peerLabel[0].toUpperCase()
                              : 'F',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(widget.peerLabel,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long_rounded,
                              color: Color(0xFFFFC531), size: 15),
                          const SizedBox(width: 6),
                          Text('Order #${widget.orderId}',
                              style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: connected
                              ? const Color(0xFF16A34A)
                                  .withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: connected
                                ? const Color(0xFF4ADE80)
                                    .withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: connected
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFFFC531),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_status,
                                style: GoogleFonts.inter(
                                    color: connected
                                        ? const Color(0xFF4ADE80)
                                        : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_fmt,
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
                const Spacer(),
                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 56),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _ControlBtn(
                        icon: _muted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: _muted ? 'Unmute' : 'Mute',
                        active: _muted,
                        onTap: () async {
                          await CallEngine.instance.toggleMute();
                          setState(() => _muted = !_muted);
                        },
                      ),
                      _ControlBtn(
                        icon: _speaker
                            ? Icons.volume_up_rounded
                            : Icons.volume_down_rounded,
                        label: 'Speaker',
                        active: _speaker,
                        onTap: () async {
                          await CallEngine.instance.toggleSpeaker();
                          setState(() => _speaker = !_speaker);
                        },
                      ),
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () => _endCall(),
                            child: Container(
                              width: 74,
                              height: 74,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFEF4444),
                                    Color(0xFFB91C1C)
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call_end_rounded,
                                  color: Colors.white, size: 32),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('End',
                              style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Icon(icon,
                color: active
                    ? const Color(0xFF0A1F16)
                    : Colors.white,
                size: 26),
          ),
        ),
        const SizedBox(height: 10),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
