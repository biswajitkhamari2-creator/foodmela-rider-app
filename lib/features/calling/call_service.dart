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
import 'package:food_track/core/services/rider_auth_service.dart';
import 'call_config.dart';
import 'call_models.dart';

/// Backend rejected the call with 401 — the stored session token is missing
/// or expired. Only a fresh login can mint a new one.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'SessionExpiredException: Login required';
}

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
  /// SECURITY: rider apiToken attached (backend requires login on calls/*).
  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body, {required String label}) {
    return retryNetwork(
      () async {
        final res = await http
            .post(
              Uri.parse('$_base$path'),
              headers: await RiderAuthService.apiHeaders(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 8));
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        // Backend returns 200 (token/status) AND 201 (request created) —
        // accept any 2xx with success:true.
        final okStatus = res.statusCode >= 200 && res.statusCode < 300;
        if (!okStatus || decoded['success'] != true) {
          // 401 = session token missing/expired — never retry, surface it.
          if (res.statusCode == 401) throw const SessionExpiredException();
          final err = Exception((decoded['error'] as String?) ?? '$label failed (${res.statusCode})');
          // 4xx business errors (not found, forbidden) won't fix themselves.
          if (res.statusCode >= 400 && res.statusCode < 500 && res.statusCode != 429) throw err;
          if (!isRetryableError(err)) throw err;
          throw err;
        }
        return decoded;
      },
      label: label,
      noRetryOn: (e) => e is SessionExpiredException || !isRetryableError(e),
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

  Future<List<DocumentReference<Map<String, dynamic>>>> _callOrderRefs(
      String orderId) async {
    final orders = _db.collection('orders');
    final refs = <DocumentReference<Map<String, dynamic>>>[orders.doc(orderId)];
    try {
      final snap = await refs.first.get().timeout(const Duration(seconds: 6));
      final alias = snap.data()?['orderId']?.toString().trim() ?? '';
      if (alias.isNotEmpty && alias != orderId) {
        final aliasRef = orders.doc(alias);
        if ((await aliasRef.get().timeout(const Duration(seconds: 6))).exists) {
          refs.add(aliasRef);
        }
      }
    } catch (e) {
      debugPrint('call order alias lookup notice: $e');
    }
    return refs;
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
    final orderRefs = await _callOrderRefs(orderId);
    var receiverId = (log['receiverId'] as String?) ?? '';
    if (callerRole == 'rider' && receiverId.isEmpty) {
      for (final ref in orderRefs) {
        try {
          final snap = await ref.get().timeout(const Duration(seconds: 4));
          final d = snap.data();
          final phone = (d?['phone'] ?? d?['customerPhone'] ?? '').toString().trim();
          if (phone.isNotEmpty) {
            receiverId = phone;
            break;
          }
        } catch (_) {}
      }
    }
    final invite = CallInvite(
      callId: (body['callId'] as String?) ?? '',
      orderId: orderId,
      channelName: (body['channelName'] as String?) ?? 'order_$orderId',
      callerId: callerId,
      callerRole: callerRole,
      receiverId: receiverId,
      receiverRole: callerRole == 'customer' ? 'rider' : 'customer',
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    );
    // Signaling lives INSIDE the order doc (field `activeCall`) — the
    // `calls` subcollection is blocked by Firestore rules, but order-doc
    // writes are allowed. One active call per order; a new call overwrites.
    final signalMap = invite.toMap()..['callId'] = invite.callId;
    await _writeWithRetry(
      () async {
        await Future.wait(
            orderRefs.map((ref) => ref.update({'activeCall': signalMap})));
      },
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
              headers: await RiderAuthService.apiHeaders(),
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

  // ── Receiver: live invite from the order doc's `activeCall` field ──
  Stream<List<CallInvite>> incomingCallStream({required String orderId, required String myId}) {
    return _db
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((d) {
      final data = d.data();
      final m = data?['activeCall'] as Map<String, dynamic>?;
      if (m == null) return <CallInvite>[];
      final callId = (m['callId'] as String?) ?? '';
      if (callId.isEmpty) return <CallInvite>[];
      if ((m['status'] as String?) != 'ringing') return <CallInvite>[];

      final recId = (m['receiverId'] as String?) ?? '';
      final recRole = (m['receiverRole'] as String?) ?? '';
      final callerRole = (m['callerRole'] as String?) ?? '';
      final callerId = (m['callerId'] as String?) ?? '';

      // Rider app: never treat our own outgoing call as incoming
      if (callerRole == 'rider') return <CallInvite>[];

      final myClean = myId.replaceAll(RegExp(r'[^0-9]'), '');
      final my10 = myClean.length >= 10 ? myClean.substring(myClean.length - 10) : myClean;
      final callerClean = callerId.replaceAll(RegExp(r'[^0-9]'), '');
      final caller10 = callerClean.length >= 10 ? callerClean.substring(callerClean.length - 10) : callerClean;

      if (callerId == myId || (my10.isNotEmpty && caller10.isNotEmpty && caller10 == my10)) {
        return <CallInvite>[];
      }

      final recClean = recId.replaceAll(RegExp(r'[^0-9]'), '');
      final rec10 = recClean.length >= 10 ? recClean.substring(recClean.length - 10) : recClean;

      final isMatch = recId == myId ||
          (my10.isNotEmpty && rec10 == my10) ||
          recRole == 'rider' ||
          callerRole == 'customer';

      if (!isMatch) return <CallInvite>[];
      return [CallInvite.fromDoc(callId, m)];
    });
  }

  // ── Watch one call's status (caller waits for accept/reject/end) ──
  Stream<CallInvite?> watchCall({required String orderId, required String callId}) {
    return _db
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .map((d) {
      final data = d.data();
      final m = data?['activeCall'] as Map<String, dynamic>?;
      if (m == null) return null;
      final id = (m['callId'] as String?) ?? '';
      if (id.isEmpty || id != callId) return null;
      return CallInvite.fromDoc(id, m);
    });
  }

  Future<void> setStatus({
    required String orderId,
    required String callId,
    required CallStatus status,
  }) async {
    // Backend first (authoritative lifecycle: accept/reject/end validated +
    // terminal states locked). Firestore mirrors only what the server allows.
    try {
      await _postJson(
        '/api/calls/$orderId/status',
        {'callId': callId, 'status': callStatusName(status)},
        label: 'call status update',
      );
    } catch (e) {
      debugPrint('call status server notice: $e');
      // 409 = server already moved past this state (ended/missed) — still
      // mirror locally so the UI stops ringing; never rewind the server.
      if (!e.toString().contains('already')) rethrow;
    }
    await _writeWithRetry(
      () => _db.collection('orders').doc(orderId).update({
        'activeCall.status': callStatusName(status),
      }),
      label: 'call status mirror',
    );
  }

  /// Caller cancelled while ringing, or 45s ring timeout → server marks the
  /// call so the recipient's ring dies even if Firestore echo is delayed.
  Future<void> cancelOrTimeout({
    required String orderId,
    required String callId,
    required bool isTimeout,
  }) async {
    try {
      if (isTimeout) {
        await _postJson(
          '/api/calls/$orderId/timeout',
          {'callId': callId},
          label: 'call timeout',
        );
      } else {
        await _postJson(
          '/api/calls/$orderId/status',
          {'callId': callId, 'status': 'cancelled'},
          label: 'call cancel',
        );
      }
    } catch (e) {
      debugPrint('call cancel/timeout notice: $e');
    }
    try {
      await _writeWithRetry(
        () => _db.collection('orders').doc(orderId).update({
          'activeCall.status': isTimeout ? 'missed' : 'ended',
        }),
        label: 'call cancel mirror',
      );
    } catch (e) {
      debugPrint('call cancel mirror notice: $e');
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
        () => _db.collection('orders').doc(orderId).update({
          'activeCall.status': 'ended',
        }),
        label: 'end-call write',
      );
    } catch (e) {
      debugPrint('firestore end-call notice: $e');
    }
  }
}
