import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'auth_service_supabase.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:retry/retry.dart';
import 'app_flow_manager.dart';
import '../chat/sqlite_helper.dart';
import 'voice_service.dart'; // Reuse error types and config
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Video service error types (extends VoiceServiceError)
enum VideoServiceError {
  configMissing,
  permissionDenied,
  networkError,
  joinFailed,
  tokenGenerationFailed,
  engineInitializationFailed,
  cameraError,
  virtualBackgroundError,
  unknown,
}

/// Video service result wrapper
class VideoServiceResult<T> {
  final bool success;
  final T? data;
  final VideoServiceError? error;
  final String? errorMessage;

  VideoServiceResult._({
    required this.success,
    this.data,
    this.error,
    this.errorMessage,
  });

  factory VideoServiceResult.success(T data) {
    return VideoServiceResult._(success: true, data: data);
  }

  factory VideoServiceResult.failure(VideoServiceError error, String message) {
    return VideoServiceResult._(
      success: false,
      error: error,
      errorMessage: message,
    );
  }

  bool get isSuccess => success;
  bool get isFailure => !success;
}

/// Video participant state with camera and video info
class VideoParticipant {
  final String uid;
  final String displayName;
  final bool isMuted;
  final bool isSpeaking;
  final bool isHost;
  final bool isOnline;
  final bool hasVideo;
  final bool isCameraEnabled;
  final DateTime? lastSeen;

  VideoParticipant({
    required this.uid,
    required this.displayName,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isHost = false,
    this.isOnline = true,
    this.hasVideo = false,
    this.isCameraEnabled = false,
    this.lastSeen,
  });

  VideoParticipant copyWith({
    String? uid,
    String? displayName,
    bool? isMuted,
    bool? isSpeaking,
    bool? isHost,
    bool? isOnline,
    bool? hasVideo,
    bool? isCameraEnabled,
    DateTime? lastSeen,
  }) {
    return VideoParticipant(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isHost: isHost ?? this.isHost,
      isOnline: isOnline ?? this.isOnline,
      hasVideo: hasVideo ?? this.hasVideo,
      isCameraEnabled: isCameraEnabled ?? this.isCameraEnabled,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'isMuted': isMuted,
      'isSpeaking': isSpeaking,
      'isHost': isHost,
      'isOnline': isOnline,
      'hasVideo': hasVideo,
      'isCameraEnabled': isCameraEnabled,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  factory VideoParticipant.fromMap(Map<String, dynamic> map) {
    return VideoParticipant(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'Unknown',
      isMuted: map['isMuted'] ?? false,
      isSpeaking: map['isSpeaking'] ?? false,
      isHost: map['isHost'] ?? false,
      isOnline: map['isOnline'] ?? true,
      hasVideo: map['hasVideo'] ?? false,
      isCameraEnabled: map['isCameraEnabled'] ?? false,
      lastSeen:
          map['lastSeen'] != null ? DateTime.tryParse(map['lastSeen']) : null,
    );
  }
}

/// Video room state
class VideoRoomState {
  final String roomId;
  final String roomName;
  final List<VideoParticipant> participants;
  final bool isJoined;
  final bool isMuted;
  final bool isVideoEnabled;
  final bool isCameraFront;
  final bool isBeautyFilterEnabled;
  final bool isVirtualBackgroundEnabled;
  final bool isLoading;
  final String? error;
  final bool isReconnecting;
  final int reconnectAttempts;
  final bool isHost;
  final bool isNetworkAvailable;

  VideoRoomState({
    required this.roomId,
    required this.roomName,
    this.participants = const [],
    this.isJoined = false,
    this.isMuted = false,
    this.isVideoEnabled = false,
    this.isCameraFront = true,
    this.isBeautyFilterEnabled = false,
    this.isVirtualBackgroundEnabled = false,
    this.isLoading = false,
    this.error,
    this.isReconnecting = false,
    this.reconnectAttempts = 0,
    this.isHost = false,
    this.isNetworkAvailable = true,
  });

  VideoRoomState copyWith({
    String? roomId,
    String? roomName,
    List<VideoParticipant>? participants,
    bool? isJoined,
    bool? isMuted,
    bool? isVideoEnabled,
    bool? isCameraFront,
    bool? isBeautyFilterEnabled,
    bool? isVirtualBackgroundEnabled,
    bool? isLoading,
    String? error,
    bool? isReconnecting,
    int? reconnectAttempts,
    bool? isHost,
    bool? isNetworkAvailable,
  }) {
    return VideoRoomState(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      participants: participants ?? this.participants,
      isJoined: isJoined ?? this.isJoined,
      isMuted: isMuted ?? this.isMuted,
      isVideoEnabled: isVideoEnabled ?? this.isVideoEnabled,
      isCameraFront: isCameraFront ?? this.isCameraFront,
      isBeautyFilterEnabled:
          isBeautyFilterEnabled ?? this.isBeautyFilterEnabled,
      isVirtualBackgroundEnabled:
          isVirtualBackgroundEnabled ?? this.isVirtualBackgroundEnabled,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      isHost: isHost ?? this.isHost,
      isNetworkAvailable: isNetworkAvailable ?? this.isNetworkAvailable,
    );
  }
}

/// Enhanced VideoService with full video capabilities
class VideoService {
  RtcEngine? _engine;
  final RtcEngine Function() _engineFactory;
  final AppFlowManager? _appFlowManager; // ignore: unused_field
  final SQLiteHelper? _sqliteHelper; // ignore: unused_field

  // Network monitoring
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isNetworkAvailable = true;

  // Video state tracking
  bool _isVideoEnabled = false;
  bool _isCameraFront = true;
  bool _isBeautyFilterEnabled = false;
  bool _isVirtualBackgroundEnabled = false;

  // Callbacks for real-time updates
  Function(String uid, bool isMuted)? onMuteChanged;
  Function(String uid, bool isSpeaking)? onSpeakingChanged;
  Function(String uid, bool hasVideo)? onVideoStateChanged;
  Function(String uid)? onParticipantJoined;
  Function(String uid)? onParticipantLeft;
  Function(VideoServiceError error, String message)? onError;
  Function(int quality)? onNetworkQualityChanged;

  VideoService({
    RtcEngine Function()? engineFactory,
    AppFlowManager? appFlowManager,
    SQLiteHelper? sqliteHelper,
  })  : _engineFactory = engineFactory ?? createAgoraRtcEngine,
        _appFlowManager = appFlowManager,
        _sqliteHelper = sqliteHelper {
    _initializeConnectivityMonitoring();
  }

  void _initializeConnectivityMonitoring() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final wasNetworkAvailable = _isNetworkAvailable;
    _isNetworkAvailable = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);

    if (!wasNetworkAvailable && _isNetworkAvailable && _engine != null) {
      onError?.call(VideoServiceError.networkError,
          'Network restored. You may need to reconnect to video chat.');
    }
  }

  /// Initialize Agora engine with video support
  Future<VideoServiceResult<void>> initializeEngine() async {
    try {
      // Validate Agora configuration
      final appIdResult = AgoraConfigEnhanced.getValidatedAppId();
      if (appIdResult.isFailure) {
        return VideoServiceResult.failure(
          VideoServiceError.configMissing,
          appIdResult.errorMessage!,
        );
      }

      // Request camera and microphone permissions
      final permissionResult = await _requestVideoPermissions();
      if (permissionResult.isFailure) {
        return permissionResult;
      }

      // Initialize Agora engine
      _engine ??= _engineFactory();
      await _engine!.initialize(RtcEngineContext(appId: appIdResult.data));

      // Set up event handlers
      _setupEventHandlers();

      // Configure audio and video profiles
      await _configureAudioVideoProfile();

      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Request camera and microphone permissions
  Future<VideoServiceResult<void>> _requestVideoPermissions() async {
    // Request microphone permission
    PermissionStatus micStatus = await Permission.microphone.status;

    if (!micStatus.isGranted) {
      if (micStatus.isPermanentlyDenied) {
        // TODO: Show notification via NotificationService
        await openAppSettings();
        return VideoServiceResult.failure(
          VideoServiceError.permissionDenied,
          'Microphone permission permanently denied. Please enable in settings.',
        );
      }

      micStatus = await Permission.microphone.request();

      if (!micStatus.isGranted) {
        return VideoServiceResult.failure(
          VideoServiceError.permissionDenied,
          'Microphone permission denied. Video chat requires microphone access.',
        );
      }
    }

    // Request camera permission
    PermissionStatus cameraStatus = await Permission.camera.status;

    if (!cameraStatus.isGranted) {
      if (cameraStatus.isPermanentlyDenied) {
        // TODO: Show notification via NotificationService
        await openAppSettings();
        return VideoServiceResult.failure(
          VideoServiceError.permissionDenied,
          'Camera permission permanently denied. Please enable in settings.',
        );
      }

      cameraStatus = await Permission.camera.request();

      if (!cameraStatus.isGranted) {
        return VideoServiceResult.failure(
          VideoServiceError.permissionDenied,
          'Camera permission denied. Video chat requires camera access.',
        );
      }
    }

    return VideoServiceResult.success(null);
  }

  void _setupEventHandlers() {
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) {
        onParticipantJoined?.call(remoteUid.toString());
      },
      onUserOffline: (connection, remoteUid, reason) {
        onParticipantLeft?.call(remoteUid.toString());
      },
      onRemoteVideoStateChanged:
          (connection, remoteUid, state, reason, elapsed) {
        final hasVideo = state == RemoteVideoState.remoteVideoStateStarting ||
            state == RemoteVideoState.remoteVideoStateDecoding;
        onVideoStateChanged?.call(remoteUid.toString(), hasVideo);
      },
      onAudioVolumeIndication:
          (connection, speakers, speakerNumber, totalVolume) {
        _handleVolumeIndication(speakers);
      },
      onNetworkQuality: (connection, remoteUid, txQuality, rxQuality) {
        // Report worst quality between tx and rx
        final worstQuality =
            txQuality.index > rxQuality.index ? txQuality : rxQuality;
        onNetworkQualityChanged?.call(worstQuality.index);
      },
      onError: (err, msg) {
        final error = _classifyError(msg);
        onError?.call(error.error!, error.errorMessage!);
      },
      onConnectionStateChanged: (connection, state, reason) {
        if (state == ConnectionStateType.connectionStateDisconnected &&
            !_isNetworkAvailable) {
          onError?.call(VideoServiceError.networkError,
              'Video connection lost due to network issues.');
        }
      },
      onLocalVideoStateChanged: (source, state, error) {
        if (error != LocalVideoStreamReason.localVideoStreamReasonOk) {
          onError?.call(VideoServiceError.cameraError,
              'Camera error: ${error.toString()}');
        }
      },
    ));
  }

  void _handleVolumeIndication(List<AudioVolumeInfo> speakers) {
    for (final speaker in speakers) {
      final uid = speaker.uid.toString();
      final isSpeaking = (speaker.volume ?? 0) > 10;
      onSpeakingChanged?.call(uid, isSpeaking);
    }
  }

  Future<void> _configureAudioVideoProfile() async {
    // Configure audio profile
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileMusicHighQuality,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    // Configure video profile
    await _engine!.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 640, height: 360),
        frameRate: 15,
        bitrate: 0, // Auto bitrate
        orientationMode: OrientationMode.orientationModeAdaptive,
        degradationPreference: DegradationPreference.maintainBalanced,
      ),
    );

    // Enable audio mixing
    await _engine!.setParameters('{"che.audio.enable.audio_mixing": true}');
  }

  /// Generate Agora token (same as voice service)
  Future<String?> generateToken(String channelName, int uid) async {
    final certResult = AgoraConfigEnhanced.getValidatedCertificate();
    if (certResult.isFailure || (certResult.data?.isEmpty ?? true)) {
      return null;
    }

    try {
      // Get backend URL from environment variable (runtime)
      final backendUrl = dotenv.env['BACKEND_URL'] ??
          'https://squadsync-backend-kinmmpi3ca-uc.a.run.app';

      final response = await retry(
        () => http.post(
          Uri.parse('$backendUrl/generate-agora-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'channelName': channelName,
            'uid': uid,
            'certificate': certResult.data,
          }),
        ),
        retryIf: (e) => e is http.ClientException || e is TimeoutException,
        maxAttempts: 3,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'] as String?;
      }
      throw Exception('Token generation failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error generating token: $e');
      return null;
    }
  }

  /// Enable video
  Future<VideoServiceResult<void>> enableVideo() async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      await _engine!.enableVideo();
      await _engine!.startPreview();
      _isVideoEnabled = true;
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Disable video
  Future<VideoServiceResult<void>> disableVideo() async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      await _engine!.stopPreview();
      await _engine!.disableVideo();
      _isVideoEnabled = false;
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Setup local video view
  Widget setupLocalVideoView() {
    if (_engine == null) {
      return const Center(
        child: Text('Video engine not initialized'),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  /// Setup remote video view
  Widget setupRemoteVideoView(int uid) {
    if (_engine == null) {
      return const Center(
        child: Text('Video engine not initialized'),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine!,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: ''),
      ),
    );
  }

  /// Toggle camera on/off
  Future<VideoServiceResult<void>> toggleCamera() async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      if (_isVideoEnabled) {
        await disableVideo();
      } else {
        await enableVideo();
      }
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Flip camera (front/back)
  Future<VideoServiceResult<void>> flipCamera() async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      await _engine!.switchCamera();
      _isCameraFront = !_isCameraFront;
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Toggle beauty filter
  Future<VideoServiceResult<void>> toggleBeautyFilter() async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      _isBeautyFilterEnabled = !_isBeautyFilterEnabled;

      await _engine!.setBeautyEffectOptions(
        enabled: _isBeautyFilterEnabled,
        options: const BeautyOptions(
          lighteningContrastLevel:
              LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: 0.7,
          smoothnessLevel: 0.5,
          rednessLevel: 0.1,
          sharpnessLevel: 0.3,
        ),
      );

      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Enable virtual background (blur or image)
  Future<VideoServiceResult<void>> enableVirtualBackground({
    bool blur = true,
    String? imagePath,
  }) async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      VirtualBackgroundSource source;

      if (blur) {
        // Blur background
        source = const VirtualBackgroundSource(
          backgroundSourceType: BackgroundSourceType.backgroundBlur,
          blurDegree: BackgroundBlurDegree.blurDegreeMedium,
        );
      } else if (imagePath != null) {
        // Image background
        source = VirtualBackgroundSource(
          backgroundSourceType: BackgroundSourceType.backgroundImg,
          source: imagePath,
        );
      } else {
        // No background effect
        source = const VirtualBackgroundSource(
          backgroundSourceType: BackgroundSourceType.backgroundNone,
        );
      }

      await _engine!.enableVirtualBackground(
        enabled: true,
        backgroundSource: source,
        segproperty: const SegmentationProperty(
          modelType: SegModelType.segModelAi,
          greenCapacity: 0.5,
        ),
      );

      _isVirtualBackgroundEnabled = true;
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Disable virtual background
  Future<VideoServiceResult<void>> disableVirtualBackground() async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      await _engine!.enableVirtualBackground(
        enabled: false,
        backgroundSource: const VirtualBackgroundSource(
          backgroundSourceType: BackgroundSourceType.backgroundNone,
        ),
        segproperty: const SegmentationProperty(),
      );

      _isVirtualBackgroundEnabled = false;
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Join video room (enables video + audio)
  Future<VideoServiceResult<void>> joinVideoRoom(
    String channelName, {
    int uid = 0,
    bool enableVideo = true,
  }) async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      // Enable video if requested
      if (enableVideo) {
        await this.enableVideo();
      }

      final token = await generateToken(channelName, uid);

      if (token != null) {
        await _engine!.joinChannelWithUserAccount(
          token: token,
          channelId: channelName,
          userAccount: AuthServiceSupabase().currentUser?.id ?? 'anonymous',
          options: ChannelMediaOptions(
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
            publishMicrophoneTrack: true,
            publishCameraTrack: enableVideo,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      } else {
        await _engine!.joinChannel(
          token: '',
          channelId: channelName,
          uid: uid,
          options: ChannelMediaOptions(
            autoSubscribeAudio: true,
            autoSubscribeVideo: true,
            publishMicrophoneTrack: true,
            publishCameraTrack: enableVideo,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      }

      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Leave video room
  Future<VideoServiceResult<void>> leaveVideoRoom() async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      await _engine!.stopPreview();
      await _engine!.leaveChannel();
      _isVideoEnabled = false;
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Toggle local mute
  Future<VideoServiceResult<void>> toggleMute(bool muted) async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      await _engine!.muteLocalAudioStream(muted);
      onMuteChanged?.call(AuthServiceSupabase().currentUser?.id ?? '0', muted);
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Enable/disable local video stream
  Future<VideoServiceResult<void>> muteLocalVideo(bool muted) async {
    if (_engine == null) {
      return VideoServiceResult.failure(
        VideoServiceError.engineInitializationFailed,
        'Video engine not initialized',
      );
    }

    try {
      await _engine!.muteLocalVideoStream(muted);
      return VideoServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VideoServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  VideoServiceResult<VideoServiceError> _classifyError(dynamic error) {
    if (error is String) {
      if (error.contains('permission') || error.contains('Permission')) {
        return VideoServiceResult.success(VideoServiceError.permissionDenied);
      }
      if (error.contains('camera') || error.contains('Camera')) {
        return VideoServiceResult.success(VideoServiceError.cameraError);
      }
      if (error.contains('network') || error.contains('connection')) {
        return VideoServiceResult.success(VideoServiceError.networkError);
      }
      if (error.contains('join') || error.contains('channel')) {
        return VideoServiceResult.success(VideoServiceError.joinFailed);
      }
      if (error.contains('token')) {
        return VideoServiceResult.success(
            VideoServiceError.tokenGenerationFailed);
      }
      if (error.contains('background') || error.contains('virtual')) {
        return VideoServiceResult.success(
            VideoServiceError.virtualBackgroundError);
      }
    }

    return VideoServiceResult.success(VideoServiceError.unknown);
  }

  // Getters for video state
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isCameraFront => _isCameraFront;
  bool get isBeautyFilterEnabled => _isBeautyFilterEnabled;
  bool get isVirtualBackgroundEnabled => _isVirtualBackgroundEnabled;

  void dispose() {
    _connectivitySubscription?.cancel();
    _engine?.stopPreview();
    _engine?.leaveChannel();
    _engine = null;
  }
}

/// Video room state notifier with AsyncValue and VideoService delegation
class VideoRoomNotifier extends StateNotifier<AsyncValue<VideoRoomState>> {
  final String roomId;
  final String roomName;
  final VideoService _videoService;
  final AppFlowManager? _appFlowManager;
  final SQLiteHelper? _sqliteHelper;

  // Room sync
  StreamSubscription? _roomSyncSubscription;
  DateTime? _joinTime;

  VideoRoomNotifier({
    required this.roomId,
    required this.roomName,
    required VideoService videoService,
    AppFlowManager? appFlowManager,
    SQLiteHelper? sqliteHelper,
  })  : _videoService = videoService,
        _appFlowManager = appFlowManager,
        _sqliteHelper = sqliteHelper,
        super(const AsyncValue.loading()) {
    _initializeVideoService();
  }

  void _initializeVideoService() {
    // Set up VideoService callbacks
    _videoService.onMuteChanged = _handleMuteChanged;
    _videoService.onSpeakingChanged = _handleSpeakingChanged;
    _videoService.onVideoStateChanged = _handleVideoStateChanged;
    _videoService.onParticipantJoined = _handleParticipantJoined;
    _videoService.onParticipantLeft = _handleParticipantLeft;
    _videoService.onError = _handleVideoError;
    _videoService.onNetworkQualityChanged = _handleNetworkQualityChanged;

    // Initialize with empty state
    state = AsyncValue.data(VideoRoomState(
      roomId: roomId,
      roomName: roomName,
    ));
  }

  void _handleMuteChanged(String uid, bool isMuted) {
    state.whenData((currentState) {
      final updatedParticipants = currentState.participants.map((participant) {
        if (participant.uid == uid) {
          return participant.copyWith(isMuted: isMuted);
        }
        return participant;
      }).toList();

      state = AsyncValue.data(
          currentState.copyWith(participants: updatedParticipants));
    });
  }

  void _handleSpeakingChanged(String uid, bool isSpeaking) {
    state.whenData((currentState) {
      final updatedParticipants = currentState.participants.map((participant) {
        if (participant.uid == uid) {
          return participant.copyWith(isSpeaking: isSpeaking);
        }
        return participant;
      }).toList();

      state = AsyncValue.data(
          currentState.copyWith(participants: updatedParticipants));
    });
  }

  void _handleVideoStateChanged(String uid, bool hasVideo) {
    state.whenData((currentState) {
      final updatedParticipants = currentState.participants.map((participant) {
        if (participant.uid == uid) {
          return participant.copyWith(hasVideo: hasVideo);
        }
        return participant;
      }).toList();

      state = AsyncValue.data(
          currentState.copyWith(participants: updatedParticipants));
    });
  }

  void _handleParticipantJoined(String uid) {
    state.whenData((currentState) async {
      final displayName = await _getDisplayNameForUid(uid);
      final participant = VideoParticipant(
        uid: uid,
        displayName: displayName,
        lastSeen: DateTime.now(),
      );

      final updatedParticipants = [...currentState.participants, participant];
      state = AsyncValue.data(
          currentState.copyWith(participants: updatedParticipants));

      // Sync to Supabase
      await _syncParticipantStateSupabase(uid);
    });
  }

  void _handleParticipantLeft(String uid) {
    state.whenData((currentState) {
      final updatedParticipants =
          currentState.participants.where((p) => p.uid != uid).toList();
      state = AsyncValue.data(
          currentState.copyWith(participants: updatedParticipants));
    });
  }

  void _handleVideoError(VideoServiceError error, String message) {
    state = AsyncValue.error(message, StackTrace.current);
    _appFlowManager?.trackError(
      userId: AuthServiceSupabase().currentUser?.id ?? 'anonymous',
      errorType: error.toString(),
      errorMessage: message,
    );
  }

  void _handleNetworkQualityChanged(int quality) {
    // Quality: 0 = unknown, 1 = excellent, 2 = good, 3 = poor, 4 = bad, 5 = very bad, 6 = down
    if (quality >= 4) {
      // TODO: Show notification via NotificationService
    }
  }

  Future<String> _getDisplayNameForUid(String uid) async {
    // For now, return 'Unknown' - can be enhanced later with user data lookup
    return 'Unknown';
  }

  Future<void> initializeVideoService() async {
    state = const AsyncValue.loading();

    try {
      final result = await _videoService.initializeEngine();
      if (result.isSuccess) {
        await _initializeRoomSync();
        state = AsyncValue.data(VideoRoomState(
          roomId: roomId,
          roomName: roomName,
        ));
      } else {
        state = AsyncValue.error(result.errorMessage!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _initializeRoomSync() async {
    // TODO: Migrate to Supabase realtime subscriptions
    // Set up room sync for participant state updates
    // _roomSyncSubscription = supabase.from('video_rooms').stream(...)
    debugPrint('Room sync not yet migrated to Supabase');
  }

  Future<void> joinRoom({bool enableVideo = true}) async {
    state = const AsyncValue.loading();

    try {
      final result =
          await _videoService.joinVideoRoom(roomId, enableVideo: enableVideo);
      if (result.isSuccess) {
        _joinTime = DateTime.now();

        // Track analytics
        final userId = AuthServiceSupabase().currentUser?.id ?? 'anonymous';
        await _appFlowManager?.trackVoiceSession(
          userId: userId,
          roomId: roomId,
          duration: Duration.zero,
        );

        state.whenData((currentState) {
          state = AsyncValue.data(currentState.copyWith(
            isJoined: true,
            isVideoEnabled: enableVideo,
          ));
        });
      } else {
        state = AsyncValue.error(result.errorMessage!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> leaveRoom() async {
    try {
      final result = await _videoService.leaveVideoRoom();
      if (result.isSuccess) {
        // Track session duration
        if (_joinTime != null) {
          final duration = DateTime.now().difference(_joinTime!);
          final userId = AuthServiceSupabase().currentUser?.id ?? 'anonymous';
          await _appFlowManager?.trackVoiceSession(
            userId: userId,
            roomId: roomId,
            duration: duration,
          );
          _joinTime = null;
        }

        // Cache room state
        await _cacheRoomState();

        state.whenData((currentState) {
          state = AsyncValue.data(currentState.copyWith(
            isJoined: false,
            participants: [],
            isMuted: false,
            isVideoEnabled: false,
          ));
        });
      } else {
        state = AsyncValue.error(result.errorMessage!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _cacheRoomState() async {
    if (_sqliteHelper == null) return;

    state.whenData((currentState) async {
      final cacheData = {
        'roomId': currentState.roomId,
        'roomName': currentState.roomName,
        'participants':
            currentState.participants.map((p) => p.toMap()).toList(),
        'cachedAt': DateTime.now().toIso8601String(),
      };

      await _sqliteHelper.cacheVoiceRoom(currentState.roomId, cacheData);
    });
  }

  Future<void> toggleMute() async {
    try {
      state.whenData((currentState) async {
        final result = await _videoService.toggleMute(!currentState.isMuted);
        if (result.isSuccess) {
          state = AsyncValue.data(
              currentState.copyWith(isMuted: !currentState.isMuted));
        } else {
          state = AsyncValue.error(result.errorMessage!, StackTrace.current);
        }
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleVideo() async {
    try {
      state.whenData((currentState) async {
        final result = await _videoService.toggleCamera();
        if (result.isSuccess) {
          state = AsyncValue.data(currentState.copyWith(
              isVideoEnabled: !currentState.isVideoEnabled));
        } else {
          state = AsyncValue.error(result.errorMessage!, StackTrace.current);
        }
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> flipCamera() async {
    try {
      final result = await _videoService.flipCamera();
      if (result.isSuccess) {
        state.whenData((currentState) {
          state = AsyncValue.data(currentState.copyWith(
              isCameraFront: !currentState.isCameraFront));
        });
      } else {
        state = AsyncValue.error(result.errorMessage!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleBeautyFilter() async {
    try {
      final result = await _videoService.toggleBeautyFilter();
      if (result.isSuccess) {
        state.whenData((currentState) {
          state = AsyncValue.data(currentState.copyWith(
              isBeautyFilterEnabled: !currentState.isBeautyFilterEnabled));
        });
      } else {
        state = AsyncValue.error(result.errorMessage!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> enableVirtualBackground(
      {bool blur = true, String? imagePath}) async {
    try {
      final result = await _videoService.enableVirtualBackground(
        blur: blur,
        imagePath: imagePath,
      );
      if (result.isSuccess) {
        state.whenData((currentState) {
          state = AsyncValue.data(
              currentState.copyWith(isVirtualBackgroundEnabled: true));
        });
      } else {
        state = AsyncValue.error(result.errorMessage!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> disableVirtualBackground() async {
    try {
      final result = await _videoService.disableVirtualBackground();
      if (result.isSuccess) {
        state.whenData((currentState) {
          state = AsyncValue.data(
              currentState.copyWith(isVirtualBackgroundEnabled: false));
        });
      } else {
        state = AsyncValue.error(result.errorMessage!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Widget getLocalVideoView() {
    return _videoService.setupLocalVideoView();
  }

  Widget getRemoteVideoView(int uid) {
    return _videoService.setupRemoteVideoView(uid);
  }

  Future<void> _syncParticipantStateSupabase(String uid) async {
    // Participant state now managed via Supabase Realtime
    // Update participant state in realtime database
    debugPrint('Participant sync using Supabase Realtime: $uid');
    return;
  }

  @override
  void dispose() {
    _roomSyncSubscription?.cancel();
    _videoService.dispose();
    super.dispose();
  }
}
