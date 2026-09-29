import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Provides satisfying sound and tactile haptic feedback for user interactions in Rider App.
class SoundFeedbackService {
  /// Regular tap: subtle crisp click and light haptic impulse.
  static void tap() {
    try {
      HapticFeedback.lightImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Button press or switch toggle: slightly firmer medium impact.
  static void buttonPress() {
    try {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// High-reward event: order accepted, delivered, or claimed.
  static void success() {
    try {
      HapticFeedback.heavyImpact();
      FlutterRingtonePlayer().playNotification();
    } catch (_) {}
  }
}
