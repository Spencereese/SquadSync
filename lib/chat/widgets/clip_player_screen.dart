import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/message_data.dart';
import '../../domain/entities/message.dart';
import '../../presentation/notifiers/chat_notifier.dart';

/// Clip comment data model
class ClipComment {
  final String id;
  final String clipMessageId;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime timestamp;
  final String? parentCommentId; // For threaded replies

  ClipComment({
    required this.id,
    required this.clipMessageId,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.timestamp,
    this.parentCommentId,
  });

  factory ClipComment.fromMap(Map<String, dynamic> data) {
    return ClipComment(
      id: data['id']?.toString() ?? '',
      clipMessageId: data['clip_message_id'] ?? '',
      authorUid: data['author_uid'] ?? '',
      authorName: data['author_name'] ?? 'Unknown',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] != null
          ? DateTime.parse(data['timestamp'])
          : DateTime.now(),
      parentCommentId: data['parent_comment_id'],
    );
  }

  Map<String, dynamic> toMap() => {
        'clip_message_id': clipMessageId,
        'author_uid': authorUid,
        'author_name': authorName,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'parent_comment_id': parentCommentId,
      };
}

/// Provider for clip comments stream
final clipCommentsProvider = StreamProvider.family<List<ClipComment>, String>(
  (ref, clipMessageId) {
    return SupabaseService.client
        .from('clip_comments')
        .stream(primaryKey: ['id'])
        .eq('clip_message_id', clipMessageId)
        .order('timestamp', ascending: true)
        .map((data) => data.map((row) => ClipComment.fromMap(row)).toList());
  },
);

/// Full-screen clip player with NEON VOID styling and comprehensive features
class ClipPlayerScreen extends ConsumerStatefulWidget {
  final ClipMessageData clipData;
  final MessageData messageData;
  final String chatGroupId;
  final ChatType chatType;
  final Color? gameColor;
  final List<MessageData>? squadClips; // For auto-play next

  const ClipPlayerScreen({
    super.key,
    required this.clipData,
    required this.messageData,
    required this.chatGroupId,
    required this.chatType,
    this.gameColor,
    this.squadClips,
  });

  @override
  ConsumerState<ClipPlayerScreen> createState() => _ClipPlayerScreenState();
}

class _ClipPlayerScreenState extends ConsumerState<ClipPlayerScreen>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  late AnimationController _hypeAnimationController;
  bool _isInitialized = false;
  bool _isError = false;
  bool _showControls = true;
  bool _isPlaying = false;
  bool _showComments = false;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyToCommentId;
  String? _replyToAuthorName;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _hypeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _initializePlayer();
    _incrementViewCount();
  }

  @override
  void dispose() {
    _controller.dispose();
    _hypeAnimationController.dispose();
    _commentController.dispose();
    _commentFocusNode.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.clipData.videoUrl),
      );

      await _controller.initialize();

      if (mounted) {
        setState(() => _isInitialized = true);

        // Auto-play
        _controller.play();
        setState(() => _isPlaying = true);

        // Listen for video completion
        _controller.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() => _isError = true);
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;

    // Check for video completion
    if (_controller.value.position >= _controller.value.duration) {
      if (_isPlaying) {
        setState(() => _isPlaying = false);
        _playNextClip();
      }
    }
  }

  void _playNextClip() {
    if (widget.squadClips == null || widget.squadClips!.isEmpty) return;

    // Find current clip index
    final currentIndex = widget.squadClips!.indexWhere(
      (clip) => clip.id == widget.messageData.id,
    );

    if (currentIndex == -1 || currentIndex >= widget.squadClips!.length - 1) {
      return; // No next clip
    }

    // Get next clip
    final nextClip = widget.squadClips![currentIndex + 1];
    if (nextClip.clipData == null) return;

    // Navigate to next clip
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ClipPlayerScreen(
          clipData: nextClip.clipData!,
          messageData: nextClip,
          chatGroupId: widget.chatGroupId,
          chatType: widget.chatType,
          gameColor: widget.gameColor,
          squadClips: widget.squadClips,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _incrementViewCount() async {
    await ref.read(chatNotifierProvider.notifier).incrementClipViews(
          widget.chatGroupId,
          widget.messageData.id,
          widget.chatType,
        );
  }

  @override
  Widget build(BuildContext context) {
    final neonColor = widget.gameColor ?? const Color(0xFF00FFFF);
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Video player section
              Expanded(
                flex: isLandscape ? 1 : 3,
                child: _buildVideoPlayer(neonColor),
              ),

              // Comments section (portrait only)
              if (!isLandscape && _showComments)
                Expanded(
                  flex: 2,
                  child: _buildCommentsSection(neonColor),
                ),

              // Bottom controls
              if (!isLandscape) _buildBottomControls(neonColor),
            ],
          ),

          // Overlay controls (landscape)
          if (isLandscape && _showControls) _buildLandscapeOverlay(neonColor),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(Color neonColor) {
    return GestureDetector(
      onTap: () {
        setState(() => _showControls = !_showControls);
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video player
            if (_isInitialized && !_isError)
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
              ),

            // Loading state
            if (!_isInitialized && !_isError)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: neonColor),
                    const SizedBox(height: 16),
                    Text(
                      'Loading clip...',
                      style: TextStyle(
                        color: neonColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // Error state
            if (_isError) _buildErrorState(neonColor),

            // Top bar overlay
            if (_showControls) _buildTopBar(neonColor),

            // Center play/pause button
            if (_showControls && _isInitialized && !_isError)
              Center(child: _buildPlayPauseButton(neonColor)),

            // Progress bar
            if (_showControls && _isInitialized && !_isError)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildProgressBar(neonColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Color neonColor) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: neonColor, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load clip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: neonColor,
                foregroundColor: Colors.black,
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color neonColor) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Close button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: neonColor.withOpacity(0.5)),
                    ),
                    child: Icon(Icons.close, color: neonColor),
                  ),
                ),
                const SizedBox(width: 12),

                // User info and game badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.messageData.sender,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Game badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: neonColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: neonColor.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.gamepad, size: 12, color: neonColor),
                                const SizedBox(width: 4),
                                Text(
                                  'SQUAD', // TODO: Get actual game name
                                  style: TextStyle(
                                    color: neonColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${widget.clipData.views} views',
                            style: TextStyle(
                              color: neonColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(widget.messageData.timestamp),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Share button
                GestureDetector(
                  onTap: _shareClip,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: neonColor.withOpacity(0.5)),
                    ),
                    child: Icon(Icons.share, color: neonColor, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(Color neonColor) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (_isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
        setState(() => _isPlaying = !_isPlaying);
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: neonColor.withOpacity(0.2),
          border: Border.all(color: neonColor, width: 3),
          boxShadow: [
            BoxShadow(
              color: neonColor.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 48,
          color: neonColor,
        ),
      ),
    )
        .animate(target: _isPlaying ? 0 : 1)
        .scale(duration: 200.ms, curve: Curves.easeOut);
  }

  Widget _buildProgressBar(Color neonColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: neonColor,
              bufferedColor: neonColor.withOpacity(0.3),
              backgroundColor: Colors.white.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, value, child) {
              final position = value.position;
              final duration = value.duration;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(Color neonColor) {
    final currentUser = AuthServiceSupabase().currentUser;
    final isHyped = currentUser != null &&
        widget.clipData.hypeReactions.contains(currentUser.id);
    final hypeCount = widget.clipData.hypeReactions.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: neonColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Big Hype button
              GestureDetector(
                onTap: _handleHypeTap,
                child: AnimatedBuilder(
                  animation: _hypeAnimationController,
                  builder: (context, child) {
                    final scale = 1.0 +
                        (_hypeAnimationController.value * 0.2) *
                            (1 - _hypeAnimationController.value);
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isHyped
                                ? [
                                    neonColor.withOpacity(0.3),
                                    neonColor.withOpacity(0.1),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.1),
                                    Colors.white.withOpacity(0.05),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isHyped
                                ? neonColor
                                : Colors.white.withOpacity(0.3),
                            width: isHyped ? 2 : 1,
                          ),
                          boxShadow: isHyped
                              ? [
                                  BoxShadow(
                                    color: neonColor.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '🔥',
                              style: TextStyle(fontSize: isHyped ? 32 : 28),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isHyped ? 'HYPED!' : 'HYPE THIS CLIP',
                              style: TextStyle(
                                color: isHyped ? neonColor : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (hypeCount > 0) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isHyped
                                      ? neonColor.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  hypeCount.toString(),
                                  style: TextStyle(
                                    color: isHyped ? neonColor : Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Comments toggle button
              GestureDetector(
                onTap: () {
                  setState(() => _showComments = !_showComments);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _showComments
                        ? neonColor.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showComments
                          ? neonColor.withOpacity(0.5)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showComments
                            ? Icons.close_rounded
                            : Icons.comment_rounded,
                        color: _showComments ? neonColor : Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showComments ? 'Hide Comments' : 'View Comments',
                        style: TextStyle(
                          color: _showComments ? neonColor : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsSection(Color neonColor) {
    final commentsAsync =
        ref.watch(clipCommentsProvider(widget.messageData.id));

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: neonColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Comments header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.comment, color: neonColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Comments',
                  style: TextStyle(
                    color: neonColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.white38,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Build threaded comment list
                final topLevelComments =
                    comments.where((c) => c.parentCommentId == null).toList();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: topLevelComments.length,
                  itemBuilder: (context, index) {
                    final comment = topLevelComments[index];
                    final replies = comments
                        .where((c) => c.parentCommentId == comment.id)
                        .toList();

                    return _buildCommentItem(
                      comment,
                      neonColor,
                      replies: replies,
                    );
                  },
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(color: neonColor),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'Failed to load comments',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
          ),

          // Comment input
          _buildCommentInput(neonColor),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
    ClipComment comment,
    Color neonColor, {
    List<ClipComment>? replies,
    bool isReply = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 32 : 0,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: isReply ? 28 : 32,
                height: isReply ? 28 : 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [neonColor, neonColor.withOpacity(0.5)],
                  ),
                ),
                child: Center(
                  child: Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: isReply ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          comment.authorName,
                          style: TextStyle(
                            color: neonColor,
                            fontSize: isReply ? 13 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatCommentTime(comment.timestamp),
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: isReply ? 11 : 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.text,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isReply ? 13 : 14,
                      ),
                    ),
                    if (!isReply) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _replyToCommentId = comment.id;
                            _replyToAuthorName = comment.authorName;
                          });
                          _commentFocusNode.requestFocus();
                        },
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            color: neonColor.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Threaded replies
          if (replies != null && replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                children: replies
                    .map((reply) => _buildCommentItem(
                          reply,
                          neonColor,
                          isReply: true,
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput(Color neonColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: neonColor.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToCommentId != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: neonColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: neonColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply, color: neonColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Replying to $_replyToAuthorName',
                        style: TextStyle(
                          color: neonColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _replyToCommentId = null;
                          _replyToAuthorName = null;
                        });
                      },
                      child: Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: neonColor.withOpacity(0.3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: neonColor.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: neonColor,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _postComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [neonColor, neonColor.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: neonColor.withOpacity(0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeOverlay(Color neonColor) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.7),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
            stops: const [0.0, 0.2, 0.8, 1.0],
          ),
        ),
        child: Column(
          children: [
            _buildTopBar(neonColor),
            const Spacer(),
            if (_isInitialized && !_isError) _buildProgressBar(neonColor),
          ],
        ),
      ),
    ).animate(target: _showControls ? 1 : 0).fadeIn(duration: 200.ms);
  }

  Future<void> _handleHypeTap() async {
    HapticFeedback.heavyImpact();
    _hypeAnimationController.forward(from: 0);

    await ref.read(chatNotifierProvider.notifier).toggleClipHype(
          widget.chatGroupId,
          widget.messageData.id,
          widget.chatType,
        );
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) return;

    try {
      final commentData = {
        'clip_message_id': widget.messageData.id,
        'author_uid': currentUser.id,
        'author_name': currentUser.userMetadata?['display_name'] ?? 'Unknown',
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
        'parent_comment_id': _replyToCommentId,
      };

      await SupabaseService.client.from('clip_comments').insert(commentData);

      _commentController.clear();
      setState(() {
        _replyToCommentId = null;
        _replyToAuthorName = null;
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to post comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to post comment')),
      );
    }
  }

  Future<void> _shareClip() async {
    try {
      // Create a deep link to this clip
      final clipLink =
          'codsquadapp://clip/${widget.chatGroupId}/${widget.messageData.id}';

      await Share.share(
        'Check out this clip from ${widget.messageData.sender}!\n$clipLink',
        subject: 'SquadSync Clip',
      );

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to share clip: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatCommentTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
