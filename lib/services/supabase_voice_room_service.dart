import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service_supabase.dart';
import 'supabase_service.dart';

/// Supabase Realtime service for voice room state management
///
/// Uses Supabase Realtime channels for:
/// - Presence tracking (who's in the room)
/// - Broadcast (mute/speaking state updates)
/// - Real-time participant sync
///
/// Replaces Firebase Firestore for voice room state
class SupabaseVoiceRoomService {
  final String roomId;
  RealtimeChannel? _channel;
  StreamController<List<VoiceRoomParticipant>>? _participantsController;
  final Map<String, VoiceRoomParticipant> _participants = {};

  SupabaseVoiceRoomService({required this.roomId});

  /// Join voice room and start tracking presence
  Future<void> joinRoom({
    required String displayName,
    bool isHost = false,
  }) async {
    final authService = AuthServiceSupabase();
    final currentUser = authService.currentUserId;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    _participantsController =
        StreamController<List<VoiceRoomParticipant>>.broadcast();

    // Create channel for this voice room
    _channel = supabase.channel('voice_room:$roomId');

    // Track presence changes
    _channel!.onPresenceSync((payload) {
      final presenceState = _channel!.presenceState();
      _updateParticipantsFromPresence(presenceState);
    }).onPresenceJoin((payload) {
      debugPrint('👤 User joined voice room: ${payload.newPresences}');
      _updateParticipantsFromPresence(_channel!.presenceState());
    }).onPresenceLeave((payload) {
      debugPrint('👋 User left voice room: ${payload.leftPresences}');
      _updateParticipantsFromPresence(_channel!.presenceState());
    });

    // Listen for broadcast events (mute/speaking state)
    _channel!
        .onBroadcast(
          event: 'mute_changed',
          callback: (payload) {
            final uid = payload['uid'] as String?;
            final isMuted = payload['isMuted'] as bool?;
            if (uid != null && isMuted != null) {
              _updateParticipantMuteState(uid, isMuted);
            }
          },
        )
        .onBroadcast(
          event: 'speaking_changed',
          callback: (payload) {
            final uid = payload['uid'] as String?;
            final isSpeaking = payload['isSpeaking'] as bool?;
            if (uid != null && isSpeaking != null) {
              _updateParticipantSpeakingState(uid, isSpeaking);
            }
          },
        );

    // Subscribe and track presence
    await _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('✅ Subscribed to voice room: $roomId');
        // Track our presence
        _channel!.track({
          'uid': currentUser,
          'displayName': displayName,
          'isHost': isHost,
          'isMuted': false,
          'isSpeaking': false,
          'joinedAt': DateTime.now().toIso8601String(),
        });
      } else if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('❌ Voice room subscription error: $error');
      }
    });
  }

  /// Leave voice room and cleanup
  Future<void> leaveRoom() async {
    final authService = AuthServiceSupabase();
    final currentUser = authService.currentUserId;
    if (currentUser != null && _channel != null) {
      await _channel!.untrack();
    }

    await _channel?.unsubscribe();
    await _participantsController?.close();
    _participants.clear();
    _channel = null;
    _participantsController = null;
  }

  /// Update local user's mute state and broadcast to others
  Future<void> updateMuteState(bool isMuted) async {
    final authService = AuthServiceSupabase();
    final currentUser = authService.currentUserId;
    if (currentUser == null || _channel == null) return;

    // Update presence
    await _channel!.track({
      'isMuted': isMuted,
    });

    // Broadcast to all participants
    await _channel!.sendBroadcastMessage(
      event: 'mute_changed',
      payload: {
        'uid': currentUser,
        'isMuted': isMuted,
      },
    );
  }

  /// Update local user's speaking state and broadcast to others
  Future<void> updateSpeakingState(bool isSpeaking) async {
    final authService = AuthServiceSupabase();
    final currentUser = authService.currentUserId;
    if (currentUser == null || _channel == null) return;

    // Update presence
    await _channel!.track({
      'isSpeaking': isSpeaking,
    });

    // Broadcast to all participants
    await _channel!.sendBroadcastMessage(
      event: 'speaking_changed',
      payload: {
        'uid': currentUser,
        'isSpeaking': isSpeaking,
      },
    );
  }

  /// Stream of all participants in the room
  Stream<List<VoiceRoomParticipant>> streamParticipants() {
    if (_participantsController == null) {
      throw Exception('Must call joinRoom() before streaming participants');
    }
    return _participantsController!.stream;
  }

  /// Get current participants list (synchronous)
  List<VoiceRoomParticipant> get currentParticipants {
    return _participants.values.toList();
  }

  /// Update participants from presence state
  void _updateParticipantsFromPresence(
      List<SinglePresenceState> presenceState) {
    final newParticipants = <String, VoiceRoomParticipant>{};

    for (final state in presenceState) {
      // Each SinglePresenceState has presences list
      for (final presence in state.presences) {
        final payload = presence.payload;
        final uid = payload['uid'] as String?;
        if (uid != null) {
          newParticipants[uid] = VoiceRoomParticipant(
            uid: uid,
            displayName: payload['displayName'] as String? ?? 'Unknown',
            isHost: payload['isHost'] as bool? ?? false,
            isMuted: payload['isMuted'] as bool? ?? false,
            isSpeaking: payload['isSpeaking'] as bool? ?? false,
            isOnline: true,
            lastSeen: DateTime.now(),
          );
        }
      }
    }

    _participants.clear();
    _participants.addAll(newParticipants);
    _participantsController?.add(currentParticipants);
  }

  /// Update specific participant's mute state
  void _updateParticipantMuteState(String uid, bool isMuted) {
    final participant = _participants[uid];
    if (participant != null) {
      _participants[uid] = participant.copyWith(isMuted: isMuted);
      _participantsController?.add(currentParticipants);
    }
  }

  /// Update specific participant's speaking state
  void _updateParticipantSpeakingState(String uid, bool isSpeaking) {
    final participant = _participants[uid];
    if (participant != null) {
      _participants[uid] = participant.copyWith(isSpeaking: isSpeaking);
      _participantsController?.add(currentParticipants);
    }
  }

  /// Dispose resources
  void dispose() {
    leaveRoom();
  }
}

/// Voice room participant model
class VoiceRoomParticipant {
  final String uid;
  final String displayName;
  final bool isMuted;
  final bool isSpeaking;
  final bool isHost;
  final bool isOnline;
  final DateTime? lastSeen;

  VoiceRoomParticipant({
    required this.uid,
    required this.displayName,
    this.isMuted = false,
    this.isSpeaking = false,
    this.isHost = false,
    this.isOnline = true,
    this.lastSeen,
  });

  VoiceRoomParticipant copyWith({
    String? uid,
    String? displayName,
    bool? isMuted,
    bool? isSpeaking,
    bool? isHost,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return VoiceRoomParticipant(
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
}
