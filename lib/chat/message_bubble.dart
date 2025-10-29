import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:cod_squad_app/app_theme.dart';
import '../squad_state.dart';
import 'chat_state.dart';
import 'link_preview.dart';
import 'poll_message_bubble.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';
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
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
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
                            Positioned(
                              bottom: -10,
                              left: widget.isMe ? -10 : null,
                              right: widget.isMe ? null : -10,
                              child: ReactionsWidget(
                                reactions: _normalizedData['reactions'] ?? [],
                                isMe: widget.isMe,
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

  Map<String, dynamic> _normalizeMessage(dynamic message) {
    if (message is DocumentSnapshot) {
      final data = message.data() as Map<String, dynamic>? ?? {};
      final isAiResponse = data['isAiResponse'] ?? false;
      final senderUid = data['senderUid'] ?? '';
      return {
        'id': message.id,
        'sender': isAiResponse && senderUid == 'grok-ai'
            ? 'Grok 🤖'
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
      };
    }
    return {
      'id': '',
      'sender': 'Unknown',
      'content': '[Invalid Message]',
      'text': '[Invalid Message]'
    };
  }

  Widget _buildSender(Map<String, dynamic> data) {
    final isAiResponse = data['isAiResponse'] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        data['sender'] ?? 'Unknown',
        style: TextStyle(
          color: isAiResponse
              ? Colors.blueAccent.withValues(alpha: 0.9) // Special color for AI
              : Colors.cyanAccent.withValues(alpha: 0.8), // Regular sender color
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
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        constraints: const BoxConstraints(maxWidth: 280), // Limit max width
        decoration: BoxDecoration(
          color: widget.isMe
              ? const Color(
                  0xFF005C4B) // WhatsApp-style green for sent messages
              : const Color(0xFF202C33), // Dark grey for received messages
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: widget.isMe
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: widget.isMe
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Semantics(
          label: 'Message from ${data['sender'] ?? 'Unknown'}',
          child: contentWidget,
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
                  : Colors.white70, // White for sent, light grey for received
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
        return _MessageReactionDialog(
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
          onEmojiSelect: (emoji) => _addReaction(context, emoji),
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

  Future<void> _addReaction(BuildContext context, String emoji) async {
    try {
      final messageId = _normalizedData['id']?.toString();
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null ||
          messageId == null ||
          messageId.isEmpty ||
          emoji.isEmpty) {
        debugPrint(
            'Invalid reaction data: userId=$userId, messageId=$messageId, emoji="$emoji"');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to add reaction: Invalid data')),
          );
        }
        return;
      }

      // Get squad state to determine collection path
      final squadState = Provider.of<SquadState>(context, listen: false);
      final squadId = squadState.selectedSquadId;

      if (squadId == null) {
        debugPrint('Reaction failed: No squad ID available');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to add reaction: No squad context')),
          );
        }
        return;
      }

      // Determine collection path based on chat type
      final collectionPath = widget.chatGroupId != null
          ? 'squads/$squadId/chat_groups/${widget.chatGroupId}/messages'
          : 'squads/$squadId/chat';

      debugPrint(
          'Adding reaction: emoji=$emoji, messageId=$messageId, collection=$collectionPath');

      try {
        debugPrint('About to get document snapshot...');
        final docSnapshot = await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(messageId)
            .get();
        debugPrint(
            'Document snapshot retrieved, exists: ${docSnapshot.exists}');

        if (!docSnapshot.exists) {
          debugPrint('Message not found: $messageId in $collectionPath');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message not found')),
            );
          }
          return;
        }

        debugPrint('About to get message data...');
        final messageData = docSnapshot.data();
        debugPrint(
            'Message data retrieved: ${messageData != null ? 'not null' : 'null'}');

        if (messageData == null) {
          debugPrint('Message data is null: $messageId in $collectionPath');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message data unavailable')),
            );
          }
          return;
        }
        debugPrint('Message data keys: ${messageData.keys.toList()}');

        // Normalize reactions data - handle both old string format and new map format
        debugPrint('About to get raw reactions...');
        final rawReactions = messageData['reactions'];
        debugPrint(
            'Raw reactions retrieved: $rawReactions, type: ${rawReactions.runtimeType}');
        final currentReactions = <Map<String, dynamic>>[];

        if (rawReactions is List) {
          debugPrint(
              'Raw reactions is List, processing ${rawReactions.length} items...');
          for (final reaction in rawReactions) {
            debugPrint(
                'Processing reaction: $reaction, type: ${reaction.runtimeType}');
            if (reaction is Map<String, dynamic>) {
              // New format
              currentReactions.add(reaction);
            } else if (reaction is String) {
              // Old format - convert to new format
              currentReactions.add({
                'userId': 'unknown', // We don't know who added old reactions
                'reaction': reaction,
                'timestamp': DateTime.now()
                    .millisecondsSinceEpoch, // Use numeric timestamp
              });
            }
            // Skip invalid reaction types
          }
        } else {
          debugPrint('Raw reactions is not a List: $rawReactions');
        }

        debugPrint('Current reactions after processing: $currentReactions');

        // Check if user already reacted with this emoji (be more robust with type checking)
        debugPrint('About to check existing reactions...');
        int existingReactionIndex = -1;
        try {
          existingReactionIndex = currentReactions.indexWhere(
            (reaction) {
              final reactionUserId = reaction['userId']?.toString();
              final reactionEmoji = reaction['reaction']?.toString();
              return reactionUserId == userId && reactionEmoji == emoji;
            },
          );
        } catch (e) {
          debugPrint('Error checking existing reactions: $e');
          // If we can't check, assume no existing reaction
          existingReactionIndex = -1;
        }

        // Create a clean, validated reaction object
        final newReaction = <String, dynamic>{
          'userId': userId,
          'reaction': emoji.trim(),
          'timestamp': DateTime.now()
              .millisecondsSinceEpoch, // Use numeric timestamp instead of FieldValue
        };

        // Always use the set with merge fallback for iOS compatibility
        final updatedReactions =
            List<Map<String, dynamic>>.from(currentReactions);

        if (existingReactionIndex != -1) {
          // User already reacted with this emoji, remove it
          updatedReactions.removeAt(existingReactionIndex);
        } else {
          // User hasn't reacted with this emoji, add it
          updatedReactions.add(newReaction);
        }

        // Filter out any invalid reactions and limit to reasonable number
        final cleanReactions = <Map<String, dynamic>>[];
        try {
          cleanReactions.addAll(updatedReactions
              .where((r) {
                try {
                  return r['userId']?.toString().isNotEmpty == true &&
                      r['reaction']?.toString().isNotEmpty == true;
                } catch (e) {
                  debugPrint('Error validating reaction: $e, reaction: $r');
                  return false;
                }
              })
              .take(50)
              .toList()); // Limit reactions per message
        } catch (e) {
          debugPrint('Error filtering reactions: $e');
          // If filtering fails, use the updated reactions as-is (limited)
          cleanReactions.addAll(updatedReactions.take(50));
        }

        try {
          debugPrint(
              'About to update Firestore with reactions: $cleanReactions');
          await FirebaseFirestore.instance
              .collection(collectionPath)
              .doc(messageId)
              .set({'reactions': cleanReactions}, SetOptions(merge: true));
          debugPrint('Firestore set successful');
        } catch (firestoreError) {
          debugPrint('Firestore set failed, trying update: $firestoreError');
          // Fallback: try update operation
          try {
            await FirebaseFirestore.instance
                .collection(collectionPath)
                .doc(messageId)
                .update({'reactions': cleanReactions});
          } catch (updateError) {
            debugPrint('Update also failed: $updateError');
            // Final fallback: don't update reactions but don't crash
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reaction saved locally')),
              );
            }
            return;
          }
        }

        HapticFeedback.lightImpact();
      } catch (e) {
        debugPrint('Error during Firestore operations: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error accessing message: $e')),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Error updating reaction: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update reaction: ${e.toString()}')),
        );
      }
    }
  }
}

class _MessageReactionDialog extends StatefulWidget {
  final dynamic message;
  final bool isMe;
  final Map<String, dynamic> data;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final Function(String) onEmojiSelect;
  final String? chatGroupId;

  const _MessageReactionDialog({
    required this.message,
    required this.isMe,
    required this.data,
    required this.onReply,
    required this.onCopy,
    required this.onDelete,
    required this.onEmojiSelect,
    this.chatGroupId,
  });

  @override
  _MessageReactionDialogState createState() => _MessageReactionDialogState();
}

class _MessageReactionDialogState extends State<_MessageReactionDialog> {
  final TextEditingController _reactionController = TextEditingController();
  bool _showReactionInput = false;

  @override
  void dispose() {
    _reactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Container(
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emoji reactions row (above message, iMessage-style)
                Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...['❤️', '👍', '😂', '😢', '😡', '😮'].map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onEmojiSelect(emoji);
                              Navigator.pop(context);
                            },
                            child: AnimatedScale(
                              scale: 1.0,
                              duration: const Duration(milliseconds: 100),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 28),
                              ),
                            ),
                          ),
                        ).animate().scale(
                              duration: const Duration(milliseconds: 300),
                              begin: const Offset(0.8, 0.8),
                              end: const Offset(1.0, 1.0),
                              curve: Curves.elasticOut,
                              delay: Duration(
                                  milliseconds: 50 *
                                      ['❤️', '👍', '😂', '😢', '😡', '😮']
                                          .indexOf(emoji)),
                            );
                      }),
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _showReactionInput = !_showReactionInput;
                            });
                          },
                          child: AnimatedScale(
                            scale: 1.0,
                            duration: const Duration(milliseconds: 100),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _showReactionInput ? Icons.close : Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(
                      duration: const Duration(milliseconds: 400),
                      begin: -0.2,
                      end: 0.0,
                      curve: Curves.easeOutBack,
                    ),
                // Message preview (smaller, more subtle)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    constraints: const BoxConstraints(maxWidth: 300),
                    decoration: BoxDecoration(
                      color: widget.isMe
                          ? AppTheme.accentColor.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: widget.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.data['content']?.isNotEmpty ?? false)
                          Text(
                            widget.data['content'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (widget.data['photos']?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[700],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.white54,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(
                      duration: const Duration(milliseconds: 300),
                      delay: const Duration(milliseconds: 100),
                    ),
                // Custom reaction input
                if (_showReactionInput)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 12.0),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: TextField(
                          controller: _reactionController,
                          decoration: InputDecoration(
                            hintText: 'Type your reaction...',
                            hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12.0),
                          ),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              widget.onEmojiSelect(value);
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ),
                    ),
                  ).animate().slideY(
                        duration: const Duration(milliseconds: 300),
                        begin: 0.2,
                        end: 0.0,
                        curve: Curves.easeOutBack,
                      ),
                // Action buttons (more subtle, bottom sheet style)
                Container(
                  margin: const EdgeInsets.only(top: 16.0),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionTile(
                            icon: Icons.reply,
                            label: 'Reply',
                            onTap: () {
                              Navigator.pop(context);
                              widget.onReply();
                            },
                          ),
                          Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.1)),
                          _buildActionTile(
                            icon: Icons.copy,
                            label: 'Copy',
                            onTap: () {
                              Navigator.pop(context);
                              widget.onCopy();
                            },
                          ),
                          Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.1)),
                          _buildActionTile(
                            icon: Icons.delete,
                            label: 'Delete',
                            onTap: () {
                              Navigator.pop(context);
                              widget.onDelete();
                            },
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(
                      duration: const Duration(milliseconds: 400),
                      begin: 0.3,
                      end: 0.0,
                      curve: Curves.easeOutBack,
                      delay: const Duration(milliseconds: 200),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isDestructive
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoMessage extends StatefulWidget {
  final String url;
  const VideoMessage({super.key, required this.url});

  @override
  State<VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<VideoMessage> {
  late VideoPlayerController _controller;
  bool _isError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Loading video: ${widget.url}'); // Log for debug
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _isError = true;
          });
        }
        debugPrint('Video init error: $e for URL: ${widget.url}');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Container(
        width: 120,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 20),
            SizedBox(height: 4),
            Text(
              'Video failed',
              style: TextStyle(fontSize: 12, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (!_isInitialized) {
      return Container(
        width: 120,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap: () => _launchUrl(widget.url),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200, maxHeight: 150),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoPlayer(_controller),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Semantics(
                label: 'Play video',
                child: const Icon(Icons.play_circle_filled,
                    size: 40, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      HapticFeedback.lightImpact();
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch $url');
    }
  }
}

class AudioMessage extends StatefulWidget {
  final String url;
  const AudioMessage({super.key, required this.url});

  @override
  State<AudioMessage> createState() => _AudioMessageState();
}

class _AudioMessageState extends State<AudioMessage> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Loading audio: ${widget.url}'); // Log for debug
    _player = AudioPlayer();
    _setupListeners();
    _player.setSource(UrlSource(widget.url)).catchError((e) {
      if (mounted) {
        setState(() {
          _isError = true;
        });
      }
      debugPrint('Audio init error: $e for URL: ${widget.url}');
    });
  }

  void _setupListeners() {
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerStateChanged.listen(
        (state) => setState(() => _isPlaying = state == PlayerState.playing));
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey[800]!.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text(
              'Audio failed to load',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey[800]!.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: _isPlaying ? 'Pause audio' : 'Play audio',
            child: IconButton(
              icon: Icon(
                _isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                color: AppTheme.accentColor,
                size: 28,
              ),
              onPressed: _togglePlay,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _position.inSeconds.toDouble(),
                  min: 0,
                  max: _duration.inSeconds.toDouble() > 0
                      ? _duration.inSeconds.toDouble()
                      : 1,
                  onChanged: (value) =>
                      _player.seek(Duration(seconds: value.toInt())),
                  activeColor: AppTheme.accentColor,
                  inactiveColor: Colors.grey[600],
                ),
                Semantics(
                  label:
                      'Audio position ${_position.inMinutes}:${_position.inSeconds % 60} of ${_duration.inMinutes}:${_duration.inSeconds % 60}',
                  child: Text(
                    "${_position.inSeconds ~/ 60}:${(_position.inSeconds % 60).toString().padLeft(2, '0')} / ${_duration.inSeconds ~/ 60}:${(_duration.inSeconds % 60).toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlay() async {
    HapticFeedback.lightImpact();
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume(); // Use resume for safety after seek/pause
    }
  }
}

class ReactionsWidget extends StatelessWidget {
  final List<dynamic> reactions;
  final bool isMe;

  const ReactionsWidget(
      {super.key, required this.reactions, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group reactions by emoji and count them
    final reactionCounts = <String, int>{};
    for (final reaction in reactions) {
      if (reaction is Map<String, dynamic>) {
        final emoji = reaction['reaction'] as String?;
        if (emoji != null) {
          reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
        }
      } else if (reaction is String) {
        reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
      }
    }

    if (reactionCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort reactions by count (highest first) and then by emoji
    final sortedReactions = reactionCounts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : a.key.compareTo(b.key);
      });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sortedReactions.map((entry) {
        final emoji = entry.key;
        final count = entry.value;

        return Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[800]!.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 12),
              ),
              if (count > 1) ...[
                const SizedBox(width: 2),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: const Duration(milliseconds: 200));
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call not implemented yet')),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.call,
            label: 'Audio Call',
            onTap: () {
              // TODO: Implement audio call
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Audio call not implemented yet')),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.message,
            label: 'Message',
            onTap: () {
              // TODO: Open 1-on-1 message
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('1-on-1 messaging not implemented yet')),
              );
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
