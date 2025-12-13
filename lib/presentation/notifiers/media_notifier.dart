import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod/riverpod.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/core/injection.dart';
import 'package:squad_sync/services/clip_service.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service_supabase.dart';


/// State for MediaNotifier - handles media, polls, and clips
class MediaState {
  final List<Map<String, dynamic>> mediaHistory;
  final Map<String, Map<String, Poll>>
      activePolls; // chatGroupId -> pollId -> poll
  final bool isUploading;
  final double uploadProgress;
  final String? uploadError;

  MediaState({
    required this.mediaHistory,
    required this.activePolls,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.uploadError,
  });

  factory MediaState.initial() => MediaState(
        mediaHistory: [],
        activePolls: {},
      );

  MediaState copyWith({
    List<Map<String, dynamic>>? mediaHistory,
    Map<String, Map<String, Poll>>? activePolls,
    bool? isUploading,
    double? uploadProgress,
    String? uploadError,
  }) {
    return MediaState(
      mediaHistory: mediaHistory ?? this.mediaHistory,
      activePolls: activePolls ?? this.activePolls,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadError: uploadError ?? this.uploadError,
    );
  }
}

/// MediaNotifier - Handles media operations:
/// - File uploads (images, videos, voice notes)
/// - Poll creation and voting
/// - Clip processing and hype reactions
/// - Media history tracking
class MediaNotifier extends AutoDisposeAsyncNotifier<MediaState> {
  late final ChatRepository _repository;
  late final ClipService _clipService;
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  @override
  Future<MediaState> build() async {
    try {
      _repository = ref.read(chatRepositoryProvider);
      _clipService = ClipService();
      return MediaState.initial();
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================================
  // MEDIA UPLOADS
  // ============================================================================

  /// Upload media file (image, video, audio)
  Future<String> uploadMedia(String filePath, String mediaType) async {
    try {
      state = await AsyncValue.guard(() async {
        final currentState = await future;
        return currentState.copyWith(isUploading: true, uploadProgress: 0.0);
      });

      final mediaUrl = await _repository.uploadMedia(filePath, mediaType);

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        return currentState.copyWith(
          isUploading: false,
          uploadProgress: 1.0,
          uploadError: null,
        );
      });

      return mediaUrl;
    } catch (e) {
      debugPrint('MediaNotifier: Upload failed: $e');
      state = await AsyncValue.guard(() async {
        final currentState = await future;
        return currentState.copyWith(
          isUploading: false,
          uploadError: e.toString(),
        );
      });
      rethrow;
    }
  }

  /// Update upload progress
  void updateUploadProgress(double progress) {
    state.whenData((currentState) {
      state = AsyncValue.data(
        currentState.copyWith(uploadProgress: progress),
      );
    });
  }

  /// Load media history for a chat group
  Future<void> loadMediaHistory(String chatGroupId) async {
    try {
      final history = await _repository.getMediaHistory(chatGroupId);

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        return currentState.copyWith(mediaHistory: history);
      });
    } catch (e) {
      debugPrint('MediaNotifier: Failed to load media history: $e');
      rethrow;
    }
  }

  /// Delete media
  Future<void> deleteMedia(String mediaUrl) async {
    try {
      await _repository.deleteMedia(mediaUrl);
    } catch (e) {
      debugPrint('MediaNotifier: Failed to delete media: $e');
      rethrow;
    }
  }

  // ============================================================================
  // POLLS
  // ============================================================================

  /// Create a new poll
  Future<void> createPoll(
      String chatGroupId, String question, List<String> options) async {
    try {
      final poll = await _repository.createPoll(chatGroupId, question, options);

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        final updatedPolls =
            Map<String, Map<String, Poll>>.from(currentState.activePolls);
        final groupPolls =
            Map<String, Poll>.from(updatedPolls[chatGroupId] ?? {});
        groupPolls[poll.id] = poll;
        updatedPolls[chatGroupId] = groupPolls;
        return currentState.copyWith(activePolls: updatedPolls);
      });
    } catch (e) {
      debugPrint('MediaNotifier: Failed to create poll: $e');
      rethrow;
    }
  }

  /// Vote on a poll
  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    try {
      await _repository.votePoll(chatGroupId, pollId, option, voterId);

      // Reload active polls to get updated vote counts
      await loadActivePolls(chatGroupId);
    } catch (e) {
      debugPrint('MediaNotifier: Failed to vote on poll: $e');
      rethrow;
    }
  }

  /// Close a poll
  Future<void> closePoll(String chatGroupId, String pollId) async {
    try {
      await _repository.closePoll(chatGroupId, pollId);

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        final updatedPolls =
            Map<String, Map<String, Poll>>.from(currentState.activePolls);
        final groupPolls =
            Map<String, Poll>.from(updatedPolls[chatGroupId] ?? {});
        groupPolls.remove(pollId);
        updatedPolls[chatGroupId] = groupPolls;
        return currentState.copyWith(activePolls: updatedPolls);
      });
    } catch (e) {
      debugPrint('MediaNotifier: Failed to close poll: $e');
      rethrow;
    }
  }

  /// Load active polls for a chat group
  Future<void> loadActivePolls(String chatGroupId) async {
    try {
      final polls = await _repository.getActivePolls(chatGroupId);

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        final updatedPolls =
            Map<String, Map<String, Poll>>.from(currentState.activePolls);
        updatedPolls[chatGroupId] = polls;
        return currentState.copyWith(activePolls: updatedPolls);
      });
    } catch (e) {
      debugPrint('MediaNotifier: Failed to load active polls: $e');
      rethrow;
    }
  }

  // ============================================================================
  // CLIPS
  // ============================================================================

  /// Process and upload a clip
  Future<Map<String, dynamic>> processClip(
    String clipFilePath, {
    Function(double)? onProgress,
  }) async {
    try {
      state = await AsyncValue.guard(() async {
        final currentState = await future;
        return currentState.copyWith(isUploading: true, uploadProgress: 0.0);
      });

      debugPrint('MediaNotifier: Processing clip from: $clipFilePath');

      final processedClip = await _clipService.processClip(
        clipFilePath,
        onProgress: (progress) {
          debugPrint(
              'Clip upload progress: ${(progress * 100).toStringAsFixed(0)}%');
          updateUploadProgress(progress);
          onProgress?.call(progress);
        },
      );

      final clipData = {
        'clipId': processedClip.clipId,
        'videoUrl': processedClip.videoUrl,
        'thumbnailUrl': processedClip.thumbUrl,
        'durationSec': (processedClip.duration / 1000).round(),
        'width': processedClip.width,
        'height': processedClip.height,
        'views': 0,
        'hypeReactions': <String>[],
      };

      state = await AsyncValue.guard(() async {
        final currentState = await future;
        return currentState.copyWith(
          isUploading: false,
          uploadProgress: 1.0,
          uploadError: null,
        );
      });

      return clipData;
    } catch (e) {
      debugPrint('MediaNotifier: Failed to process clip: $e');
      state = await AsyncValue.guard(() async {
        final currentState = await future;
        return currentState.copyWith(
          isUploading: false,
          uploadError: e.toString(),
        );
      });
      rethrow;
    }
  }

  /// Increment view count for a clip message
  Future<void> incrementClipViews(
      String chatGroupId, String messageId, ChatType chatType) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final clipData = await SupabaseService.client
          .from('chat_messages')
          .select('clip_data')
          .eq('id', messageId)
          .maybeSingle();

      if (clipData != null) {
        final currentViews = (clipData['clip_data']?['views'] as int?) ?? 0;
        await SupabaseService.client.from('chat_messages').update({
          'clip_data': {
            ...Map<String, dynamic>.from(clipData['clip_data'] ?? {}),
            'views': currentViews + 1,
          }
        }).eq('id', messageId);
      }

      debugPrint('MediaNotifier: Incremented views for clip $messageId');
    } catch (e) {
      debugPrint('MediaNotifier: Failed to increment clip views: $e');
      // Non-critical, don't rethrow
    }
  }

  /// Toggle hype reaction on a clip
  Future<void> toggleClipHype(
      String chatGroupId, String messageId, ChatType chatType) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      final messageData = await SupabaseService.client
          .from('chat_messages')
          .select('clip_data')
          .eq('id', messageId)
          .maybeSingle();

      if (messageData != null) {
        final clipData = messageData['clip_data'] as Map<String, dynamic>?;

        if (clipData != null) {
          final hypeReactions =
              List<String>.from(clipData['hype_reactions'] ?? []);

          if (hypeReactions.contains(currentUser.id)) {
            hypeReactions.remove(currentUser.id);
          } else {
            hypeReactions.add(currentUser.id);
          }

          await SupabaseService.client.from('chat_messages').update({
            'clip_data': {
              ...clipData,
              'hype_reactions': hypeReactions,
            }
          }).eq('id', messageId);

          debugPrint('MediaNotifier: Toggled hype for clip $messageId');
        }
      }
    } catch (e) {
      debugPrint('MediaNotifier: Failed to toggle clip hype: $e');
      // Non-critical, don't rethrow
    }
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  List<Map<String, dynamic>> getMediaHistory() {
    return state.maybeWhen(
      data: (data) => data.mediaHistory,
      orElse: () => [],
    );
  }

  Map<String, Poll> getActivePolls(String chatGroupId) {
    return state.maybeWhen(
      data: (data) => data.activePolls[chatGroupId] ?? {},
      orElse: () => {},
    );
  }

  bool get isUploading {
    return state.maybeWhen(
      data: (data) => data.isUploading,
      orElse: () => false,
    );
  }

  double get uploadProgress {
    return state.maybeWhen(
      data: (data) => data.uploadProgress,
      orElse: () => 0.0,
    );
  }
}

// Backward compatibility alias
final mediaNotifierProvider =
    AutoDisposeAsyncNotifierProvider<MediaNotifier, MediaState>.new(
  MediaNotifier.new,
);
