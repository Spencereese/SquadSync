import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';

/// Utility class for detecting and handling different types of URLs
class LinkDetector {
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s]+',
    caseSensitive: false,
  );

  static List<String> extractUrls(String text) {
    return _urlRegex.allMatches(text).map((match) => match.group(0)!).toList();
  }

  static bool containsUrls(String text) {
    return _urlRegex.hasMatch(text);
  }

  static LinkType getLinkType(String url) {
    final uri = Uri.parse(url.toLowerCase());

    // Video platforms
    if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      return LinkType.youtube;
    }
    if (uri.host.contains('vimeo.com')) {
      return LinkType.vimeo;
    }
    if (uri.host.contains('twitch.tv')) {
      return LinkType.twitch;
    }

    // Social media
    if (uri.host.contains('twitter.com') || uri.host.contains('x.com')) {
      return LinkType.twitter;
    }
    if (uri.host.contains('instagram.com')) {
      return LinkType.instagram;
    }
    if (uri.host.contains('facebook.com')) {
      return LinkType.facebook;
    }
    if (uri.host.contains('tiktok.com')) {
      return LinkType.tiktok;
    }

    // Video files
    if (url.toLowerCase().contains('.mp4') ||
        url.toLowerCase().contains('.mov') ||
        url.toLowerCase().contains('.avi') ||
        url.toLowerCase().contains('.mkv')) {
      return LinkType.videoFile;
    }

    // Image files
    if (url.toLowerCase().contains('.jpg') ||
        url.toLowerCase().contains('.jpeg') ||
        url.toLowerCase().contains('.png') ||
        url.toLowerCase().contains('.gif') ||
        url.toLowerCase().contains('.webp')) {
      return LinkType.imageFile;
    }

    return LinkType.website;
  }
}

enum LinkType {
  youtube,
  vimeo,
  twitch,
  twitter,
  instagram,
  facebook,
  tiktok,
  videoFile,
  imageFile,
  website,
}

/// Model for link preview data
class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final LinkType type;

  LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    required this.type,
  });

  factory LinkPreview.fromJson(Map<String, dynamic> json, String url) {
    return LinkPreview(
      url: url,
      title: json['title'],
      description: json['description'],
      imageUrl: json['image'],
      type: LinkDetector.getLinkType(url),
    );
  }
}

/// Service for fetching link previews
class LinkPreviewService {
  static const String _backendUrl =
      'https://squadsync-backend-756172684661.us-central1.run.app';

  static Future<LinkPreview?> fetchPreview(String url) async {
    try {
      final linkType = LinkDetector.getLinkType(url);

      // For social media and video platforms, try to get rich previews
      if (linkType == LinkType.twitter) {
        return await _fetchTwitterPreview(url);
      }

      // For direct video/image files, create basic preview
      if (linkType == LinkType.videoFile || linkType == LinkType.imageFile) {
        return LinkPreview(
          url: url,
          title: _getFileName(url),
          type: linkType,
        );
      }

      // Use our backend endpoint for link previews
      final response = await http.get(
        Uri.parse('$_backendUrl/link-preview?url=${Uri.encodeComponent(url)}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return LinkPreview(
          url: url,
          title: data['title'],
          description: data['description'],
          imageUrl: data['image'],
          type: linkType,
        );
      }
    } catch (e) {
      debugPrint('Error fetching link preview: $e');
    }

    // Fallback: return basic preview
    return LinkPreview(
      url: url,
      title: _getDomain(url),
      type: LinkDetector.getLinkType(url),
    );
  }

  static Future<LinkPreview?> _fetchTwitterPreview(String url) async {
    try {
      // Extract tweet ID from URL
      final tweetId = _extractTweetId(url);
      if (tweetId == null) return null;

      // Note: Twitter API requires authentication. For now, return basic preview
      // In production, you'd use Twitter API v2 with Bearer token
      return LinkPreview(
        url: url,
        title: 'Tweet',
        description: 'Tap to view tweet',
        type: LinkType.twitter,
      );
    } catch (e) {
      debugPrint('Error fetching Twitter preview: $e');
      return null;
    }
  }

  static String? _extractTweetId(String url) {
    final regex = RegExp(r'/status/(\d+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  static String _getFileName(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    return pathSegments.isNotEmpty ? pathSegments.last : 'File';
  }

  static String _getDomain(String url) {
    final uri = Uri.parse(url);
    return uri.host;
  }
}

/// Widget for displaying rich text with clickable links
class RichTextWithLinks extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool isMe;

  const RichTextWithLinks({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final urls = LinkDetector.extractUrls(text);

    if (urls.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
      );
    }

    // Split text by URLs and create spans
    var remainingText = text;
    for (final url in urls) {
      final parts = remainingText.split(url);
      if (parts.isNotEmpty) {
        spans.add(TextSpan(text: parts[0], style: style));
        spans.add(
          TextSpan(
            text: url,
            style: (style ?? const TextStyle()).copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()..onTap = () => _launchUrl(url),
          ),
        );
        remainingText = parts.length > 1 ? parts.sublist(1).join(url) : '';
      }
    }

    if (remainingText.isNotEmpty) {
      spans.add(TextSpan(text: remainingText, style: style));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign,
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      HapticFeedback.lightImpact();
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Widget for displaying link previews
class LinkPreviewWidget extends StatefulWidget {
  final String url;
  final LinkType type;

  const LinkPreviewWidget({
    super.key,
    required this.url,
    required this.type,
  });

  @override
  State<LinkPreviewWidget> createState() => _LinkPreviewWidgetState();
}

class _LinkPreviewWidgetState extends State<LinkPreviewWidget> {
  LinkPreview? _preview;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final preview = await LinkPreviewService.fetchPreview(widget.url);
    if (mounted) {
      setState(() {
        _preview = preview;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Loading preview...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_preview == null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          widget.url,
          style: const TextStyle(
              color: Colors.blue, decoration: TextDecoration.underline),
        ),
      );
    }

    // Special handling for different social media types
    switch (widget.type) {
      case LinkType.twitter:
        return _buildTwitterPreview();
      case LinkType.instagram:
        return _buildInstagramPreview();
      case LinkType.tiktok:
        return _buildTikTokPreview();
      case LinkType.youtube:
        return _buildYouTubePreview();
      default:
        return _buildGenericPreview();
    }
  }

  Widget _buildTwitterPreview() {
    return GestureDetector(
      onTap: () => _launchUrl(widget.url),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1DA1F2).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFF1DA1F2).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline,
                color: Color(0xFF1DA1F2), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Twitter / X Post',
                    style: TextStyle(
                      color: Color(0xFF1DA1F2),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _preview!.description ?? 'Tap to view tweet',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFF1DA1F2), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInstagramPreview() {
    return GestureDetector(
      onTap: () => _launchUrl(widget.url),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE4405F).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFFE4405F).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.camera_alt, color: Color(0xFFE4405F), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Instagram Post',
                    style: TextStyle(
                      color: Color(0xFFE4405F),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _preview!.description ?? 'Tap to view post',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFFE4405F), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildYouTubePreview() {
    return GestureDetector(
      onTap: () => _launchUrl(widget.url),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFF0000).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: const Color(0xFFFF0000).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill,
                color: Color(0xFFFF0000), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YouTube Video',
                    style: TextStyle(
                      color: Color(0xFFFF0000),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _preview!.title ?? 'Tap to watch video',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Color(0xFFFF0000), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTikTokPreview() {
    return GestureDetector(
      onTap: () => _launchUrl(widget.url),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.music_note, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TikTok Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _preview!.description ?? 'Tap to watch video',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericPreview() {
    return GestureDetector(
      onTap: () => _launchUrl(widget.url),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_preview!.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: _preview!.imageUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 150,
                    color: Colors.black38,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 150,
                    color: Colors.black38,
                    child: const Icon(Icons.image, color: Colors.white38),
                  ),
                ),
              ),
            if (_preview!.title != null) ...[
              const SizedBox(height: 8),
              Text(
                _preview!.title!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (_preview!.description != null) ...[
              const SizedBox(height: 4),
              Text(
                _preview!.description!,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _getDomain(widget.url),
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDomain(String url) {
    final uri = Uri.parse(url);
    return uri.host;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      HapticFeedback.lightImpact();
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Widget for video previews
class VideoLinkPreview extends StatefulWidget {
  final String url;
  final LinkType type;

  const VideoLinkPreview({
    super.key,
    required this.url,
    required this.type,
  });

  @override
  State<VideoLinkPreview> createState() => _VideoLinkPreviewState();
}

class _VideoLinkPreviewState extends State<VideoLinkPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _showControls = false;
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      String? videoUrl;
      String? thumbnailUrl;

      if (widget.type == LinkType.youtube) {
        final videoId = _extractYouTubeVideoId(widget.url);
        if (videoId != null) {
          // Use YouTube's thumbnail for initial display
          thumbnailUrl =
              'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
          // For inline playback, we'll use a different approach
          videoUrl = 'https://www.youtube.com/watch?v=$videoId';
        }
      } else if (widget.type == LinkType.vimeo) {
        videoUrl = _getVimeoVideoUrl(widget.url);
      } else if (widget.type == LinkType.videoFile) {
        videoUrl = widget.url;
      } else if (widget.type == LinkType.twitch) {
        // For Twitch, we'll show preview but open externally
        videoUrl = null;
      }

      if (videoUrl != null && widget.type != LinkType.youtube) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await _controller!.initialize();
        _controller!.addListener(_onVideoStateChanged);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _thumbnailUrl = thumbnailUrl;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true; // Mark as initialized even on error
        });
      }
    }
  }

  void _onVideoStateChanged() {
    if (mounted) {
      setState(() {
        _isPlaying = _controller?.value.isPlaying ?? false;
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_controller == null) {
      // For YouTube and other external videos, open externally
      _launchUrl(widget.url);
      return;
    }

    if (_isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.play();
    }
  }

  String? _extractYouTubeVideoId(String url) {
    final regex = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  String? _getVimeoVideoUrl(String url) {
    // For Vimeo, we'd need their API. For now, return null to show thumbnail
    return null;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoStateChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // For videos that can't be played inline, show preview with external link
    if (_controller == null && widget.type != LinkType.youtube) {
      return LinkPreviewWidget(url: widget.url, type: widget.type);
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: MouseRegion(
        onEnter: (_) => setState(() => _showControls = true),
        onExit: (_) => setState(() => _showControls = false),
        child: Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: _controller?.value.aspectRatio ?? 16 / 9,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Video player or thumbnail
                  if (_controller != null && _isInitialized)
                    VideoPlayer(_controller!)
                  else if (_thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: _thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.black38,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.black38,
                        child: const Icon(Icons.video_library,
                            color: Colors.white38, size: 48),
                      ),
                    )
                  else
                    Container(
                      color: Colors.black38,
                      child: const Center(
                        child: Icon(Icons.video_library,
                            color: Colors.white38, size: 48),
                      ),
                    ),

                  // Play button overlay
                  if (!_isPlaying)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),

                  // Video controls
                  if (_controller != null && (_showControls || !_isPlaying))
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _togglePlayPause,
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              iconSize: 24,
                            ),
                            Expanded(
                              child: VideoProgressIndicator(
                                _controller!,
                                allowScrubbing: true,
                                colors: const VideoProgressColors(
                                  playedColor: Colors.red,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _launchUrl(widget.url),
                              icon: const Icon(
                                Icons.open_in_new,
                                color: Colors.white,
                              ),
                              iconSize: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Loading indicator
                  if (_controller != null && !_isInitialized)
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      HapticFeedback.lightImpact();
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
