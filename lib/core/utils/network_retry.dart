// ─── Food Mela — Low-network resilience helpers ───────────────────────────────
// Retry with exponential backoff for HTTP + Firestore operations on flaky
// 2G/3G connections. Behaviour-only hardening: no feature, API, or UI change.
// Usage: `await retryNetwork(() => someCall().timeout(...), label: '...')`
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Runs [task] up to [maxAttempts] times with exponential backoff
/// ([firstDelay] → 2x → 4x, capped by [maxDelay]).
/// Retries on timeouts, network errors, and transient failures — but NEVER on
/// [BlocklistedException] types passed via [noRetryOn] (e.g. auth/block errors
/// that will never succeed on retry).
Future<T> retryNetwork<T>(
  Future<T> Function() task, {
  String label = 'network task',
  int maxAttempts = 3,
  Duration firstDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 8),
  bool Function(Object error)? noRetryOn,
}) async {
  var delay = firstDelay;
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await task();
    } catch (e) {
      lastError = e;
      if (noRetryOn != null && noRetryOn(e)) rethrow;
      if (attempt == maxAttempts) break;
      debugPrint('🔁 $label failed (attempt $attempt/$maxAttempts): $e — retrying in ${delay.inSeconds}s');
      await Future.delayed(delay);
      final next = delay.inMilliseconds * 2;
      delay = Duration(milliseconds: next > maxDelay.inMilliseconds ? maxDelay.inMilliseconds : next);
    }
  }
  throw lastError ?? Exception('$label failed');
}

/// True for errors worth retrying on a flaky connection: timeouts, socket /
/// host lookup failures, connection resets, and HTTP 5xx / 429.
/// Auth, permission, 4xx (except 429), and business-logic errors return false.
bool isRetryableError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('permission-denied') ||
      s.contains('unauthenticated') ||
      s.contains('blockedexception') ||
      s.contains('microphone permission denied')) {
    return false;
  }
  return s.contains('timeout') ||
      s.contains('socketexception') ||
      s.contains('host lookup') ||
      s.contains('connection reset') ||
      s.contains('connection refused') ||
      s.contains('network is unreachable') ||
      s.contains('failed host lookup') ||
      s.contains('500') ||
      s.contains('502') ||
      s.contains('503') ||
      s.contains('504') ||
      s.contains('429');
}
