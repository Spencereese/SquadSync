import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';
import 'chat_state.dart';
import 'link_preview.dart';
import 'poll_message_bubble.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';
import 'dialogs/message_reaction_dialog.dart';
import 'widgets/video_message.dart';
import 'widgets/audio_message.dart';
import 'services/reaction_service.dart';
// For debugPrint

const String storageBucketPrefix =
    'https://storage.googleapis.com/squadsync-media/'; // Customize if your bucket differs

String fixMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return url.startsWith('http') ? url : '$storageBucketPrefix$url';
}

class MessageBubble extends StatefulWidget {
  final dynamic message;
  final bool isMe;
  final bool showSender;
  final bool showAvatar;
  final bool showTimestamp;
  final bool showReadIndicator;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Map<String, bool> sendingStatus;
  final String? chatGroupId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showSender,
    required this.showAvatar,
    required this.showTimestamp,
    required this.showReadIndicator,
    required this.onTap,
    required this.onLongPress,
    required this.sendingStatus,
    this.chatGroupId,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  late Map<String, dynamic> _normalizedData;
  late List<String> _urls;
  bool _isGrokExpanded = false; // Track if Grok message is expanded

  @override
  void initState() {
    super.initState();
    _normalizeAndCacheData();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _normalizeAndCacheData();
    }
  }

  void _normalizeAndCacheData() {
    _normalizedData = _normalizeMessage(widget.message);
    _urls = LinkDetector.extractUrls(_normalizedData['text'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a Grok AI message for unique styling
    final isAiResponse = _normalizedData['isAiResponse'] ?? false;
    final senderUid = _normalizedData['senderUid'] ?? '';
    final isGrokMessage = isAiResponse && senderUid == 'grok-ai';

    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        // Unique layout for Grok messages
        if (isGrokMessage) {
          return _buildGrokMessage(context);
        }

        // Standard layout for regular messages
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Column(
            crossAxisAlignment:
                widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (widget.showTimestamp &&
                  (_normalizedData['timestamp'] != null ||
                      _normalizedData['timestamp_ms'] != null))
                _buildTimestamp(_normalizedData),
              Row(
                mainAxisAlignment: widget.isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!widget.isMe)
                    _buildAvatar(context, squadState,
                        _normalizedData['sender'] ?? 'Unknown'),
                  if (!widget.isMe) const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: widget.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (widget.showSender) _buildSender(_normalizedData),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildMessageContent(context, _normalizedData),
                            // Microphone icon for voice-to-text (like iMessage)
                            if (!widget.isMe)
                              Positioned(
                                bottom: -8,
                                right: -8,
                                child: GestureDetector(
                                  onTap: () {
                                    // TODO: Implement voice-to-text functionality
                                    HapticFeedback.lightImpact();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Voice-to-text coming soon!')),
                                    );
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                          0xFF007AFF), // iMessage blue
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.mic,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrokMessage(BuildContext context) {
    final isGrokMessage = _normalizedData['isAiResponse'] == true &&
        _normalizedData['senderUid'] == 'grok-ai';

    if (!isGrokMessage) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          if (widget.showTimestamp &&
              (_normalizedData['timestamp'] != null ||
                  _normalizedData['timestamp_ms'] != null))
            _buildTimestamp(_normalizedData),
          // HAL-like collapsed state initially
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _isGrokExpanded
                  ? _buildExpandedGrokMessage()
                  : _buildCollapsedGrokMessage(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedGrokMessage() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isGrokExpanded = true;
        });
      },
      child: Semantics(
        label: 'Grok message - tap to expand',
        child: Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
            border: Border.all(
              color: const Color(0xFF8B0000),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B0000).withValues(alpha: 0.6),
                blurRadius: 7,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Color(0xFF8B0000),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedGrokMessage() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _isGrokExpanded = false;
        });
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A), // Very dark background
          border: Border.all(
            color: const Color(0xFF8B0000), // Dark red border
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(4), // Minimal rounding
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B0000).withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header bar with subtle glow
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B0000).withValues(alpha: 0.8),
                    const Color(0xFF8B0000).withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Message content
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Terminal-like prompt indicator
                  Container(
                    margin: const EdgeInsets.only(right: 8.0, top: 2.0),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B0000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Text content
                  Expanded(
                    child: _buildText(_normalizedData['text'] ?? ''),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _normalizeMessage(dynamic message) {
    if (message is DocumentSnapshot) {
      final data = message.data() as Map<String, dynamic>? ?? {};
      final isAiResponse = data['isAiResponse'] ?? false;
      final senderUid = data['senderUid'] ?? '';
      return {
        'id': message.id,
        'sender': isAiResponse && senderUid == 'grok-ai'
            ? '' // No name for Grok - shadow mode
            : data['sender'] ?? data['sender_name'] ?? 'Unknown',
        'content': data['text'] ?? data['content'] ?? '',
        'text': data['text'] ?? data['content'] ?? '',
        'photos': data['imageUrl'] != null
            ? [
                {
                  'uri': data['imageUrl'],
                  'creation_timestamp': data['timestamp_ms']
                }
              ]
            : (data['photos'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [],
        'timestamp_ms': data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
            : data['timestamp_ms'] ?? DateTime.now().millisecondsSinceEpoch,
        'videoUrl': data['videoUrl'] ??
            (data['videos']?.isNotEmpty == true
                ? data['videos'][0]['uri']
                : null),
        'audioUrl': data['audioUrl'] ??
            (data['audio']?.isNotEmpty == true
                ? data['audio'][0]['uri']
                : null),
        'delivered': data['delivered'] ?? false,
        'read': data['read'] ?? false,
        'reactions': data['reactions'] ?? [],
        'replyTo': data['replyTo'] ?? data['reply_to'],
        'pollId': data['pollId'],
        'isAiResponse': isAiResponse,
        'senderUid': senderUid,
      };
    } else if (message is Map<String, dynamic>) {
      final id = message['id']?.toString() ?? '';
      final isAiResponse = message['isAiResponse'] ?? false;
      final senderUid = message['senderUid'] ?? '';
      return {
        'id': id,
        'sender': isAiResponse && senderUid == 'grok-ai'
            ? 'Grok 🤖'
            : message['sender'] ?? message['sender_name'] ?? 'Unknown',
        'content': message['content'] ?? message['text'] ?? '',
        'text': message['content'] ?? message['text'] ?? '',
        'photos': (message['photos'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [],
        'timestamp_ms': message['timestamp_ms'] is int
            ? message['timestamp_ms']
            : DateTime.now().millisecondsSinceEpoch,
        'videoUrl': message['videoUrl'] ??
            (message['videos']?.isNotEmpty == true
                ? message['videos'][0]['uri']
                : null),
        'audioUrl': message['audioUrl'] ??
            (message['audio']?.isNotEmpty == true
                ? message['audio'][0]['uri']
                : null),
        'delivered': message['delivered'] ?? false,
        'read': message['read'] ?? false,
        'reactions': message['reactions'] ?? [],
        'replyTo': message['replyTo'] ?? message['reply_to'],
        'pollId': message['pollId'],
        'isAiResponse': isAiResponse,
        'senderUid': senderUid,
      };
    }
    return {
      'id': '',
      'sender': 'Unknown',
      'content': '[Invalid Message]',
      'text': '[Invalid Message]'
    };
  }

  BoxDecoration _getMessageDecoration(Map<String, dynamic> data) {
    final isAiResponse = data['isAiResponse'] ?? false;
    final senderUid = data['senderUid'] ?? '';

    // Futuristic design for Grok AI messages
    final isGrok = isAiResponse && senderUid == 'grok-ai';

    if (isGrok) {
      return BoxDecoration(
        color: const Color(0xFF0A0A0A), // Very dark background
        border: Border.all(
          color: const Color(0xFF8B0000), // Dark red border
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(2), // Sharp, angular corners
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      );
    }

    // iMessage-style bubbles
    return BoxDecoration(
      color: widget.isMe
          ? const Color(0xFF007AFF) // iMessage blue for sent messages
          : const Color(
              0xFF2C2C2E), // Dark gray for received messages in dark theme
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(21),
        topRight: const Radius.circular(21),
        bottomLeft:
            widget.isMe ? const Radius.circular(21) : const Radius.circular(4),
        bottomRight:
            widget.isMe ? const Radius.circular(4) : const Radius.circular(21),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  EdgeInsets _getMessagePadding(Map<String, dynamic> data) {
    final isAiResponse = data['isAiResponse'] ?? false;
    final senderUid = data['senderUid'] ?? '';

    // Compact padding for futuristic Grok messages
    if (isAiResponse && senderUid == 'grok-ai') {
      return const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0);
    }

    // iMessage-style padding - generous for comfortable reading
    return const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0);
  }

  Widget _buildSender(Map<String, dynamic> data) {
    final isAiResponse = data['isAiResponse'] ?? false;
    final senderUid = data['senderUid'] ?? '';

    // Don't show sender name for Grok shadow messages
    if (isAiResponse && senderUid == 'grok-ai') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        data['sender'] ?? 'Unknown',
        style: TextStyle(
          color: isAiResponse
              ? const Color(0xFF00D4FF) // Electric blue for evil AI theme
              : Colors.cyanAccent
                  .withValues(alpha: 0.8), // Regular sender color
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTimestamp(Map<String, dynamic> data) {
    DateTime? timestamp;
    if (data['timestamp'] is Timestamp) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else if (data['timestamp_ms'] != null) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(data['timestamp_ms']);
    }
    if (timestamp == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Center(
        child: Semantics(
          label:
              'Message sent on ${DateFormat('MMMM d, yyyy, h:mm a').format(timestamp)}',
          child: Text(
            DateFormat('MMM d, yyyy, h:mm a').format(timestamp),
            style: TextStyle(
              color: Colors.white
                  .withValues(alpha: 0.5), // Subtle white with transparency
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Map<String, dynamic> data) {
    final hasContent = (data['content'] as String?)?.isNotEmpty ?? false;
    final hasText = (data['text'] as String?)?.isNotEmpty ?? false;
    final hasPhotos = data['photos']?.isNotEmpty ?? false;
    final hasVideo =
        data['videoUrl'] != null && (data['videoUrl'] as String).isNotEmpty;
    final hasAudio =
        data['audioUrl'] != null && (data['audioUrl'] as String).isNotEmpty;
    final hasPoll =
        data['pollId'] != null && (data['pollId'] as String).isNotEmpty;

    if (!hasContent &&
        !hasText &&
        !hasPhotos &&
        !hasVideo &&
        !hasAudio &&
        !hasPoll) {
      return const Text(
        '[Empty Message]',
        style: TextStyle(fontSize: 14, color: Colors.white70),
      );
    }

    // If this is a poll message, show the poll
    if (hasPoll) {
      return _buildPollContent(data);
    }

    // Build content column without inner bubble
    final contentWidget = Column(
      crossAxisAlignment:
          widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Add reply indicator if this is a reply
        if (data['replyTo'] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: _buildReplyIndicator(data['replyTo']),
          ),
        if (hasContent || hasText)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: _buildText(data['text'] ?? data['content'] ?? ''),
          ),
        if (hasPhotos)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: _buildImage(context, data['photos'][0]['uri']),
          ),
        if (hasVideo)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: VideoMessage(url: fixMediaUrl(data['videoUrl'])),
          ),
        if (hasAudio)
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: AudioMessage(url: fixMediaUrl(data['audioUrl'])),
          ),
        _buildMessageStatus(data),
      ],
    );

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: () => _showReactionMenu(context, data),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: _getMessagePadding(data),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width *
              0.7, // More reasonable max width
          minWidth: 60, // Smaller minimum for short messages
        ),
        decoration: _getMessageDecoration(data),
        child: Semantics(
          label: 'Message from ${data['sender'] ?? 'Unknown'}',
          child: IntrinsicWidth(
            // This ensures the bubble sizes to content
            child: contentWidget,
          ),
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300));
  }

  Widget _buildPollContent(Map<String, dynamic> data) {
    final pollId = data['pollId'] as String;
    return FutureBuilder<Poll?>(
      future: PollService().getPoll(pollId, chatGroupId: widget.chatGroupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 100,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Text(
            '[Poll not found]',
            style: TextStyle(fontSize: 14, color: Colors.white70),
          );
        }

        final poll = snapshot.data!;
        return PollMessageBubble(
          poll: poll,
          chatGroupId: widget.chatGroupId,
          isFromCurrentUser: widget.isMe,
        );
      },
    );
  }

  Widget _buildText(String text) {
    final isAiResponse = _normalizedData['isAiResponse'] ?? false;
    return Semantics(
      label: 'Message text: $text',
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          RichTextWithLinks(
            text: text,
            style: TextStyle(
              fontSize: 16,
              color: widget.isMe
                  ? Colors.white
                  : isAiResponse
                      ? Colors.white // White text for Grok messages
                      : Colors
                          .white70, // White for sent, light grey for received
              fontWeight: FontWeight.normal,
              backgroundColor: Colors.transparent,
            ),
            textAlign: widget.isMe ? TextAlign.end : TextAlign.start,
            isMe: widget.isMe,
          ),
          // Add link previews for the first URL found
          if (_urls.isNotEmpty) _buildLinkPreview(_urls.first),
        ],
      ),
    );
  }

  Widget _buildReplyIndicator(String replyToId) {
    // For now, just show a simple reply indicator
    // In a full implementation, you'd fetch the original message
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.reply, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            'Replying to message',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue[200],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPreview(String url) {
    final linkType = LinkDetector.getLinkType(url);

    // For video content, use video preview
    if (linkType == LinkType.youtube ||
        linkType == LinkType.vimeo ||
        linkType == LinkType.twitch ||
        linkType == LinkType.videoFile) {
      return VideoLinkPreview(url: url, type: linkType);
    }

    // For other links, use general link preview
    return LinkPreviewWidget(url: url, type: linkType);
  }

  Widget _buildImage(BuildContext context, String? imageUrl) {
    final fixedUrl = fixMediaUrl(imageUrl);
    if (fixedUrl.isEmpty) {
      return Semantics(
        label: 'Invalid image',
        child: const Text(
          '[Invalid Image URL]',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
      );
    }
    debugPrint('Loading image: $fixedUrl'); // Log for debugging
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, fixedUrl),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 200, // Smaller within bubble
          maxHeight: 200,
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(8), // Smaller radius within bubble
          child: CachedNetworkImage(
            imageUrl: fixedUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) {
              debugPrint('Image load error: $error for URL: $url'); // Log error
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 24),
                    SizedBox(height: 4),
                    Text(
                      'Failed to load',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageStatus(Map<String, dynamic> data) {
    final messageId = data['id']?.toString() ?? '';
    if (messageId.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.sendingStatus[messageId] == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Semantics(
          label: 'Message is sending',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text('Sending...',
                  style: TextStyle(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      );
    }
    if (widget.sendingStatus[messageId] == false) {
      return Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Semantics(
          label: 'Message failed to send',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 12, color: Colors.redAccent),
              const SizedBox(width: 4),
              const Text('Failed',
                  style: TextStyle(fontSize: 10, color: Colors.redAccent)),
            ],
          ),
        ),
      );
    }
    if (widget.showReadIndicator &&
        !widget.sendingStatus.containsKey(messageId)) {
      return Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data['delivered'] == true)
              Semantics(
                label: 'Message delivered',
                child: const Text('Delivered',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
              ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
            if (data['read'] == true)
              Semantics(
                label: 'Message read',
                child: const Icon(Icons.done_all, color: Colors.blue, size: 14),
              ).animate().scale(duration: const Duration(milliseconds: 300)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAvatar(
      BuildContext context, SquadState squadState, String sender) {
    final profileImage = squadState.memberProfileImages[sender];
    return GestureDetector(
      onTap: () => _showUserMenu(context, squadState, sender),
      child: CircleAvatar(
        radius: 16,
        backgroundImage: profileImage != null && profileImage.isNotEmpty
            ? CachedNetworkImageProvider(fixMediaUrl(profileImage))
            : null,
        child: profileImage == null || profileImage.isEmpty
            ? Text(
                sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              )
            : null,
      ),
    );
  }

  void _showUserMenu(
      BuildContext context, SquadState squadState, String userName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserMenuSheet(
        userName: userName,
        squadState: squadState,
      ),
    );
  }

  void _showReactionMenu(BuildContext context, Map<String, dynamic> data) {
    HapticFeedback.mediumImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return MessageReactionDialog(
          message: widget.message,
          isMe: widget.isMe,
          data: data,
          onReply: () {
            if (!context.mounted) return;
            // Use ChatState for reply functionality
            final chatState = Provider.of<ChatState>(context, listen: false);
            chatState.setReplyToMessage(widget.message);
            Navigator.pop(context); // Close the reaction menu
          },
          onCopy: () {
            if (!context.mounted) return;
            Clipboard.setData(ClipboardData(text: data['content'] ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Text copied')),
            );
          },
          onDelete: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Message'),
                content:
                    const Text('Are you sure you want to delete this message?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              try {
                // Get squad state to determine collection path
                final squadState =
                    Provider.of<SquadState>(context, listen: false);
                final squadId = squadState.selectedSquadId;

                // Determine collection path based on chat type
                final collectionPath = widget.chatGroupId != null &&
                        squadId != null
                    ? 'squads/$squadId/chat_groups/${widget.chatGroupId}/messages'
                    : squadId != null
                        ? 'squads/$squadId/chat'
                        : 'chats';

                // Use Firestore directly to delete the message
                final messageId = data['id'];
                if (messageId != null) {
                  await FirebaseFirestore.instance
                      .collection(collectionPath)
                      .doc(messageId)
                      .delete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message deleted')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            }
          },
          onEmojiSelect: (emoji) => ReactionService.addReaction(
            context,
            emoji,
            _normalizedData['id']?.toString() ?? '',
            widget.chatGroupId,
          ),
          chatGroupId: widget.chatGroupId,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
    );
  }
}

class _UserMenuSheet extends StatelessWidget {
  final String userName;
  final SquadState squadState;

  const _UserMenuSheet({required this.userName, required this.squadState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // User's name
          Text(
            userName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          // Options
          _buildMenuItem(
            context,
            icon: Icons.videocam,
            label: 'Video Call',
            onTap: () {
              // TODO: Implement video call
              Navigator.pop(context);
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Video call not implemented yet')),
              // );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.call,
            label: 'Audio Call',
            onTap: () {
              // TODO: Implement audio call
              Navigator.pop(context);
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Audio call not implemented yet')),
              // );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.message,
            label: 'Message',
            onTap: () {
              // TODO: Open 1-on-1 message
              Navigator.pop(context);
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(
              //       content: Text('1-on-1 messaging not implemented yet')),
              // );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.block,
            label: 'Ban',
            onTap: () {
              Navigator.pop(context);
              squadState.addBan(userName, squadState.displayName ?? 'Unknown');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$userName has been voted for ban')),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.person_off,
            label: 'Block User',
            onTap: () async {
              Navigator.pop(context);
              await squadState.blockUser(userName);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$userName has been blocked')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(label),
      onTap: onTap,
    );
  }
}
