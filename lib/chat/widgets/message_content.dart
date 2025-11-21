import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../link_preview.dart';
import '../widgets/video_message.dart';
import '../widgets/audio_message.dart';
import '../poll_message_bubble.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';
import '../models/message_data.dart';
import '../../services/ai_service.dart';
import '../chat_service.dart';
import '../message_bubble.dart';

/// Message content renderer - handles text, media, and special formatting
class MessageContent extends StatelessWidget {
  final MessageData message;
  final bool isFromCurrentUser;
  final VoidCallback? onMediaTap;
  final String? chatGroupId;
  final ChatService? chatService;
  final ChatType? chatType;

  const MessageContent({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.onMediaTap,
    this.chatGroupId,
    this.chatService,
    this.chatType,
  });

  @override
  Widget build(BuildContext context) {
    if (!message.hasContent) {
      return const Text(
        '[Empty Message]',
        style: TextStyle(fontSize: 14, color: Colors.white70),
      );
    }

    // If this is a poll message, show the poll
    if (message.pollId?.isNotEmpty == true) {
      return _buildPollContent();
    }

    // Build content column
    return Column(
      crossAxisAlignment:
          isFromCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (message.replyTo?.isNotEmpty == true)
          FutureBuilder<MessageData?>(
            future: chatService?.getMessageById(message.replyTo!,
                chatGroupId: chatGroupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border(
                      left: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Loading reply...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              final repliedMessage = snapshot.data;
              if (repliedMessage == null) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border(
                      left: BorderSide(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 3.0,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Original message not found',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              // Determine if the replied message is from the current user
              final currentUserUid =
                  FirebaseAuth.instance.currentUser?.uid ?? '';
              final isRepliedMessageFromMe =
                  repliedMessage.senderUid == currentUserUid;

              return Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: MessageBubble(
                  message: repliedMessage,
                  isMe: isRepliedMessageFromMe,
                  showSender: !isRepliedMessageFromMe,
                  showAvatar: !isRepliedMessageFromMe,
                  showTimestamp: true,
                  showReadIndicator: false,
                  onTap: () {
                    // TODO: Implement scroll to message
                  },
                  onLongPress: () {},
                  sendingStatus: const {}, // Not applicable for quoted messages
                  chatGroupId: chatGroupId,
                  chatType: ChatType.squad, // Default to squad
                  chatService: chatService,
                ),
              );
            },
          ),
        if (message.text.isNotEmpty) _buildTextContent(context),
        if (message.photos.isNotEmpty) _buildImageContent(context),
        if (message.videoUrl?.isNotEmpty == true) _buildVideoContent(),
        if (message.audioUrl?.isNotEmpty == true) _buildAudioContent(),
        // Add subtle status indicators for sent messages
        if (isFromCurrentUser) _buildStatusIndicators(),
      ],
    );
  }

  Widget _buildPollContent() {
    return FutureBuilder<Poll?>(
      future: PollService().getPoll(message.pollId!, chatGroupId: chatGroupId),
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
          chatGroupId: chatGroupId,
          isFromCurrentUser: isFromCurrentUser,
        );
      },
    );
  }

  Widget _buildTextContent(BuildContext context) {
    final urls = LinkDetector.extractUrls(message.text);

    return Column(
      crossAxisAlignment:
          isFromCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Message text: ${message.text}',
          child: RichTextWithLinks(
            text: message.text,
            style: TextStyle(
              fontSize: 16,
              color: isFromCurrentUser
                  ? Colors.white
                  : message.isAiResponse
                      ? Colors.white // White text for Grok messages
                      : Colors
                          .white70, // White for sent, light grey for received
              fontWeight: FontWeight.normal,
              backgroundColor: Colors.transparent,
            ),
            textAlign: TextAlign
                .start, // Always left-align text for better readability
            isMe: isFromCurrentUser,
          ),
        ),
        // Add link previews for the first URL found
        if (urls.isNotEmpty) _buildLinkPreview(urls.first),
      ],
    );
  }

  Widget _buildImageContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: _buildImage(context, message.photos[0]['uri']),
    );
  }

  Widget _buildVideoContent() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: VideoMessage(url: fixMediaUrl(message.videoUrl!)),
    );
  }

  Widget _buildAudioContent() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: AudioMessage(url: fixMediaUrl(message.audioUrl!)),
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

    return GestureDetector(
      onTap: () => _showFullScreenImage(context, fixedUrl),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 200, // Smaller within bubble
          maxHeight: 200,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
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
            errorWidget: (context, url, error) => Container(
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
            ),
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

  Widget _buildStatusIndicators() {
    if (!isFromCurrentUser) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtle delivery/read indicators
          if (message.status == MessageStatus.delivered ||
              message.status == MessageStatus.read)
            Icon(
              message.status == MessageStatus.read
                  ? Icons.done_all
                  : Icons.done,
              size: 12,
              color: message.status == MessageStatus.read
                  ? Colors.blue.withValues(alpha: 0.7)
                  : Colors.grey.withValues(alpha: 0.5),
            ),
          // Subtle timestamp for sent messages
          if (message.status != MessageStatus.sending)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}

String fixMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return url.startsWith('http')
      ? url
      : 'https://storage.googleapis.com/squadsync-media/$url';
}
