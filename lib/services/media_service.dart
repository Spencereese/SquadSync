import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';

/// Service responsible for media upload operations including images, videos, and audio.
/// Handles Firebase Storage uploads with progress tracking and error handling.
class MediaService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload media (image/video) to Firebase Storage with progress tracking
  MediaUploadTask uploadMediaWithProgress(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
    Function(String url)? onComplete,
    Function(String error)? onError,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError?.call('User must be authenticated to upload media');
      throw Exception('User must be authenticated to upload media');
    }

    final taskId = 'media_${DateTime.now().millisecondsSinceEpoch}';
    Reference ref = _storage.ref().child('chat_media/$fileName');

    final uploadTask = ref.putFile(file);
    return MediaUploadTask(
      taskId,
      uploadTask,
      onProgress: onProgress,
      onComplete: (url) {
        HapticFeedback.lightImpact();
        onComplete?.call(url);
      },
      onError: onError,
    );
  }

  /// Legacy method for backward compatibility - upload media without progress tracking
  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    final completer = Completer<String>();
    String? error;

    uploadMediaWithProgress(
      file,
      fileName,
      onComplete: (url) => completer.complete(url),
      onError: (err) {
        error = err;
        completer.completeError(Exception(err));
      },
    );

    try {
      return await completer.future;
    } catch (e) {
      throw Exception(error ?? 'Failed to upload media: $e');
    }
  }

  /// Upload audio to Firebase Storage with progress tracking
  MediaUploadTask uploadAudioWithProgress(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
    Function(String url)? onComplete,
    Function(String error)? onError,
  }) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError?.call('User must be authenticated to upload audio');
      throw Exception('User must be authenticated to upload audio');
    }

    final taskId = 'audio_${DateTime.now().millisecondsSinceEpoch}';
    Reference ref = _storage.ref().child('chat_audio/$fileName');

    final uploadTask = ref.putFile(file);
    return MediaUploadTask(
      taskId,
      uploadTask,
      onProgress: onProgress,
      onComplete: (url) {
        HapticFeedback.lightImpact();
        onComplete?.call(url);
      },
      onError: onError,
    );
  }

  /// Legacy method for backward compatibility - upload audio without progress tracking
  Future<String> uploadAudio(File file, String fileName) async {
    final completer = Completer<String>();
    String? error;

    uploadAudioWithProgress(
      file,
      fileName,
      onComplete: (url) => completer.complete(url),
      onError: (err) {
        error = err;
        completer.completeError(Exception(err));
      },
    );

    try {
      return await completer.future;
    } catch (e) {
      throw Exception(error ?? 'Failed to upload audio: $e');
    }
  }
}

/// Represents a cancellable media upload task
class MediaUploadTask {
  final String taskId;
  final UploadTask _uploadTask;
  final Function(double progress)? onProgress;
  final Function(String url)? onComplete;
  final Function(String error)? onError;

  bool _isCancelled = false;

  MediaUploadTask(
    this.taskId,
    this._uploadTask, {
    this.onProgress,
    this.onComplete,
    this.onError,
  }) {
    // Listen to upload progress
    _uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      if (_isCancelled) return;

      final progress = snapshot.bytesTransferred / snapshot.totalBytes;
      onProgress?.call(progress);

      if (snapshot.state == TaskState.success) {
        snapshot.ref.getDownloadURL().then((url) {
          if (!_isCancelled) {
            onComplete?.call(url);
          }
        }).catchError((error) {
          if (!_isCancelled) {
            onError?.call('Failed to get download URL: $error');
          }
        });
      } else if (snapshot.state == TaskState.error) {
        if (!_isCancelled) {
          onError?.call('Upload failed: ${snapshot.state}');
        }
      }
    });
  }

  void cancel() {
    _isCancelled = true;
    _uploadTask.cancel();
  }

  bool get isCancelled => _isCancelled;
}
