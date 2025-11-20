import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Voice room participant state
class VoiceParticipant {
  final String uid;
  final String displayName;
  final bool isMuted;
  final bool isSpeaking;
  final bool isHost;

  VoiceParticipant({
    required this.uid,
    required this.displayName,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isHost = false,
  });

  VoiceParticipant copyWith({
    String? uid,
    String? displayName,
    bool? isMuted,
    bool? isSpeaking,
    bool? isHost,
  }) {
    return VoiceParticipant(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isHost: isHost ?? this.isHost,
    );
  }
}

/// Voice room state
class VoiceRoomState {
  final String roomId;
  final String roomName;
  final List<VoiceParticipant> participants;
  final bool isJoined;
  final bool isMuted;
  final bool isLoading;
  final String? error;

  VoiceRoomState({
    required this.roomId,
    required this.roomName,
    this.participants = const [],
    this.isJoined = false,
    this.isMuted = false,
    this.isLoading = false,
    this.error,
  });

  VoiceRoomState copyWith({
    String? roomId,
    String? roomName,
    List<VoiceParticipant>? participants,
    bool? isJoined,
    bool? isMuted,
    bool? isLoading,
    String? error,
  }) {
    return VoiceRoomState(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      participants: participants ?? this.participants,
      isJoined: isJoined ?? this.isJoined,
      isMuted: isMuted ?? this.isMuted,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Voice room state notifier
class VoiceRoomNotifier extends StateNotifier<VoiceRoomState> {
  RtcEngine? _engine;
  final String appId;
  final RtcEngine Function() _engineFactory;
  final Future<PermissionStatus> Function() _requestPermission;

  VoiceRoomNotifier(
    String roomId,
    String roomName, {
    String? appId,
    RtcEngine Function()? engineFactory,
    Future<PermissionStatus> Function()? requestPermission,
  })  : appId = appId ??
            const String.fromEnvironment('AGORA_APP_ID', defaultValue: ''),
        _engineFactory = engineFactory ?? createAgoraRtcEngine,
        _requestPermission =
            requestPermission ?? (() async => Permission.microphone.request()),
        super(VoiceRoomState(roomId: roomId, roomName: roomName));

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if appId is set
      if (appId.isEmpty) {
        throw Exception('AGORA_APP_ID environment variable is not set');
      }

      // Request microphone permission
      final status = await _requestPermission();
      if (!status.isGranted) {
        throw Exception('Microphone permission denied');
      }

      // Initialize Agora engine
      _engine = _engineFactory();
      await _engine!.initialize(RtcEngineContext(appId: appId));

      // Set up event handlers
      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _addParticipant(connection.localUid.toString(), 'You', isHost: true);
          state = state.copyWith(isJoined: true, isLoading: false);
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _addParticipant(remoteUid.toString(), 'User $remoteUid');
        },
        onUserOffline: (connection, remoteUid, reason) {
          _removeParticipant(remoteUid.toString());
        },
        onAudioVolumeIndication:
            (connection, speakers, speakerNumber, totalVolume) {
          _updateSpeakingStates(speakers);
        },
        onError: (err, msg) {
          state = state.copyWith(error: msg, isLoading: false);
        },
      ));

      // Set audio profile for voice chat
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicHighQuality,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> joinRoom() async {
    if (_engine == null) return;

    try {
      // Generate token (in production, get from your backend)
      const token = null; // Use null for testing, replace with actual token

      await _engine!.joinChannel(
        token: token,
        channelId: state.roomId,
        uid: 0, // Let Agora assign UID
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> leaveRoom() async {
    if (_engine == null) return;

    try {
      await _engine!.leaveChannel();
      state = state.copyWith(
        isJoined: false,
        participants: [],
        isMuted: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleMute() async {
    if (_engine == null) return;

    try {
      final newMutedState = !state.isMuted;
      await _engine!.muteLocalAudioStream(newMutedState);
      state = state.copyWith(isMuted: newMutedState);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _addParticipant(String uid, String displayName, {bool isHost = false}) {
    final participant = VoiceParticipant(
      uid: uid,
      displayName: displayName,
      isHost: isHost,
    );
    state = state.copyWith(
      participants: [...state.participants, participant],
    );
  }

  void _removeParticipant(String uid) {
    state = state.copyWith(
      participants: state.participants.where((p) => p.uid != uid).toList(),
    );
  }

  void _updateSpeakingStates(List<AudioVolumeInfo> speakers) {
    final updatedParticipants = state.participants.map((participant) {
      final speaker = speakers.firstWhere(
        (s) => s.uid.toString() == participant.uid,
        orElse: () => AudioVolumeInfo(uid: 0, volume: 0, vad: 0),
      );
      final isSpeaking = (speaker.volume ?? 0) > 10; // Volume threshold
      return participant.copyWith(isSpeaking: isSpeaking);
    }).toList();

    state = state.copyWith(participants: updatedParticipants);
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine = null;
    super.dispose();
  }
}
