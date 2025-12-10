import 'dart:async';
import 'dart:io';
import 'auth_service_supabase.dart';
// TODO: Migrate fully to Supabase Storage
// import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'supabase_service.dart';

/// Service responsible for media upload operations including images, videos, and audio.
///
/// **Supabase Storage Strategy:**
/// - Uploads to Supabase Storage
/// - Automatic bucket creation in Supabase
class MediaService {
  final Logger _logger = Logger();

  // TODO: Migrate fully to Supabase Storage buckets
  // static const String _chatMediaBucket = 'chat-media';
  // static const String _chatAudioBucket = 'chat-audio';
  // static const String _chatBackgroundsBucket = 'chat-backgrounds';
  // static const String _clipsBucket = 'clips';

  /// Upload media to Supabase Storage
  ///
  /// [filePath] - Local file path
  /// [storagePath] - Path in Supabase storage (e.g., 'chat_media/file.jpg')
  /// [bucket] - Bucket name (defaults to chat-media)
  Future<String?> uploadMediaSupabase(
    String filePath,
    String storagePath, {
    String bucket = 'chat-media',
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.e('File not found: $filePath');
        return null;
      }

      // Ensure bucket exists
      await _ensureBucketExists(bucket);

      // Read file as bytes
      final bytes = await file.readAsBytes();

      // Upload to Supabase Storage
      await supabase.storage.from(bucket).uploadBinary(
            storagePath,
            bytes,
          );

      // Get public URL
      final publicUrl = supabase.storage.from(bucket).getPublicUrl(storagePath);

      _logger.i('Uploaded to Supabase: $publicUrl');
      return publicUrl;
    } catch (e) {
      _logger.e('Supabase upload failed: $e');
      return null;
    }
  }

  /// Get signed URL from Supabase Storage
  ///
  /// [path] - Storage path
  /// [bucket] - Bucket name
  /// [expiresIn] - URL expiration in seconds (default 1 hour)
  Future<String?> getSignedUrlSupabase(
    String path, {
    String bucket = 'chat-media',
    int expiresIn = 3600,
  }) async {
    try {
      final signedUrl =
          await supabase.storage.from(bucket).createSignedUrl(path, expiresIn);

      _logger.i('Generated signed URL from Supabase');
      return signedUrl;
    } catch (e) {
      _logger.e('Failed to get Supabase signed URL: $e');
      return null;
    }
  }

  /// Ensure Supabase bucket exists, create if missing
  Future<void> _ensureBucketExists(String bucketName) async {
    try {
      // Try to list files to check if bucket exists
      await supabase.storage.from(bucketName).list();
    } catch (e) {
      // Bucket doesn't exist, try to create it
      try {
        await supabase.storage.createBucket(bucketName);
        _logger.i('Created Supabase bucket: $bucketName');
      } catch (createError) {
        _logger.w('Failed to create bucket $bucketName: $createError');
        // Bucket might already exist or user lacks permissions
      }
    }
  }

  /// Get media URL with read priority: Supabase first → Firebase fallback
  ///
  /// [fileName] - File name/path
  /// [bucket] - Supabase bucket name
  /// [firebasePath] - Firebase Storage path
  Future<String> getMediaUrl(
    String fileName, {
    String bucket = 'chat-media',
    String? firebasePath,
  }) async {
    // Try Supabase first
    try {
      final supabaseUrl = supabase.storage.from(bucket).getPublicUrl(fileName);

      // Verify URL is accessible
      final response = await http.head(Uri.parse(supabaseUrl));
      if (response.statusCode == 200) {
        _logger.i('Using Supabase URL for $fileName');
        return supabaseUrl;
      }
    } catch (e) {
      _logger.w('Supabase URL failed, falling back to Firebase: $e');
    }

    // TODO: Implement Supabase Storage fallback
    throw Exception('Media URL not found in Supabase Storage: $fileName');
  }

  /// Upload media (image/video) to Supabase Storage
  /// Returns public URL on success
  Future<String> uploadMediaWithSignedUrl(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
    Function(String error)? onError,
  }) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      onError?.call('User must be authenticated to upload media');
      throw Exception('User must be authenticated to upload media');
    }

    try {
      final storagePath = 'chat_media/$fileName';
      final url = await uploadMediaSupabase(
        file.path,
        storagePath,
        bucket: 'chat-media',
      );

      if (url == null) {
        throw Exception('Failed to upload media to Supabase Storage');
      }

      _logger.i('Media uploaded successfully: $url');
      onProgress?.call(1.0); // Mark as complete
      return url;
    } catch (e) {
      _logger.e('Media upload failed: $e');
      onError?.call('Upload failed: $e');
      throw Exception('Failed to upload media: $e');
    }
  }

  /// Legacy method for backward compatibility - upload media without progress tracking
  Future<String> uploadMedia(File file, String fileName, bool isVideo) async {
    return uploadMediaWithSignedUrl(file, fileName);
  }

  /// Upload audio to Supabase Storage
  /// Returns public URL on success
  Future<String> uploadAudioWithSignedUrl(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
    Function(String error)? onError,
  }) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      onError?.call('User must be authenticated to upload audio');
      throw Exception('User must be authenticated to upload audio');
    }

    try {
      final storagePath = 'chat_audio/$fileName';
      final url = await uploadMediaSupabase(
        file.path,
        storagePath,
        bucket: 'chat-audio',
      );

      if (url == null) {
        throw Exception('Failed to upload audio to Supabase Storage');
      }

      _logger.i('Audio uploaded successfully: $url');
      onProgress?.call(1.0); // Mark as complete
      return url;
    } catch (e) {
      _logger.e('Audio upload failed: $e');
      onError?.call('Upload failed: $e');
      throw Exception('Failed to upload audio: $e');
    }
  }

  /// Legacy method for backward compatibility - upload audio without progress tracking
  Future<String> uploadAudio(File file, String fileName) async {
    return uploadAudioWithSignedUrl(file, fileName);
  }

  /// Upload background image to Supabase Storage
  /// Returns public URL on success
  Future<String> uploadBackground(
    String filePath,
    String fileName,
  ) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to upload backgrounds');
    }

    try {
      final storagePath = 'chat_backgrounds/$fileName';
      final url = await uploadMediaSupabase(
        filePath,
        storagePath,
        bucket: 'chat-backgrounds',
      );

      if (url == null) {
        throw Exception('Failed to upload background to Supabase Storage');
      }

      _logger.i('Background uploaded successfully: $url');
      return url;
    } catch (e) {
      _logger.e('Background upload failed: $e');
      throw Exception('Failed to upload background: $e');
    }
  }

  /// Upload clip to Supabase Storage
  /// Returns public URL on success
  Future<String> uploadClip(
    File file,
    String fileName, {
    Function(double progress)? onProgress,
  }) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to upload clips');
    }

    try {
      final storagePath = 'clips/$fileName';
      final url = await uploadMediaSupabase(
        file.path,
        storagePath,
        bucket: 'clips',
      );

      if (url == null) {
        throw Exception('Failed to upload clip to Supabase Storage');
      }

      _logger.i('Clip uploaded successfully: $url');
      onProgress?.call(1.0); // Mark as complete
      return url;
    } catch (e) {
      _logger.e('Clip upload failed: $e');
      throw Exception('Failed to upload clip: $e');
    }
  }
}
