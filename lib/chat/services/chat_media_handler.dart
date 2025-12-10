import 'dart:io';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import '../../services/message_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart' as record_package;
import '../../domain/entities/lobby_state.dart';
import '../../domain/entities/message.dart';
import '../chat_state_notifier.dart';
import '../../services/media_service.dart';

/// Service responsible for handling media operations in chat including
/// image picking, audio recording, and media uploading
class ChatMediaHandler {
  final ImagePicker _picker = ImagePicker();
  final record_package.AudioRecorder _audioRecorder =
      record_package.AudioRecorder();
  final MessageService _chatService = MessageService();
  final AuthServiceSupabase _authService = AuthServiceSupabase();

  String? _audioPath;

  /// Dispose of resources
  void dispose() {
    _audioRecorder.dispose();
  }

  /// Pick and send media (image or video) from gallery/camera
  Future<void> sendMedia(
    WidgetRef ref, {
    required String? chatGroupId,
    required ChatType chatType,
  }) async {
    try {
      final XFile? media = await _picker.pickMedia();
      if (media == null) return;

      ref.read(chatStateProvider.notifier).setUploading(true);
      File file = File(media.path);
      bool isVideo = media.mimeType?.startsWith('video/') ?? false;
      final user = _authService.currentUser;
      if (user == null) return;

      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${user.id}.${isVideo ? 'mp4' : 'jpg'}';

      // Use new media service with signed URLs
      final mediaService = MediaService();
      String downloadUrl =
          await mediaService.uploadMediaWithSignedUrl(file, fileName);

      final timestampMs = DateTime.now().millisecondsSinceEpoch;

      await _chatService.sendMessage(
        ref,
        senderUid: user.id,
        text: '',
        photos: !isVideo
            ? [
                {'uri': downloadUrl, 'creation_timestamp': timestampMs}
              ]
            : [],
        videos: isVideo
            ? [
                {'uri': downloadUrl, 'creation_timestamp': timestampMs}
              ]
            : [],
        chatGroupId: chatGroupId,
        chatType: chatType,
      );

      ref.read(chatStateProvider.notifier).setUploading(false);
      HapticFeedback.lightImpact();
    } catch (e) {
      ScaffoldMessenger.of(ref.context)
          .showSnackBar(SnackBar(content: Text('Media upload failed: $e')));
      ref.read(chatStateProvider.notifier).setUploading(false);
    }
  }

  /// Start audio recording
  Future<void> startRecording(WidgetRef ref) async {
    if (await _audioRecorder.hasPermission()) {
      try {
        final directory = Directory.systemTemp;
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }
        final path =
            '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const record_package.RecordConfig(),
            path: path);
        ref.read(chatStateProvider.notifier).setRecording(true);
        HapticFeedback.mediumImpact();
      } catch (e) {
        debugPrint('Recording start failed: $e');
        if (ref.context.mounted) {
          ScaffoldMessenger.of(ref.context)
              .showSnackBar(SnackBar(content: Text('Recording failed: $e')));
        }
      }
    } else {
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
            const SnackBar(content: Text('Microphone permission Denied')));
      }
    }
  }

  /// Stop audio recording and upload
  Future<void> stopRecording(
    WidgetRef ref, {
    required String? chatGroupId,
    required ChatType chatType,
  }) async {
    try {
      String? path = await _audioRecorder.stop();
      ref.read(chatStateProvider.notifier).setRecording(false);

      if (path != null) {
        _audioPath = path;
        await _uploadAudio(ref, chatGroupId: chatGroupId, chatType: chatType);
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Recording stop failed: $e');
      ref.read(chatStateProvider.notifier).setRecording(false);
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
            SnackBar(content: Text('Failed to stop recording: $e')));
      }
    }
  }

  /// Upload recorded audio file
  Future<void> _uploadAudio(
    WidgetRef ref, {
    required String? chatGroupId,
    required ChatType chatType,
  }) async {
    if (_audioPath == null) return;
    ref.read(chatStateProvider.notifier).setUploading(true);

    try {
      File file = File(_audioPath!);
      final user = _authService.currentUser;
      if (user == null) return;

      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${user.id}.m4a';
      String downloadUrl = await _chatService.uploadAudio(file, fileName);
      final timestampMs = DateTime.now().millisecondsSinceEpoch;

      await _chatService.sendMessage(
        ref,
        senderUid: user.id,
        text: '',
        audio: [
          {'uri': downloadUrl, 'creation_timestamp': timestampMs}
        ],
        chatGroupId: chatGroupId,
        chatType: chatType,
      );

      ref.read(chatStateProvider.notifier).setUploading(false);
      _audioPath = null;
    } catch (e) {
      ScaffoldMessenger.of(ref.context)
          .showSnackBar(SnackBar(content: Text('Audio upload failed: $e')));
      ref.read(chatStateProvider.notifier).setUploading(false);
    }
  }

  /// Pick chat image from gallery
  Future<String?> pickChatImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        return image.path;
      }
    } catch (e) {
      debugPrint('Error picking chat image: $e');
    }
    return null;
  }

  /// Pick and upload chat image (for chat settings)
  Future<void> changeChatImage(
    BuildContext context, {
    required String? chatGroupId,
    LobbyState? squadState,
    required Function(String) onImageUpdated,
  }) async {
    final imagePath = await pickChatImage();
    if (imagePath == null) return;

    try {
      File file = File(imagePath);
      String fileName =
          'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String downloadUrl =
          await _chatService.uploadMedia(file, fileName, false);

      // Update user group chat image in Supabase
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null || chatGroupId == null) return;

      // Fetch current user_groups array
      final response = await SupabaseService.client
          .from('users')
          .select('user_groups')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (response != null) {
        final userGroups =
            List<Map<String, dynamic>>.from(response['user_groups'] ?? []);

        // Find and update the specific chat group
        final groupIndex = userGroups
            .indexWhere((group) => group['chat_group_id'] == chatGroupId);

        if (groupIndex != -1) {
          userGroups[groupIndex]['image_url'] = downloadUrl;
          userGroups[groupIndex]['timestamp'] =
              DateTime.now().toIso8601String();

          // Update the entire user_groups array
          await SupabaseService.client.from('users').update({
            'user_groups': userGroups,
          }).eq('id', currentUser.id);
        }
      }

      // Update local state and provide feedback
      onImageUpdated(downloadUrl);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update chat image: $e')));
      }
    }
  }
}
