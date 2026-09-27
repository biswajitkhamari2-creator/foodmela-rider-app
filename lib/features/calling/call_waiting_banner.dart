// ─── Food Mela — CallWaitingBanner: compact new-call alert (rider) ────────────
// Shown when a NEW incoming call arrives while another call is live.
// Never covers the active call screen — slides in as a top banner with:
//   • Decline — rejects the new call, active call untouched.
//   • End & Accept — ends the active call, then answers the new one.
//
// Usage: CallWaiting.show(context, invite: ..., myId: ..., onActiveEnded: ...).
// `onActiveEnded` fires after the old call fully ends (engine left, recording
// stopped) so the caller can push ActiveCallScreen for the new call.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'call_models.dart';
import 'call_service.dart';

class CallWaiting {
  CallWaiting._();

  /// Shows the banner. Returns when the banner is dismissed (either action).
  /// [onAcceptNew] runs only for End & Accept, AFTER the active call ended.
  static Future<void> show(
    BuildContext context, {
    required CallInvite invite,
    required String myId,
    required Future<void> Function() onActiveEnded,
  }) {
    final completer = Completer<void>();
    late OverlayEntry entry;
    var settled = false;

    void dismiss() {
      if (settled) return;
      settled = true;
      entry.remove();
      if (!completer.isCompleted) completer.complete();
    }

    entry = OverlayEntry(
      builder: (ctx) => _CallWaitingBanner(
        invite: invite,
        onDecline: () async {
          dismiss();
          // Reject the new call — active call untouched.
          try {
            await CallService.instance.setStatus(
              orderId: invite.orderId,
              callId: invite.callId,
              status: CallStatus.rejected,
            );
          } catch (_) {}
        },
        onEndAndAccept: () async {
          dismiss();
          // Mark new call accepted first (stops the caller ringing fast),
          // then end the old call, then hand control back to join the new one.
          try {
            await CallService.instance.setStatus(
              orderId: invite.orderId,
              callId: invite.callId,
              status: CallStatus.accepted,
            );
          } catch (_) {}
          await onActiveEnded();
        },
      ),
    );

    Overlay.of(context).insert(entry);
    // Auto-dismiss after 45s (caller times out anyway) — new call marked missed.
    Timer(const Duration(seconds: 45), () async {
      if (settled) return;
      dismiss();
      try {
        await CallService.instance.setStatus(
          orderId: invite.orderId,
          callId: invite.callId,
          status: CallStatus.missed,
        );
      } catch (_) {}
    });
    return completer.future;
  }
}

class _CallWaitingBanner extends StatefulWidget {
  final CallInvite invite;
  final VoidCallback onDecline;
  final VoidCallback onEndAndAccept;
  const _CallWaitingBanner({
    required this.invite,
    required this.onDecline,
    required this.onEndAndAccept,
  });

  @override
  State<_CallWaitingBanner> createState() => _CallWaitingBannerState();
}

class _CallWaitingBannerState extends State<_CallWaitingBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slide;
  late final Animation<Offset> _offset;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _offset = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offset,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(18),
              color: const Color(0xFF10231A),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.35)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                            ),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.call_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('New call waiting…',
                                  style: GoogleFonts.inter(
                                      color: const Color(0xFF4ADE80),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.4)),
                              const SizedBox(height: 2),
                              Text(widget.invite.callerLabel,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800)),
                              Text('Order #${widget.invite.orderId} • you are on another call',
                                  style: GoogleFonts.inter(
                                      color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () {
                              setState(() => _busy = true);
                              widget.onDecline();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              foregroundColor: const Color(0xFFFCA5A5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text('Decline',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _busy ? null : () {
                              setState(() => _busy = true);
                              widget.onEndAndAccept();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              elevation: 0,
                            ),
                            child: Text('End & Accept',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
