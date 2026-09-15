// ─── Food Mela — CallService: backend tokens + Firestore signaling ────────────
// Flow:
//  1. Caller: startCall() → backend /request (access check + log) → writes
//     orders/{orderId}/calls/{callId} (status=ringing).
//  2. Receiver: incomingCallStream() fires → IncomingCallScreen.
//  3. Accept: backend /token (membership-checked RTC token) → join Agora.
//     Caller joins on seeing status=accepted. Backend /record/start begins S3 capture.
//  4. Either side ends: status=ended + backend /record/stop {duration} → mp3 URL saved.
//
// LOW-NETWORK HARDENING (behaviour-only, no feature/API change):
// every backend HTTP call retries with exponential backoff (1s→2s→4s) and
// every Firestore signaling write carries a timeout + retry, so calls still
// connect on flaky 2G instead of dying on the first timeout.
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:food_track/core/utils/network_retry.dart';
import 'call_config.dart';
import 'call_models.dart';

class CallToken {
  final String appId;
  final String channelName;
  final String token;
  final int uid;
  final String role;
  const CallToken({
    required this.appId,
    required this.channelName,
    required this.token,
    required this.uid,
    required this.role,
  });
}

class CallService {
  CallService._();
  static final CallService instance = CallService._();

  final _db = FirebaseFirestore.instance;
  String get _base => CallConfig.backendBaseUrl;

  /// POST with retry — short first timeout (fail fast on 2G) + backoff.
  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body, {required String label}) {
    return retryNetwork(
      () async {
        final res = await http
            .post(
              Uri.parse('$_base$path'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        if (res.statusCode != 200 || decoded['success'] != true) {
          final err = Exception((decoded['error'] as String?) ?? '$label failed (${res.statusCode})');
          // 4xx business errors (not found, forbidden) won't fix themselves.
          if (res.statusCode >= 400 && res.statusCode < 500 && res.statusCode != 429) throw err;
          if (!isRetryableError(err)) throw err;
          throw err;
        }
        return decoded;
      },
      label: label,
      noRetryOn: (e) => !isRetryableError(e),
    );
  }

  /// Firestore write with timeout + retry (signaling must not hang forever).
  Future<void> _writeWithRetry(Future<void> Function() write, {required String label}) {
    return retryNetwork(
      () => write().timeout(const Duration(seconds: 8)),
      label: label,
      noRetryOn: (e) => !isRetryableError(e),
    );
  }

  // ── Backend: fetch membership-checked RTC token ──
  Future<CallToken> fetchToken({
    required String orderId,
    required String userId,
    String? role,
  }) async {
    final body = await _postJson(
      '/api/calls/$orderId/token',
      {'userId': userId, if (role != null) 'role': role},
      label: 'call token',
    );
    return CallToken(
      appId: (body['appId'] as String?) ?? CallConfig.agoraAppId,
      channelName: body['channelName'] as String,
      token: body['token'] as String,
      uid: (body['uid'] as num).toInt(),
      role: (body['role'] as String?) ?? 'customer',
    );
  }

  // ── Caller: create backend log + Firestore invite ──
  Future<CallInvite> startCall({
    required String orderId,
    required String callerId,
    required String callerRole, // 'customer' | 'rider'
  }) async {
    final body = await _postJson(
      '/api/calls/$orderId/request',
      {'callerId': callerId, 'callerRole': callerRole},
      label: 'call request',
    );
    final log = (body['log'] as Map<String, dynamic>?) ?? {};
    final invite = CallInvite(
      callId: (body['callId'] as String?) ?? '',
      orderId: orderId,
      channelName: (body['channelName'] as String?) ?? 'order_$orderId',
      callerId: callerId,
      callerRole: callerRole,
      receiverId: (log['receiverId'] as String?) ?? '',
      receiverRole: callerRole == 'customer' ? 'rider' : 'customer',
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    );
    await _writeWithRetry(
      () => _db.collection('orders').doc(orderId).collection('calls').doc(invite.callId).set(invite.toMap()),
      label: 'call invite write',
    );
    // Backup path: incoming-call FCM push (covers background/killed app).
    // Primary path stays Firestore signaling. Best-effort, never blocks.
    _fireIncomingCallPush(invite);
    return invite;
  }

  void _fireIncomingCallPush(CallInvite invite) {
    Future(() async {
      try {
        final snap = await retryNetwork(
          () => _db.collection('orders').doc(invite.orderId).get().timeout(
                const Duration(seconds: 6),
              ),
          label: 'call push order read',
          maxAttempts: 2,
          noRetryOn: (e) => !isRetryableError(e),
        );
        final data = snap.data();
        final tokenKey =
            invite.receiverRole == 'rider' ? 'riderFcmToken' : 'customerFcmToken';
        final receiverToken =
            (data?[tokenKey] as String?)?.isNotEmpty == true ? data![tokenKey] as String : null;
        final res = await http
            .post(
              Uri.parse('$_base/api/calls/${invite.orderId}/ring'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'callId': invite.callId,
                'callerRole': invite.callerRole,
                if (receiverToken != null) 'receiverToken': receiverToken,
              }),
            )
            .timeout(const Duration(seconds: 8));
        debugPrint('📞 incoming-call push: ${res.statusCode}');
      } catch (e) {
        debugPrint('incoming-call push notice: $e');
      }
    });
  }

  // ── Receiver: live invites where I am the receiver and still ringing ──
  Stream<List<CallInvite>> incomingCallStream({required String orderId, required String myId}) {
    return _db
        .collection('orders')
        .doc(orderId)
        .collection('calls')
        .where('receiverId', isEqualTo: myId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((s) => s.docs.map((d) => CallInvite.fromDoc(d.id, d.data())).toList());
  }

  // ── Watch one call's status (caller waits for accept/reject/end) ──
  Stream<CallInvite?> watchCall({required String orderId, required String callId}) {
    return _db
        .collection('orders')
        .doc(orderId)
        .collection('calls')
        .doc(callId)
        .snapshots()
        .map((d) => d.exists ? CallInvite.fromDoc(d.id, d.data()!) : null);
  }

  Future<void> setStatus({
    required String orderId,
    required String callId,
    required CallStatus status,
  }) async {
    await _writeWithRetry(
      () => _db.collection('orders').doc(orderId).collection('calls').doc(callId).update({
        'status': callStatusName(status),
      }),
      label: 'call status write',
    );
    // Mirror terminal states to backend log (best-effort).
    if (status == CallStatus.rejected || status == CallStatus.missed || status == CallStatus.failed) {
      try {
        await _postJson(
          '/api/calls/$orderId/status',
          {'callId': callId, 'status': callStatusName(status)},
          label: 'call status mirror',
        );
      } catch (e) {
        debugPrint('call status mirror notice: $e');
      }
    }
  }

  // ── Recording: start on accept, stop on end (S3 mp3 via Agora Cloud Recording) ──
  Future<void> startRecording({required String orderId, required String callId}) async {
    try {
      await _postJson(
        '/api/calls/$orderId/record/start',
        {'callId': callId},
        label: 'recording start',
      );
    } catch (e) {
      debugPrint('recording start notice: $e');
    }
  }

  Future<void> stopRecording({
    required String orderId,
    required String callId,
    required int durationSeconds,
  }) async {
    try {
      await _postJson(
        '/api/calls/$orderId/record/stop',
        {'callId': callId, 'duration': durationSeconds},
        label: 'recording stop',
      );
    } catch (e) {
      debugPrint('recording stop notice: $e');
    }
    try {
      await _writeWithRetry(
        () => _db.collection('orders').doc(orderId).collection('calls').doc(callId).update({
          'status': 'ended',
        }),
        label: 'end-call write',
      );
    } catch (e) {
      debugPrint('firestore end-call notice: $e');
    }
  }
}
