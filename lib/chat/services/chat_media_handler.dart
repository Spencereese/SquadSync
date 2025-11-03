import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart' as record_package;
import '../../squad_state.dart';
import '../../services/ai_service.dart';
import '../chat_service.dart';
import '../chat_state.dart';

/// Service responsible for handling media operations in chat including
/// image picking, audio recording, and media uploading
class ChatMediaHandler {
  final ImagePicker _picker = ImagePicker();
  final record_package.AudioRecorder _audioRecorder =
      record_package.AudioRecorder();
  final ChatService _chatService = ChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _audioPath;

  /// Dispose of resources
  void dispose() {
    _audioRecorder.dispose();
  }

  /// Pick and send media (image or video) from gallery/camera
  Future<void> sendMedia(
    BuildContext context, {
    required String? chatGroupId,
    required ChatType chatType,
  }) async {
    final chatState = Provider.of<ChatState>(context, listen: false);
    try {
      final XFile? media = await _picker.pickMedia();
      if (media == null) return;

      chatState.setUploading(true);
      File file = File(media.path);
      bool isVideo = media.mimeType?.startsWith('video/') ?? false;
      final user = _auth.currentUser;
      if (user == null) return;

      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.${isVideo ? 'mp4' : 'jpg'}';
      String downloadUrl =
          await _chatService.uploadMedia(file, fileName, isVideo);
      final timestampMs = DateTime.now().millisecondsSinceEpoch;

      await _chatService.sendMessage(
        context,
        senderUid: user.uid,
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

      chatState.setUploading(false);
      HapticFeedback.lightImpact();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Media upload failed: $e')));
      chatState.setUploading(false);
    }
  }

  /// Start audio recording
  Future<void> startRecording(BuildContext context) async {
    final chatState = Provider.of<ChatState>(context, listen: false);

    if (await _audioRecorder.hasPermission()) {
      try {
        final directory = Directory.systemTemp;
        final path =
            '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const record_package.RecordConfig(),
            path: path);
        chatState.setRecording(true);
        HapticFeedback.mediumImpact();
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Recording failed: $e')));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission Denied')));
    }
  }

  /// Stop audio recording and upload
  Future<void> stopRecording(
    BuildContext context, {
    required String? chatGroupId,
    required ChatType chatType,
  }) async {
    final chatState = Provider.of<ChatState>(context, listen: false);

    try {
      String? path = await _audioRecorder.stop();
      chatState.setRecording(false);

      if (path != null) {
        _audioPath = path;
        await _uploadAudio(context,
            chatGroupId: chatGroupId, chatType: chatType);
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')));
    }
  }

  /// Upload recorded audio file
  Future<void> _uploadAudio(
    BuildContext context, {
    required String? chatGroupId,
    required ChatType chatType,
  }) async {
    final chatState = Provider.of<ChatState>(context, listen: false);

    if (_audioPath == null) return;
    chatState.setUploading(true);

    try {
      File file = File(_audioPath!);
      final user = _auth.currentUser;
      if (user == null) return;

      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.m4a';
      String downloadUrl = await _chatService.uploadAudio(file, fileName);
      final timestampMs = DateTime.now().millisecondsSinceEpoch;

      await _chatService.sendMessage(
        context,
        senderUid: user.uid,
        text: '',
        audio: [
          {'uri': downloadUrl, 'creation_timestamp': timestampMs}
        ],
        chatGroupId: chatGroupId,
        chatType: chatType,
      );

      chatState.setUploading(false);
      _audioPath = null;
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Audio upload failed: $e')));
      chatState.setUploading(false);
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
    required SquadState squadState,
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

      // Determine where to save the image URL based on chat type
      final squadId = squadState.selectedSquadId;
      if (squadId == null) return;

      if (chatGroupId != null) {
        // Update group chat image
        await FirebaseFirestore.instance
            .collection('squads')
            .doc(squadId)
            .collection('chat_groups')
            .doc(chatGroupId)
            .set({
          'imageUrl': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        // Update squad chat image
        await FirebaseFirestore.instance
            .collection('chat_metadata')
            .doc('chat_config')
            .set({
          'imageUrl': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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
