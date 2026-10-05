import 'package:flutter/foundation.dart';

/// Global singleton guard to prevent duplicate / stacked incoming call screens.
/// Even if multiple stream listeners (e.g. RiderDashboardScreen, ActiveDeliveryScreen, FCM)
/// receive the same or another invite simultaneously, only ONE incoming call screen
/// is ever displayed at a time, and a given callId is never shown twice.
class IncomingCallGuard {
  IncomingCallGuard._();

  static final Set<String> _handledCallIds = {};
  static bool _isShowing = false;
  static String? _currentCallId;

  /// Returns true ONLY if no other incoming call screen is currently showing
  /// and this specific callId hasn't already been displayed or handled.
  static bool shouldShow(String callId) {
    final cleanId = callId.trim();
    if (cleanId.isEmpty) return false;

    if (_isShowing) {
      debugPrint('🚫 [IncomingCallGuard] Suppressed duplicate incoming screen: another call ($_currentCallId) is already showing');
      return false;
    }

    if (_handledCallIds.contains(cleanId)) {
      debugPrint('🚫 [IncomingCallGuard] Suppressed duplicate incoming screen: call $cleanId already shown');
      return false;
    }

    _handledCallIds.add(cleanId);
    _isShowing = true;
    _currentCallId = cleanId;
    debugPrint('✅ [IncomingCallGuard] Presenting incoming call screen for $cleanId');
    return true;
  }

  /// Called when the incoming call screen is popped, answered, declined, or timed out.
  static void dismissed(String callId) {
    final cleanId = callId.trim();
    debugPrint('ℹ️ [IncomingCallGuard] Dismissed incoming call screen for $cleanId');
    _isShowing = false;
    if (_currentCallId == cleanId) {
      _currentCallId = null;
    }
  }

  static bool get isShowing => _isShowing;

  static void reset() {
    _isShowing = false;
    _currentCallId = null;
    _handledCallIds.clear();
  }
}
