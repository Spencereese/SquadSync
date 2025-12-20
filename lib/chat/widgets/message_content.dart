import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import '../link_preview.dart';
import '../widgets/video_message.dart';
import '../widgets/audio_message.dart';
import '../poll_message_bubble.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';
import '../models/message_data.dart' hide MessageType;
import '../../domain/entities/message.dart' hide Poll;
import '../../services/message_service.dart';
import '../../presentation/notifiers/chat_notifier.dart' as cn;

/// Message content renderer - handles text, media, and special formatting
class MessageContent extends ConsumerWidget {
  final MessageData message;
  final bool isFromCurrentUser;
  final VoidCallback? onMediaTap;
  final String? chatGroupId;
  final MessageService? chatService;
  final ChatType? chatType;
  final String? squadId;

  const MessageContent({
    super.key,
    required this.message,
    required this.isFromCurrentUser,
    this.onMediaTap,
    this.chatGroupId,
    this.chatService,
    this.chatType,
    this.squadId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Removed excessive debug logging that was spamming console on every build
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
          _buildReplyPreview(context, ref),
        if (message.text.isNotEmpty) _buildTextContent(context),
        if (message.photos.isNotEmpty) _buildImageContent(context),
        if (message.videoUrl?.isNotEmpty == true) _buildVideoContent(),
        if (message.audioUrl?.isNotEmpty == true) _buildAudioContent(),
        // Add subtle status indicators for sent messages
        if (isFromCurrentUser) _buildStatusIndicators(),
      ],
    );
  }

  /// Build Messenger-style reply preview
  Widget _buildReplyPreview(BuildContext context, WidgetRef ref) {
    if (message.replyTo == null || chatGroupId == null) {
      return const SizedBox.shrink();
    }

    // Fetch the replied message from the message list
    final chatState = ref.watch(cn.chatNotifierProvider);

    return chatState.when(
      data: (state) {
        final messages = state.chatMessages[chatGroupId] ?? [];
        final repliedMsg = messages.cast<Message?>().firstWhere(
              (msg) => msg?.id == message.replyTo,
              orElse: () => null,
            );

        if (repliedMsg == null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8.0),
              border: Border(
                left: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.5),
                  width: 3.0,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.reply_rounded,
                  size: 14,
                  color: Colors.grey.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Message not found',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }

        // Messenger-style compact reply preview
        final authService = AuthServiceSupabase();
        final currentUserUid = authService.currentUserId ?? '';
        final isRepliedByCurrentUser = repliedMsg.senderId == currentUserUid;

        // Build the preview UI with FutureBuilder to fetch display name
        return FutureBuilder<String?>(
          future: isRepliedByCurrentUser
              ? Future.value('You')
              : SupabaseService.client
                  .from('users')
                  .select('display_name')
                  .eq('uid', repliedMsg.senderId)
                  .maybeSingle()
                  .then((response) =>
                      response?['display_name'] as String? ??
                      repliedMsg.senderId),
          builder: (context, snapshot) {
            final resolvedDisplayName = snapshot.data ?? 'Unknown';

            return GestureDetector(
              onTap: () {
                // TODO: Scroll to original message
                debugPrint(
                    'Tapped reply preview - scroll to message: ${message.replyTo}');
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.7),
                      width: 3.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply_rounded,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resolvedDisplayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            repliedMsg.text.isNotEmpty
                                ? repliedMsg.text
                                : _getMediaTypeLabel(repliedMsg),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (repliedMsg.mediaUrl != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: _getMediaTypeIcon(repliedMsg),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Loading reply...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _getMediaTypeLabel(Message msg) {
    switch (msg.messageType) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.voiceNote:
        return '🎤 Voice message';
      case MessageType.file:
        return '📎 File';
      case MessageType.poll:
        return '📊 Poll';
      default:
        return '[Media]';
    }
  }

  Widget _getMediaTypeIcon(Message msg) {
    IconData icon;
    switch (msg.messageType) {
      case MessageType.image:
        icon = Icons.image;
        break;
      case MessageType.video:
        icon = Icons.videocam;
        break;
      case MessageType.audio:
        icon = Icons.audiotrack;
        break;
      case MessageType.voiceNote:
        icon = Icons.mic;
        break;
      default:
        icon = Icons.insert_drive_file;
    }
    return Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 20);
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
              color: Colors.white,
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
            memCacheWidth: 400, // 2x for retina
            memCacheHeight: 400,
            fadeInDuration: const Duration(milliseconds: 100),
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
                memCacheWidth: 1080,
                memCacheHeight: 1920,
                fadeInDuration: const Duration(milliseconds: 150),
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
          // Timestamp removed from inside bubbles as requested
        ],
      ),
    );
  }
}

String fixMediaUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return url.startsWith('http')
      ? url
      : 'https://storage.googleapis.com/lobbiesync-media/$url';
}
