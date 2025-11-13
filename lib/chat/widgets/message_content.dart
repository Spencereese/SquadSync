import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../link_preview.dart';
import '../widgets/video_message.dart';
import '../widgets/audio_message.dart';
import '../poll_message_bubble.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';
import '../models/message_data.dart';

/// Message content renderer - handles text, media, and special formatting
class MessageContent extends StatelessWidget {
  final MessageData message;
  final bool isFromCurrentUser;
  final VoidCallback? onMediaTap;
  final String? chatGroupId;

  const MessageContent({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.onMediaTap,
    this.chatGroupId,
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
        // Add reply indicator if this is a reply
        if (message.replyTo != null) _buildReplyIndicator(),
        if (message.text.isNotEmpty) _buildTextContent(context),
        if (message.photos.isNotEmpty) _buildImageContent(context),
        if (message.videoUrl?.isNotEmpty == true) _buildVideoContent(),
        if (message.audioUrl?.isNotEmpty == true) _buildAudioContent(),
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

  Widget _buildReplyIndicator() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchRepliedMessage(),
      builder: (context, snapshot) {
        final sender = snapshot.data?['sender'] ?? 'Unknown';
        final text = snapshot.data?['text'] ??
            snapshot.data?['content'] ??
            'Message not found';

        return Container(
          margin: const EdgeInsets.only(bottom: 4.0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.reply, size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replying to $sender',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[200],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchRepliedMessage() async {
    if (message.replyTo == null || chatGroupId == null) return null;

    try {
      // Determine the collection path based on chat type
      String collectionPath;
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return null;

      // For now, assume user group chats - this could be made more generic
      collectionPath = 'users/$userId/chat_groups/$chatGroupId/messages';

      final doc = await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(message.replyTo!)
          .get();

      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('Error fetching replied message: $e');
    }
    return null;
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
            textAlign: isFromCurrentUser ? TextAlign.end : TextAlign.start,
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
}

// Helper functions that were in the original file
String fixMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return url.startsWith('http')
      ? url
      : 'https://storage.googleapis.com/squadsync-media/$url';
}
