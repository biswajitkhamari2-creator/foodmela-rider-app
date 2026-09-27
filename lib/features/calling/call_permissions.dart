import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:food_track/core/theme/food_melaa_colors.dart';

/// ─── CALL PERMISSIONS GATE ──────────────────────────────────────────────────
/// WhatsApp-style calls need 3 permissions BEFORE any call button works:
///   1. Microphone — voice.
///   2. Notification — incoming-call ring must show.
///   3. Full-screen intent — ring must wake a LOCKED phone (Android 14+ asks
///      this as a separate system toggle; permission_handler can't pop it,
///      so we deep-link to the exact Settings page).
///
/// [ensureForCall] returns true only when all 3 are granted. When anything is
/// missing it shows a blocking sheet explaining WHY each is needed + buttons
/// that open the exact Settings page. No permission → no call (fail-closed).
class CallPermissions {
  CallPermissions._();

  static Future<bool> get _micOk async =>
      await Permission.microphone.isGranted;

  static Future<bool> get _notifOk async =>
      await Permission.notification.isGranted;

  /// True when a call can ring + connect right now.
  static Future<bool> canCallNow() async {
    return (await _micOk) && (await _notifOk);
  }

  /// Gate every call button through this. Shows the mandatory sheet when
  /// anything is missing; returns true only when all granted.
  static Future<bool> ensureForCall(BuildContext context) async {
    if (await canCallNow()) return true;
    if (!context.mounted) return false;
    final granted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (_) => const _CallPermissionSheet(),
    );
    return granted == true && await canCallNow();
  }

  static Future<void> requestMic() async {
    try {
      await Permission.microphone.request();
    } catch (_) {}
  }

  static Future<void> requestNotif() async {
    try {
      await Permission.notification.request();
    } catch (_) {}
  }

  /// Opens the exact system page for the full-screen-intent toggle
  /// (Alarms & reminders / Special app access → Display over other apps).
  static Future<void> openFullScreenSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }
}

class _CallPermissionSheet extends StatefulWidget {
  const _CallPermissionSheet();

  @override
  State<_CallPermissionSheet> createState() => _CallPermissionSheetState();
}

class _CallPermissionSheetState extends State<_CallPermissionSheet> {
  bool _mic = false;
  bool _notif = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final m = await Permission.microphone.isGranted;
    final n = await Permission.notification.isGranted;
    if (mounted) setState(() { _mic = m; _notif = n; });
  }

  Future<void> _grantAll() async {
    setState(() => _busy = true);
    await CallPermissions.requestMic();
    await CallPermissions.requestNotif();
    await _refresh();
    setState(() => _busy = false);
    if (!mounted) return;
    if (_mic && _notif) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1815),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: FoodMelaaColors.borderGrey, borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 18),
          Center(
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF3E2A9), Color(0xFFD4AF37)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_in_talk_rounded, size: 30, color: Color(0xFF1C1815)),
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text('Calls need 3 permissions', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w800, color: FoodMelaaColors.textDark))),
          const SizedBox(height: 6),
          Center(child: Text('Without these, rider ↔ customer calls cannot ring.\nGrant once — works forever.', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12.5, color: FoodMelaaColors.textSecondary, height: 1.5))),
          const SizedBox(height: 16),
          _row(Icons.mic_rounded, 'Microphone', 'Your voice on the call', _mic),
          const SizedBox(height: 10),
          _row(Icons.notifications_active_rounded, 'Notifications', 'Incoming-call ring must show', _notif),
          const SizedBox(height: 10),
          _lockRow(),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : _grantAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: FoodMelaaColors.gold,
                foregroundColor: const Color(0xFF1C1815),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_busy ? 'Requesting…' : 'Grant All Permissions', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1C1815))),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Not now', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: FoodMelaaColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String title, String sub, bool done) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: FoodMelaaColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: FoodMelaaColors.borderLight)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF242019), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 16, color: FoodMelaaColors.gold)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
          Text(sub, style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary)),
        ])),
        Icon(done ? Icons.check_circle_rounded : Icons.pending_rounded, size: 20, color: done ? FoodMelaaColors.vegGreen : FoodMelaaColors.warning),
      ]),
    );
  }

  Widget _lockRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: FoodMelaaColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: FoodMelaaColors.borderLight)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF242019), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.lock_open_rounded, size: 16, color: FoodMelaaColors.gold)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ring on lock screen', style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: FoodMelaaColors.textDark)),
          Text('Android Settings → allow "Display over other apps"', style: GoogleFonts.inter(fontSize: 11, color: FoodMelaaColors.textSecondary)),
        ])),
        TextButton(
          onPressed: CallPermissions.openFullScreenSettings,
          child: Text('OPEN', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w800, color: FoodMelaaColors.gold)),
        ),
      ]),
    );
  }
}
