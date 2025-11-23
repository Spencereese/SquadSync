import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

/// Service responsible for media upload operations including images, videos, and audio.
/// Handles Firebase Storage uploads with progress tracking and signed URL generation.
class MediaService {
  final Logger _logger = Logger();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _backendUrl =
      'http://localhost:8080'; // Update with your backend URL

  /// Upload media (image/video) to Firebase Storage and get signed URL
  Future<String> uploadMediaWithSignedUrl(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
    Function(String error)? onError,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError?.call('User must be authenticated to upload media');
      throw Exception('User must be authenticated to upload media');
    }

    try {
      // First upload to Firebase Storage
      final uploadTask =
          _storage.ref().child('chat_media/$fileName').putFile(file);

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Get signed URL from backend
      final signedUrl = await _getSignedUrl(fileName);
      return signedUrl ??
          downloadUrl; // Fallback to direct URL if signed URL fails
    } catch (e) {
      onError?.call('Upload failed: $e');
      throw Exception('Failed to upload media: $e');
    }
  }

  /// Get signed URL for media file from backend
  Future<String?> _getSignedUrl(String fileName) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/generate-signed-url'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fileName': fileName}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['signedUrl'];
      }
      return null;
    } catch (e) {
      _logger.e('Failed to get signed URL: $e');
      return null;
    }
  }

  /// Legacy method for backward compatibility - upload media without progress tracking
  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    return uploadMediaWithSignedUrl(file, fileName);
  }

  /// Upload audio to Firebase Storage and get signed URL
  Future<String> uploadAudioWithSignedUrl(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
    Function(String error)? onError,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      onError?.call('User must be authenticated to upload audio');
      throw Exception('User must be authenticated to upload audio');
    }

    try {
      // First upload to Firebase Storage
      final uploadTask =
          _storage.ref().child('chat_audio/$fileName').putFile(file);

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Get signed URL from backend
      final signedUrl = await _getSignedUrl(fileName);
      return signedUrl ??
          downloadUrl; // Fallback to direct URL if signed URL fails
    } catch (e) {
      onError?.call('Audio upload failed: $e');
      throw Exception('Failed to upload audio: $e');
    }
  }

  /// Legacy method for backward compatibility - upload audio without progress tracking
  Future<String> uploadAudio(File file, String fileName) async {
    return uploadAudioWithSignedUrl(file, fileName);
  }
}
