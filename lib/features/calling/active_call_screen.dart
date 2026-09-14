// ─── Food Mela — Active in-call screen ────────────────────────────────────────
// Live timer, connection status, mute / speaker / end. Stops backend recording
// on end so the admin gets an mp3 URL on the call log.
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: Colors.white, size: 56),
              ),
              const SizedBox(height: 20),
              Text(widget.peerLabel,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              Text('Order #${widget.orderId}',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: _status == 'Connected'
                      ? const Color(0xFF16A34A).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_status,
                    style: GoogleFonts.inter(
                        color: _status == 'Connected'
                            ? const Color(0xFF4ADE80)
                            : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Text(_fmt,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700)),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _RoundBtn(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    active: _muted,
                    onTap: () async {
                      await CallEngine.instance.toggleMute();
                      setState(() => _muted = !_muted);
                    },
                  ),
                  _RoundBtn(
                    icon: _speaker ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    active: _speaker,
                    onTap: () async {
                      await CallEngine.instance.toggleSpeaker();
                      setState(() => _speaker = !_speaker);
                    },
                  ),
                  FloatingActionButton(
                    heroTag: 'end',
                    backgroundColor: const Color(0xFFDC2626),
                    onPressed: () => _endCall(),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _RoundBtn({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            color: active ? const Color(0xFF111827) : Colors.white, size: 26),
      ),
    );
  }
}
