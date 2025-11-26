import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:retry/retry.dart';
import '../managers/stubs.dart';
import 'app_flow_manager.dart';
import 'firestore_service.dart';
import '../chat/sqlite_helper.dart';

/// Voice service error types
enum VoiceServiceError {
  configMissing,
  permissionDenied,
  networkError,
  joinFailed,
  tokenGenerationFailed,
  engineInitializationFailed,
  unknown,
}

/// Voice service result wrapper
class VoiceServiceResult<T> {
  final bool success;
  final T? data;
  final VoiceServiceError? error;
  final String? errorMessage;

  VoiceServiceResult._({
    required this.success,
    this.data,
    this.error,
    this.errorMessage,
  });

  factory VoiceServiceResult.success(T data) {
    return VoiceServiceResult._(success: true, data: data);
  }

  factory VoiceServiceResult.failure(VoiceServiceError error, String message) {
    return VoiceServiceResult._(
      success: false,
      error: error,
      errorMessage: message,
    );
  }

  bool get isSuccess => success;
  bool get isFailure => !success;
}

/// Voice room participant state with enhanced features
class VoiceParticipant {
  final String uid;
  final String displayName;
  final bool isMuted;
  final bool isSpeaking;
  final bool isHost;
  final bool isOnline;
  final DateTime? lastSeen;

  VoiceParticipant({
    required this.uid,
    required this.displayName,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isHost = false,
    this.isOnline = true,
    this.lastSeen,
  });

  VoiceParticipant copyWith({
    String? uid,
    String? displayName,
    bool? isMuted,
    bool? isSpeaking,
    bool? isHost,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return VoiceParticipant(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isHost: isHost ?? this.isHost,
      isOnline: isOnline ?? this.isOnline,
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
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  factory VoiceParticipant.fromMap(Map<String, dynamic> map) {
    return VoiceParticipant(
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? 'Unknown',
      isMuted: map['isMuted'] ?? false,
      isSpeaking: map['isSpeaking'] ?? false,
      isHost: map['isHost'] ?? false,
      isOnline: map['isOnline'] ?? true,
      lastSeen:
          map['lastSeen'] != null ? DateTime.tryParse(map['lastSeen']) : null,
    );
  }
}

/// Voice room state with enhanced features
class VoiceRoomState {
  final String roomId;
  final String roomName;
  final List<VoiceParticipant> participants;
  final bool isJoined;
  final bool isMuted;
  final bool isLoading;
  final String? error;
  final bool isReconnecting;
  final int reconnectAttempts;
  final bool isHost;
  final bool isNetworkAvailable;

  VoiceRoomState({
    required this.roomId,
    required this.roomName,
    this.participants = const [],
    this.isJoined = false,
    this.isMuted = false,
    this.isLoading = false,
    this.error,
    this.isReconnecting = false,
    this.reconnectAttempts = 0,
    this.isHost = false,
    this.isNetworkAvailable = true,
  });

  VoiceRoomState copyWith({
    String? roomId,
    String? roomName,
    List<VoiceParticipant>? participants,
    bool? isJoined,
    bool? isMuted,
    bool? isLoading,
    String? error,
    bool? isReconnecting,
    int? reconnectAttempts,
    bool? isHost,
    bool? isNetworkAvailable,
  }) {
    return VoiceRoomState(
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      participants: participants ?? this.participants,
      isJoined: isJoined ?? this.isJoined,
      isMuted: isMuted ?? this.isMuted,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isReconnecting: isReconnecting ?? this.isReconnecting,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      isHost: isHost ?? this.isHost,
      isNetworkAvailable: isNetworkAvailable ?? this.isNetworkAvailable,
    );
  }
}

/// Enhanced Agora configuration with validation and fallbacks
class AgoraConfigEnhanced {
  static const String _mockAppId = 'mock_app_id_for_development';
  static const String _mockCertificate = 'mock_certificate_for_development';

  static VoiceServiceResult<String> getValidatedAppId() {
    try {
      final id = dotenv.env['AGORA_APP_ID'] ?? '';
      if (id.isNotEmpty) {
        return VoiceServiceResult.success(id);
      }

      if (kDebugMode) {
        debugPrint('AGORA_APP_ID not found, using mock for development');
        return VoiceServiceResult.success(_mockAppId);
      }

      return VoiceServiceResult.failure(
        VoiceServiceError.configMissing,
        'AGORA_APP_ID is required in production',
      );
    } catch (e) {
      return VoiceServiceResult.failure(
        VoiceServiceError.configMissing,
        'Failed to load AGORA_APP_ID: $e',
      );
    }
  }

  static VoiceServiceResult<String> getValidatedCertificate() {
    try {
      final cert = dotenv.env['AGORA_APP_CERTIFICATE'] ?? '';
      if (cert.isNotEmpty) {
        return VoiceServiceResult.success(cert);
      }

      if (kDebugMode) {
        debugPrint(
            'AGORA_APP_CERTIFICATE not found, using mock for development');
        return VoiceServiceResult.success(_mockCertificate);
      }

      // Certificate is optional for testing mode
      return VoiceServiceResult.success('');
    } catch (e) {
      return VoiceServiceResult.failure(
        VoiceServiceError.configMissing,
        'Failed to load AGORA_APP_CERTIFICATE: $e',
      );
    }
  }
}

/// Core VoiceService handling Agora operations
class VoiceService {
  RtcEngine? _engine;
  final RtcEngine Function() _engineFactory;
  final NotificationManager? _notificationManager;
  final AppFlowManager? _appFlowManager; // ignore: unused_field
  final FirestoreService? _firestoreService; // ignore: unused_field
  final SQLiteHelper? _sqliteHelper; // ignore: unused_field

  // Network monitoring
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isNetworkAvailable = true;

  // Callbacks for real-time updates
  Function(String uid, bool isMuted)? onMuteChanged;
  Function(String uid, bool isSpeaking)? onSpeakingChanged;
  Function(String uid)? onParticipantJoined;
  Function(String uid)? onParticipantLeft;
  Function(VoiceServiceError error, String message)? onError;

  VoiceService({
    RtcEngine Function()? engineFactory,
    NotificationManager? notificationManager,
    AppFlowManager? appFlowManager,
    FirestoreService? firestoreService,
    SQLiteHelper? sqliteHelper,
  })  : _engineFactory = engineFactory ?? createAgoraRtcEngine,
        _notificationManager = notificationManager,
        _appFlowManager = appFlowManager,
        _firestoreService = firestoreService,
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
      onError?.call(VoiceServiceError.networkError,
          'Network restored. You may need to reconnect to voice chat.');
    }
  }

  /// Initialize Agora engine with validation
  Future<VoiceServiceResult<void>> initializeEngine() async {
    try {
      // Validate Agora configuration
      final appIdResult = AgoraConfigEnhanced.getValidatedAppId();
      if (appIdResult.isFailure) {
        return VoiceServiceResult.failure(
          appIdResult.error!,
          appIdResult.errorMessage!,
        );
      }

      // Request microphone permission
      final permissionResult = await _requestMicrophonePermission();
      if (permissionResult.isFailure) {
        return permissionResult;
      }

      // Initialize Agora engine
      _engine ??= _engineFactory();
      await _engine!.initialize(RtcEngineContext(appId: appIdResult.data));

      // Set up event handlers
      _setupEventHandlers();

      // Configure audio profile
      await _configureAudioProfile();

      return VoiceServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VoiceServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  Future<VoiceServiceResult<void>> _requestMicrophonePermission() async {
    PermissionStatus status = await Permission.microphone.status;

    if (status.isGranted) {
      return VoiceServiceResult.success(null);
    }

    if (status.isPermanentlyDenied) {
      _notificationManager?.showNotification(
        title: 'Microphone Permission Required',
        body:
            'Please enable microphone access in app settings to use voice chat.',
      );
      await openAppSettings();
      return VoiceServiceResult.failure(
        VoiceServiceError.permissionDenied,
        'Microphone permission permanently denied. Please enable in settings.',
      );
    }

    status = await Permission.microphone.request();

    if (status.isGranted) {
      return VoiceServiceResult.success(null);
    }

    return VoiceServiceResult.failure(
      VoiceServiceError.permissionDenied,
      'Microphone permission denied. Voice chat requires microphone access.',
    );
  }

  void _setupEventHandlers() {
    _engine!.registerEventHandler(RtcEngineEventHandler(
      onUserJoined: (connection, remoteUid, elapsed) {
        onParticipantJoined?.call(remoteUid.toString());
      },
      onUserOffline: (connection, remoteUid, reason) {
        onParticipantLeft?.call(remoteUid.toString());
      },
      onAudioVolumeIndication:
          (connection, speakers, speakerNumber, totalVolume) {
        _handleVolumeIndication(speakers);
      },
      onError: (err, msg) {
        final error = _classifyError(msg);
        onError?.call(error.error!, error.errorMessage!);
      },
      onConnectionStateChanged: (connection, state, reason) {
        if (state == ConnectionStateType.connectionStateDisconnected &&
            !_isNetworkAvailable) {
          onError?.call(VoiceServiceError.networkError,
              'Voice connection lost due to network issues.');
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

  Future<void> _configureAudioProfile() async {
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileMusicHighQuality,
      scenario: AudioScenarioType.audioScenarioChatroom,
    );

    await _engine!.setParameters('{"che.audio.enable.audio_mixing": true}');
    await _engine!.setParameters('{"che.audio.enable.ear_monitoring": false}');
  }

  /// Generate Agora token
  Future<String?> generateToken(String channelName, int uid) async {
    final certResult = AgoraConfigEnhanced.getValidatedCertificate();
    if (certResult.isFailure || (certResult.data?.isEmpty ?? true)) {
      return null;
    }

    try {
      final response = await retry(
        () => http.post(
          Uri.parse('http://localhost:8080/generate-agora-token'),
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

  /// Join voice channel
  Future<VoiceServiceResult<void>> joinChannel(String channelName,
      {int uid = 0}) async {
    if (_engine == null) {
      return VoiceServiceResult.failure(
        VoiceServiceError.engineInitializationFailed,
        'Voice engine not initialized',
      );
    }

    try {
      final token = await generateToken(channelName, uid);

      if (token != null) {
        await _engine!.joinChannelWithUserAccount(
          token: token,
          channelId: channelName,
          userAccount: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
          options: const ChannelMediaOptions(
            autoSubscribeAudio: true,
            publishMicrophoneTrack: true,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      } else {
        await _engine!.joinChannel(
          token: '',
          channelId: channelName,
          uid: uid,
          options: const ChannelMediaOptions(
            autoSubscribeAudio: true,
            publishMicrophoneTrack: true,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      }

      return VoiceServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VoiceServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Leave voice channel
  Future<VoiceServiceResult<void>> leaveChannel() async {
    if (_engine == null) {
      return VoiceServiceResult.failure(
        VoiceServiceError.engineInitializationFailed,
        'Voice engine not initialized',
      );
    }

    try {
      await _engine!.leaveChannel();
      return VoiceServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VoiceServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  /// Toggle local mute
  Future<VoiceServiceResult<void>> toggleMute(bool muted) async {
    if (_engine == null) {
      return VoiceServiceResult.failure(
        VoiceServiceError.engineInitializationFailed,
        'Voice engine not initialized',
      );
    }

    try {
      await _engine!.muteLocalAudioStream(muted);
      onMuteChanged?.call(FirebaseAuth.instance.currentUser?.uid ?? '0', muted);
      return VoiceServiceResult.success(null);
    } catch (e) {
      final error = _classifyError(e);
      return VoiceServiceResult.failure(error.error!, error.errorMessage!);
    }
  }

  VoiceServiceResult<VoiceServiceError> _classifyError(dynamic error) {
    if (error is String) {
      if (error.contains('permission') || error.contains('Permission')) {
        return VoiceServiceResult.success(VoiceServiceError.permissionDenied);
      }
      if (error.contains('network') || error.contains('connection')) {
        return VoiceServiceResult.success(VoiceServiceError.networkError);
      }
      if (error.contains('join') || error.contains('channel')) {
        return VoiceServiceResult.success(VoiceServiceError.joinFailed);
      }
      if (error.contains('token')) {
        return VoiceServiceResult.success(
            VoiceServiceError.tokenGenerationFailed);
      }
    }

    return VoiceServiceResult.success(VoiceServiceError.unknown);
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _engine?.leaveChannel();
    _engine = null;
  }
}

/// Voice room state notifier with AsyncValue and VoiceService delegation
class VoiceRoomNotifier extends StateNotifier<AsyncValue<VoiceRoomState>> {
  final String roomId;
  final String roomName;
  final VoiceService _voiceService;
  final NotificationManager? _notificationManager; // ignore: unused_field
  final AppFlowManager? _appFlowManager; // ignore: unused_field
  final FirestoreService? _firestoreService; // ignore: unused_field
  final SQLiteHelper? _sqliteHelper; // ignore: unused_field

  // Room sync
  StreamSubscription? _roomSyncSubscription;
  DateTime? _joinTime;

  VoiceRoomNotifier({
    required this.roomId,
    required this.roomName,
    required VoiceService voiceService,
    NotificationManager? notificationManager,
    AppFlowManager? appFlowManager,
    FirestoreService? firestoreService,
    SQLiteHelper? sqliteHelper,
  })  : _voiceService = voiceService,
        _notificationManager = notificationManager,
        _appFlowManager = appFlowManager,
        _firestoreService = firestoreService,
        _sqliteHelper = sqliteHelper,
        super(const AsyncValue.loading()) {
    _initializeVoiceService();
  }

  void _initializeVoiceService() {
    // Set up VoiceService callbacks
    _voiceService.onMuteChanged = _handleMuteChanged;
    _voiceService.onSpeakingChanged = _handleSpeakingChanged;
    _voiceService.onParticipantJoined = _handleParticipantJoined;
    _voiceService.onParticipantLeft = _handleParticipantLeft;
    _voiceService.onError = _handleVoiceError;

    // Initialize with empty state
    state = AsyncValue.data(VoiceRoomState(
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

  void _handleParticipantJoined(String uid) {
    state.whenData((currentState) async {
      final displayName = await _getDisplayNameForUid(uid);
      final participant = VoiceParticipant(
        uid: uid,
        displayName: displayName,
        lastSeen: DateTime.now(),
      );

      final updatedParticipants = [...currentState.participants, participant];
      state = AsyncValue.data(
          currentState.copyWith(participants: updatedParticipants));

      // Sync to Firestore
      await _syncParticipantState(uid);
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

  void _handleVoiceError(VoiceServiceError error, String message) {
    state = AsyncValue.error(message, StackTrace.current);
    _appFlowManager?.trackError(
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      errorType: error.toString(),
      errorMessage: message,
    );
  }

  Future<String> _getDisplayNameForUid(String uid) async {
    // For now, return 'Unknown' - can be enhanced later with user data lookup
    return 'Unknown';
  }

  Future<void> initializeVoiceService() async {
    state = const AsyncValue.loading();

    try {
      final result = await _voiceService.initializeEngine();
      if (result.isSuccess) {
        await _initializeRoomSync();
        state = AsyncValue.data(VoiceRoomState(
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
    // Set up Firestore room sync
    _roomSyncSubscription =
        _firestoreService?.getVoiceRoomStream(roomId).listen(
      (roomData) {
        if (roomData != null) {
          _handleRoomSyncUpdate(roomData);
        }
      },
      onError: (error) {
        debugPrint('Room sync error: $error');
      },
    );
  }

  void _handleRoomSyncUpdate(Map<String, dynamic> roomData) {
    state.whenData((currentState) {
      final participants = (roomData['participants'] as List<dynamic>?)
              ?.map((p) => VoiceParticipant.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [];

      final isHost =
          roomData['hostUid'] == FirebaseAuth.instance.currentUser?.uid;

      state = AsyncValue.data(currentState.copyWith(
        participants: participants,
        isHost: isHost,
      ));
    });
  }

  Future<void> joinRoom() async {
    state = const AsyncValue.loading();

    try {
      final result = await _voiceService.joinChannel(roomId);
      if (result.isSuccess) {
        _joinTime = DateTime.now();

        // Track analytics
        final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
        await _appFlowManager?.trackVoiceSession(
          userId: userId,
          roomId: roomId,
          duration: Duration.zero,
        );

        state.whenData((currentState) {
          state = AsyncValue.data(currentState.copyWith(isJoined: true));
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
      final result = await _voiceService.leaveChannel();
      if (result.isSuccess) {
        // Track session duration
        if (_joinTime != null) {
          final duration = DateTime.now().difference(_joinTime!);
          final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
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
      final result =
          await _voiceService.toggleMute(state.value?.isMuted ?? false);
      if (result.isSuccess) {
        state.whenData((currentState) {
          state = AsyncValue.data(
              currentState.copyWith(isMuted: !currentState.isMuted));
        });
      } else {
        state = AsyncValue.error(result.errorMessage!, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> kickParticipant(String uid) async {
    state.whenData((currentState) async {
      if (!currentState.isHost) {
        state = AsyncValue.error(
            'Only host can kick participants', StackTrace.current);
        return;
      }

      try {
        // Remove from local state
        final updatedParticipants =
            currentState.participants.where((p) => p.uid != uid).toList();
        state = AsyncValue.data(
            currentState.copyWith(participants: updatedParticipants));

        // Sync to Firestore
        await _syncRoomState();
      } catch (e, stack) {
        state = AsyncValue.error(e, stack);
      }
    });
  }

  Future<void> muteParticipant(String uid, bool muted) async {
    state.whenData((currentState) async {
      if (!currentState.isHost) {
        state = AsyncValue.error(
            'Only host can mute participants', StackTrace.current);
        return;
      }

      try {
        // Update local state
        final updatedParticipants =
            currentState.participants.map((participant) {
          if (participant.uid == uid) {
            return participant.copyWith(isMuted: muted);
          }
          return participant;
        }).toList();

        state = AsyncValue.data(
            currentState.copyWith(participants: updatedParticipants));

        // Sync participant state
        await _syncParticipantState(uid);
      } catch (e, stack) {
        state = AsyncValue.error(e, stack);
      }
    });
  }

  Future<void> _syncRoomState() async {
    if (_firestoreService == null) return;

    state.whenData((currentState) async {
      final roomData = {
        'roomId': currentState.roomId,
        'roomName': currentState.roomName,
        'participants':
            currentState.participants.map((p) => p.toMap()).toList(),
        'hostUid': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestoreService.updateVoiceRoom(currentState.roomId, roomData);
    });
  }

  Future<void> _syncParticipantState(String uid) async {
    if (_firestoreService == null) return;

    state.whenData((currentState) async {
      final participant = currentState.participants.firstWhere(
        (p) => p.uid == uid,
        orElse: () => VoiceParticipant(uid: uid, displayName: 'Unknown'),
      );

      await _firestoreService.updateVoiceParticipant(
          currentState.roomId, uid, participant.toMap());
    });
  }

  @override
  void dispose() {
    _roomSyncSubscription?.cancel();
    _voiceService.dispose();
    super.dispose();
  }
}
