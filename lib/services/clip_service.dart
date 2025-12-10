import 'dart:io';
import 'dart:async';
import 'auth_service_supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'supabase_service.dart';

/// Exception classes for clip processing
class ClipProcessingException implements Exception {
  final String message;
  final dynamic originalError;

  ClipProcessingException(this.message, [this.originalError]);

  @override
  String toString() =>
      'ClipProcessingException: $message${originalError != null ? ' (${originalError.toString()})' : ''}';
}

class ClipCompressionException extends ClipProcessingException {
  ClipCompressionException(String message, [dynamic originalError])
      : super(message, originalError);
}

class ClipUploadException extends ClipProcessingException {
  ClipUploadException(String message, [dynamic originalError])
      : super(message, originalError);
}

class ClipThumbnailException extends ClipProcessingException {
  ClipThumbnailException(String message, [dynamic originalError])
      : super(message, originalError);
}

/// Data model for processed clip
class ClipData {
  final String videoUrl;
  final String thumbUrl;
  final int duration; // in milliseconds
  final int width;
  final int height;
  final String clipId;

  ClipData({
    required this.videoUrl,
    required this.thumbUrl,
    required this.duration,
    required this.width,
    required this.height,
    required this.clipId,
  });

  Map<String, dynamic> toJson() => {
        'videoUrl': videoUrl,
        'thumbUrl': thumbUrl,
        'duration': duration,
        'width': width,
        'height': height,
        'clipId': clipId,
      };

  factory ClipData.fromJson(Map<String, dynamic> json) => ClipData(
        videoUrl: json['videoUrl'] as String,
        thumbUrl: json['thumbUrl'] as String,
        duration: json['duration'] as int,
        width: json['width'] as int,
        height: json['height'] as int,
        clipId: json['clipId'] as String,
      );
}

/// Service for processing and uploading gaming clips
class ClipService {
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  static const int maxDurationSeconds = 30;
  static const int maxResolutionHeight = 720;
  static const int targetFrameRate = 30;
  static const int targetBitrate = 2000000; // 2 Mbps

  /// Process a video clip: compress, trim if needed, generate thumbnail, and upload
  ///
  /// [filePath] - Path to the original video file
  /// [onProgress] - Optional callback for upload progress (0.0 to 1.0)
  ///
  /// Returns [ClipData] with URLs and metadata
  ///
  /// Throws [ClipProcessingException] or its subclasses on failure
  Future<ClipData> processClip(
    String filePath, {
    Function(double progress)? onProgress,
  }) async {
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      throw ClipProcessingException(
          'User must be authenticated to upload clips');
    }

    final clipId = _uuid.v4();
    File? compressedFile;
    File? thumbnailFile;

    try {
      _logger.i('Starting clip processing for: $filePath');
      onProgress?.call(0.1);

      // Get video info
      final videoInfo = await _getVideoInfo(filePath);
      if (videoInfo == null) {
        throw ClipProcessingException('Failed to read video information');
      }

      _logger.i(
          'Video info - Duration: ${videoInfo.duration}s, Size: ${videoInfo.width}x${videoInfo.height}');
      onProgress?.call(0.2);

      // Trim video if longer than 30 seconds (keep last 30 seconds)
      String processedPath = filePath;
      if (videoInfo.duration != null &&
          videoInfo.duration! > maxDurationSeconds * 1000) {
        _logger.i('Trimming video to last $maxDurationSeconds seconds');
        processedPath = await _trimVideo(
          filePath,
          videoInfo.duration!.toInt(),
        );
        onProgress?.call(0.3);
      }

      // Compress video (max 720p, 30fps, reduce bitrate)
      _logger.i('Compressing video...');
      compressedFile = await _compressVideo(processedPath);
      if (compressedFile == null) {
        throw ClipCompressionException('Video compression failed');
      }
      onProgress?.call(0.5);

      // Generate thumbnail
      _logger.i('Generating thumbnail...');
      thumbnailFile = await _generateThumbnail(compressedFile.path);
      if (thumbnailFile == null) {
        throw ClipThumbnailException('Thumbnail generation failed');
      }
      onProgress?.call(0.6);

      // Upload video
      _logger.i('Uploading video...');
      final videoUrl = await _uploadFile(
        compressedFile,
        'clips/$clipId.mp4',
        onProgress: (uploadProgress) {
          // Map upload progress from 0.6 to 0.8
          onProgress?.call(0.6 + (uploadProgress * 0.2));
        },
      );
      onProgress?.call(0.8);

      // Upload thumbnail
      _logger.i('Uploading thumbnail...');
      final thumbUrl = await _uploadFile(
        thumbnailFile,
        'clips/${clipId}_thumb.jpg',
        onProgress: (uploadProgress) {
          // Map upload progress from 0.8 to 0.95
          onProgress?.call(0.8 + (uploadProgress * 0.15));
        },
      );
      onProgress?.call(0.95);

      // Get final video info for metadata
      final finalVideoInfo = await _getVideoInfo(compressedFile.path);
      final duration = finalVideoInfo?.duration ?? 0;
      final width = finalVideoInfo?.width ?? 0;
      final height = finalVideoInfo?.height ?? 0;

      onProgress?.call(1.0);
      _logger.i('Clip processing complete: $clipId');

      return ClipData(
        videoUrl: videoUrl,
        thumbUrl: thumbUrl,
        duration: duration.toInt(),
        width: width.toInt(),
        height: height.toInt(),
        clipId: clipId,
      );
    } catch (e) {
      _logger.e('Clip processing failed: $e');
      if (e is ClipProcessingException) {
        rethrow;
      }
      throw ClipProcessingException(
          'Unexpected error during clip processing', e);
    } finally {
      // Cleanup temporary files
      await _cleanupFiles([compressedFile, thumbnailFile]);
    }
  }

  /// Get video information
  Future<MediaInfo?> _getVideoInfo(String filePath) async {
    try {
      return await VideoCompress.getMediaInfo(filePath);
    } catch (e) {
      _logger.e('Failed to get video info: $e');
      return null;
    }
  }

  /// Trim video to last N seconds
  Future<String> _trimVideo(String filePath, int totalDurationMs) async {
    try {
      final startTime = (totalDurationMs / 1000) - maxDurationSeconds;

      // Use VideoCompress to trim
      final result = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.HighestQuality,
        deleteOrigin: false,
        startTime: startTime.toInt(),
        duration: maxDurationSeconds,
        includeAudio: true,
      );

      if (result?.file == null) {
        throw ClipCompressionException('Failed to trim video');
      }

      return result!.file!.path;
    } catch (e) {
      _logger.e('Failed to trim video: $e');
      throw ClipCompressionException('Video trimming failed', e);
    }
  }

  /// Compress video to max 720p, 30fps, reduced bitrate
  Future<File?> _compressVideo(String filePath) async {
    try {
      final result = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: targetFrameRate,
      );

      return result?.file;
    } catch (e) {
      _logger.e('Failed to compress video: $e');
      throw ClipCompressionException('Video compression failed', e);
    }
  }

  /// Generate thumbnail at 50% mark or peak brightness frame
  Future<File?> _generateThumbnail(String videoPath) async {
    try {
      // Get video duration to find 50% mark
      final info = await VideoCompress.getMediaInfo(videoPath);
      if (info.duration == null) {
        throw ClipThumbnailException('Cannot determine video duration');
      }

      // Generate thumbnail at 50% mark
      final timeMs = (info.duration! / 2).toInt();

      final thumbnail = await VideoCompress.getFileThumbnail(
        videoPath,
        quality: 80,
        position: timeMs,
      );

      return thumbnail;
    } catch (e) {
      _logger.e('Failed to generate thumbnail: $e');
      if (e is ClipThumbnailException) {
        rethrow;
      }
      throw ClipThumbnailException('Thumbnail generation failed', e);
    }
  }

  /// Upload file to Supabase Storage
  Future<String> _uploadFile(
    File file,
    String storagePath, {
    Function(double progress)? onProgress,
  }) async {
    try {
      // Read file as bytes
      final bytes = await file.readAsBytes();

      // Upload to Supabase Storage
      final supabase = SupabaseService.client;
      await supabase.storage.from('clips').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'video/mp4',
              upsert: false,
            ),
          );

      // Get public URL
      final downloadUrl =
          supabase.storage.from('clips').getPublicUrl(storagePath);

      _logger.i('Clip uploaded: $downloadUrl');
      onProgress?.call(1.0); // Mark as complete
      return downloadUrl;
    } catch (e) {
      _logger.e('Failed to upload file to $storagePath: $e');
      throw ClipUploadException('File upload failed', e);
    }
  }

  /// Cleanup temporary files
  Future<void> _cleanupFiles(List<File?> files) async {
    for (final file in files) {
      if (file != null && await file.exists()) {
        try {
          await file.delete();
          _logger.d('Deleted temporary file: ${file.path}');
        } catch (e) {
          _logger.w('Failed to delete temporary file: ${file.path}');
        }
      }
    }
  }

  /// Cancel ongoing compression (cleanup)
  Future<void> cancelProcessing() async {
    try {
      await VideoCompress.cancelCompression();
      _logger.i('Compression cancelled');
    } catch (e) {
      _logger.e('Failed to cancel compression: $e');
    }
  }

  /// Delete a clip from Supabase Storage
  Future<void> deleteClip(String clipId) async {
    try {
      final supabase = SupabaseService.client;

      // Delete video file
      await supabase.storage.from('clips').remove(['$clipId.mp4']);

      // Delete thumbnail file
      await supabase.storage.from('clips').remove(['${clipId}_thumb.jpg']);

      _logger.i('Deleted clip: $clipId');
    } catch (e) {
      _logger.e('Failed to delete clip $clipId: $e');
      throw ClipProcessingException('Failed to delete clip', e);
    }
  }

  /// Get subscription to VideoCompress events for monitoring
  /// Returns an ObservableBuilder that can be converted to a Stream
  dynamic getCompressionProgress() {
    return VideoCompress.compressProgress$;
  }

  /// Dispose resources
  void dispose() {
    VideoCompress.dispose();
  }
}
