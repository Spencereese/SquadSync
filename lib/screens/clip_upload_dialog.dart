import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../presentation/notifiers/clip_notifier.dart';
import '../services/clip_service.dart';

/// Dialog for uploading a clip with progress indication
class ClipUploadDialog extends ConsumerStatefulWidget {
  final String? squadId;
  final Color? gameColor;

  const ClipUploadDialog({
    super.key,
    this.squadId,
    this.gameColor,
  });

  @override
  ConsumerState<ClipUploadDialog> createState() => _ClipUploadDialogState();
}

class _ClipUploadDialogState extends ConsumerState<ClipUploadDialog> {
  final ImagePicker _picker = ImagePicker();
  final ClipService _clipService = ClipService();

  bool _isProcessing = false;
  double _uploadProgress = 0.0;
  String _statusMessage = 'Ready to upload';
  File? _selectedVideo;

  Future<void> _pickVideo() async {
    try {
      HapticFeedback.lightImpact();

      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );

      if (video != null && mounted) {
        setState(() {
          _selectedVideo = File(video.path);
          _statusMessage = 'Video selected: ${video.name}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadClip() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _uploadProgress = 0.0;
      _statusMessage = 'Starting upload...';
    });

    try {
      HapticFeedback.mediumImpact();

      // Process and upload the clip
      final clipData = await _clipService.processClip(
        _selectedVideo!.path,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              if (progress < 0.3) {
                _statusMessage = 'Compressing video...';
              } else if (progress < 0.6) {
                _statusMessage = 'Generating thumbnail...';
              } else if (progress < 0.9) {
                _statusMessage = 'Uploading...';
              } else {
                _statusMessage = 'Finalizing...';
              }
            });
          }
        },
      );

      // Upload clip to Supabase via clip notifier
      await ref.read(clipNotifierProvider.notifier).uploadClip(
            widget.squadId,
            clipData,
          );

      if (mounted) {
        HapticFeedback.heavyImpact();

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎮 Clip uploaded successfully!'),
            backgroundColor: widget.gameColor ?? Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();

        setState(() {
          _isProcessing = false;
          _statusMessage = 'Upload failed';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = widget.gameColor ?? theme.colorScheme.primary;

    return Dialog(
      backgroundColor: const Color(0xFF14181F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.videocam,
                  color: accentColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Upload Clip',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (!_isProcessing)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Video preview or placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                ),
              ),
              child: _selectedVideo != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: accentColor,
                              size: 64,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Video Ready',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            color: Colors.white38,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No video selected',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Status message
            Text(
              _statusMessage,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Progress bar
            if (_isProcessing)
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickVideo,
                    icon: const Icon(Icons.video_library),
                    label: Text(
                      _selectedVideo != null ? 'Change Video' : 'Select Video',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(color: accentColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing || _selectedVideo == null
                        ? null
                        : _uploadClip,
                    icon: _isProcessing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isProcessing ? 'Uploading...' : 'Upload'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: accentColor.withOpacity(0.3),
                    ),
                  ),
                ),
              ],
            ),

            // Info text
            const SizedBox(height: 16),
            Text(
              'Videos longer than 30 seconds will be trimmed.\nMax resolution: 720p',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
