// ─── Food Mela — Agora voice engine wrapper ───────────────────────────────────
// Voice-only (audio). Handles join/leave, mute, speaker, remote events.
// Requires dependency: agora_rtc_engine: ^6.3.0
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'call_config.dart';

class CallEngine {
  CallEngine._();
  static final CallEngine instance = CallEngine._();

  RtcEngine? _engine;
  bool _muted = false;
  bool _speaker = false;

  bool get isMuted => _muted;
  bool get isSpeaker => _speaker;

  void Function(int remoteUid)? onUserJoined;
  void Function(int remoteUid)? onUserOffline;
  void Function()? onLeft;
  void Function(String message)? onError;

  Future<void> _ensureEngine() async {
    if (_engine != null) return;
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) throw Exception('Microphone permission denied');
    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(appId: CallConfig.agoraAppId));
    await _engine!.enableAudio();
    await _engine!.setDefaultAudioRouteToSpeakerphone(false);
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (conn, uid, _) => onUserJoined?.call(uid),
      onUserOffline: (conn, uid, _) => onUserOffline?.call(uid),
      onLeaveChannel: (conn, _) => onLeft?.call(),
      onError: (code, msg) {
        debugPrint('⚠️ Agora $code $msg');
        onError?.call('Audio error $code');
      },
    ));
  }

  Future<void> join({required String channel, required String token, required int uid}) async {
    await _ensureEngine();
    _muted = false;
    _speaker = false;
    await _engine!.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<void> toggleMute() async {
    _muted = !_muted;
    await _engine?.muteLocalAudioStream(_muted);
  }

  Future<void> toggleSpeaker() async {
    _speaker = !_speaker;
    await _engine?.setEnableSpeakerphone(_speaker);
  }

  Future<void> leave() async {
    try {
      await _engine?.leaveChannel();
    } catch (e) {
      debugPrint('leave notice: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _engine?.release();
    } catch (e) {
      debugPrint('dispose notice: $e');
    }
    _engine = null;
  }
}
