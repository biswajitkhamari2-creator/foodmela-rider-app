// ─── Food Mela — Call signaling models ────────────────────────────────────────
// Signaling rides on Firestore: orders/{orderId}/calls/{callId}.
// Only customerPhone / assigned riderId of an ACTIVE order may read/write
// (enforced by firestore.rules + backend token check).

enum CallStatus { ringing, accepted, rejected, ended, missed, failed }

CallStatus callStatusFrom(String? s) {
  switch (s) {
    case 'accepted':
      return CallStatus.accepted;
    case 'rejected':
      return CallStatus.rejected;
    case 'ended':
      return CallStatus.ended;
    case 'missed':
      return CallStatus.missed;
    case 'failed':
      return CallStatus.failed;
    default:
      return CallStatus.ringing;
  }
}

String callStatusName(CallStatus s) => s.name;

class CallInvite {
  final String callId;
  final String orderId;
  final String channelName;
  final String callerId;
  final String callerRole; // 'customer' | 'rider'
  final String receiverId;
  final String receiverRole;
  final CallStatus status;
  final DateTime createdAt;

  const CallInvite({
    required this.callId,
    required this.orderId,
    required this.channelName,
    required this.callerId,
    required this.callerRole,
    required this.receiverId,
    required this.receiverRole,
    required this.status,
    required this.createdAt,
  });

  factory CallInvite.fromDoc(String callId, Map<String, dynamic> d) {
    int ms = 0;
    final ts = d['createdAt'];
    if (ts is int) {
      ms = ts;
    } else if (ts is String) {
      ms = DateTime.tryParse(ts)?.millisecondsSinceEpoch ?? 0;
    }
    return CallInvite(
      callId: callId,
      orderId: (d['orderId'] as String?) ?? '',
      channelName: (d['channelName'] as String?) ?? '',
      callerId: (d['callerId'] as String?) ?? '',
      callerRole: (d['callerRole'] as String?) ?? 'customer',
      receiverId: (d['receiverId'] as String?) ?? '',
      receiverRole: (d['receiverRole'] as String?) ?? 'rider',
      status: callStatusFrom(d['status'] as String?),
      createdAt: DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'channelName': channelName,
        'callerId': callerId,
        'callerRole': callerRole,
        'receiverId': receiverId,
        'receiverRole': receiverRole,
        'status': callStatusName(status),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  /// Role label shown in UI — never a phone number (privacy).
  String get callerLabel => callerRole == 'rider' ? 'Assigned Rider' : 'Customer';
  String get receiverLabel => receiverRole == 'rider' ? 'Assigned Rider' : 'Customer';
}
