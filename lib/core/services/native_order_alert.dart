// ─── Food Mela — native incoming-order alert bridge ─────────────────────────
// Thin MethodChannel wrapper over MainActivity's alert engine (custom looping
// ringtone on the ALARM stream + repeating vibration + wake/lock-screen).
// Native is the PRIMARY alert; OrderRingtoneService (system ringtone) is the
// fallback when native audio can't start (emulator, missing asset, old OS).
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeOrderAlert {
  NativeOrderAlert._();

  static const MethodChannel _channel =
      MethodChannel('com.foodmela.driver/alert');

  /// Start the native alert for [orderId]. Returns true when the custom
  /// ringtone actually started — false means Dart must play the fallback.
  static Future<bool> start(String orderId) async {
    if (orderId.isEmpty) return false;
    try {
      final ok = await _channel
          .invokeMethod<bool>('startOrderAlert', {'orderId': orderId})
          .timeout(const Duration(seconds: 3));
      return ok ?? false;
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] start failed: $e');
      return false;
    }
  }

  /// Stop the alert for one order. The native engine keeps ringing while any
  /// other order is still pending.
  static Future<void> stop(String orderId) async {
    try {
      await _channel
          .invokeMethod('stopOrderAlert', {'orderId': orderId})
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] stop failed: $e');
    }
  }

  /// Silence everything (logout / going offline / app shutdown).
  static Future<void> stopAll() async {
    try {
      await _channel
          .invokeMethod('stopAllAlerts')
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] stopAll failed: $e');
    }
  }

  /// True when the OS will auto-launch the full-screen call UI from
  /// background/killed. On Android 14+ this needs a user-granted special
  /// permission (fresh installs default to DENIED — only dialer apps get it
  /// automatically). Older Android returns true (no gate exists).
  static Future<bool> canUseFullScreenIntent() async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('canUseFullScreenIntent')
          .timeout(const Duration(seconds: 3));
      return ok ?? true;
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] full-screen check failed: $e');
      return true;
    }
  }

  /// Open the exact Settings page where the user grants the full-screen
  /// permission (Android 14+: Manage full-screen intents; older: app
  /// notification settings).
  static Future<void> openFullScreenIntentSettings() async {
    try {
      await _channel
          .invokeMethod('openFullScreenIntentSettings')
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] settings open failed: $e');
    }
  }

  /// True when "Display over other apps" (SYSTEM_ALERT_WINDOW) is granted.
  static Future<bool> canDrawOverlays() async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('canDrawOverlays')
          .timeout(const Duration(seconds: 3));
      return ok ?? true;
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] overlay check failed: $e');
      return true;
    }
  }

  /// Open Android settings for "Display over other apps".
  static Future<void> openOverlaySettings() async {
    try {
      await _channel
          .invokeMethod('openOverlaySettings')
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] overlay settings open failed: $e');
    }
  }

  /// True when Battery Optimization is already ignored.
  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      final ok = await _channel
          .invokeMethod<bool>('isIgnoringBatteryOptimizations')
          .timeout(const Duration(seconds: 3));
      return ok ?? true;
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] battery optimization check failed: $e');
      return true;
    }
  }

  /// Request Battery Optimization Exemption dialog.
  static Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel
          .invokeMethod('requestIgnoreBatteryOptimizations')
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] battery optimization request failed: $e');
    }
  }

  /// Force bring app to foreground over any active app when an order call arrives.
  static Future<void> bringAppToForeground() async {
    try {
      await _channel
          .invokeMethod('bringAppToForeground')
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('⚠️ [NATIVE ALERT] bringAppToForeground failed: $e');
    }
  }
}
