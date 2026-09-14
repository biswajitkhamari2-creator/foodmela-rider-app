// ─── Food Mela — Incoming order ringtone ──────────────────────────────────────
// Call-style continuous ringing for unaccepted orders. Keeps ringing until the
// order is accepted / rejected / cancelled / claimed by another rider —
// "koi call aaya hai" experience, not a one-time beep.
//
// PRIMARY path: native alert engine (MainActivity) — loops the bundled
// FoodMela ringtone on the ALARM stream (audible even in silent mode) with
// repeating vibration, wake + show-over-lock-screen. Survives background and
// locked-screen states where Dart audio can't run.
// FALLBACK path: system ringtone via flutter_ringtone_player, used only when
// native audio can't start (emulator, missing asset, channel unavailable).
import 'package:flutter/foundation.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:food_track/core/services/native_order_alert.dart';

class OrderRingtoneService {
  static final Set<String> _ringingOrderIds = {};
  static final Set<String> _nativeActiveIds = {};

  static Set<String> get ringingOrderIds => Set.of(_ringingOrderIds);
  static bool isRinging(String orderId) => _ringingOrderIds.contains(orderId);
  static bool get isRingingAny => _ringingOrderIds.isNotEmpty;

  /// Start looping ringtone for an order. No-op if already ringing for it.
  static Future<void> startRinging(String orderId) async {
    if (orderId.isEmpty) return;
    final alreadyPlaying = _ringingOrderIds.isNotEmpty;
    _ringingOrderIds.add(orderId);
    if (alreadyPlaying) {
      debugPrint('📞 Already ringing — $orderId added to ring set');
      return;
    }
    // Native first: custom FoodMela ringtone + vibration + wake/lock-screen.
    final nativeOk = await NativeOrderAlert.start(orderId);
    if (nativeOk) {
      _nativeActiveIds.add(orderId);
      debugPrint('📞 [NATIVE] FoodMela ringtone ringing for $orderId');
      return;
    }
    // Fallback: system ringtone on the alarm stream.
    try {
      await FlutterRingtonePlayer().playRingtone(
        looping: true,
        asAlarm: true,
        volume: 1.0,
      );
      debugPrint('📞 Ringing started (fallback) for $orderId');
    } catch (e) {
      debugPrint('⚠️ Ringtone start failed: $e');
    }
  }

  /// Stop ringing for one order. The player only goes silent when no other
  /// unaccepted order still needs ringing.
  static Future<void> stopRinging(String orderId) async {
    _ringingOrderIds.remove(orderId);
    _nativeActiveIds.remove(orderId);
    await NativeOrderAlert.stop(orderId);
    if (_ringingOrderIds.isNotEmpty) {
      debugPrint('📞 Still ringing for ${_ringingOrderIds.length} order(s)');
      return;
    }
    await stopAll();
  }

  static Future<void> stopAll() async {
    _ringingOrderIds.clear();
    _nativeActiveIds.clear();
    await NativeOrderAlert.stopAll();
    try {
      await FlutterRingtonePlayer().stop();
      debugPrint('📞 Ringing stopped');
    } catch (e) {
      debugPrint('⚠️ Ringtone stop failed: $e');
    }
  }
}
