import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:pinch_zoom/pinch_zoom.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_theme.dart';
import '../../squad_state.dart';
import 'media_widgets.dart';
import 'reactions.dart';
import 'Reactions_picker.dart';
import 'chat_service.dart';
import 'chat_state.dart';

class MessageBubble extends StatelessWidget {
  final DocumentSnapshot message;
  final bool isMe;
  final bool showSender;
  final bool showAvatar;
  final bool showTimestamp;
  final bool showReadIndicator;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Map<String, bool> sendingStatus;
  final ChatService chatService; // Added as a parameter

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
    required this.chatService, // Required parameter
  });

  @override
  Widget build(BuildContext context) {
    final data = message.data() as Map<String, dynamic>? ?? {};
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        return Dismissible(
          key: Key(message.id),
          direction:
              isMe ? DismissDirection.endToStart : DismissDirection.startToEnd,
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart ||
                direction == DismissDirection.startToEnd) {
              Provider.of<ChatState>(context, listen: false)
                  .setReplyToMessage(message);
            }
          },
          background: Container(
              color: Colors.blue.withAlpha(51), child: const Icon(Icons.reply)),
          secondaryBackground: Container(
              color: Colors.blue.withAlpha(51), child: const Icon(Icons.reply)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showTimestamp && data['timestamp'] != null)
                  _buildTimestamp(data),
                Row(
                  mainAxisAlignment:
                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe)
                      _buildAvatar(
                          context, squadState, data['sender'] ?? 'Unknown'),
                    if (!isMe) const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (showSender) _buildSender(data),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onTap();
                            },
                            onLongPress: () => _showLongPressOptions(
                                context, message.id, data['text'] ?? ''),
                            child: _buildMessageContent(context, data),
                          ),
                          if (!isMe) ReactionsWidget(docId: message.id),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLongPressOptions(
      BuildContext context, String docId, String messageText) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => overlayEntry?.remove(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy - 60,
            width: size.width,
            child: ReactionPicker(
              docId: docId,
              onReactionSelected: (emoji) {
                chatService.addReaction(docId, emoji);
                overlayEntry?.remove();
              },
            ).animate().slideY(
                  begin: -0.5,
                  end: 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + size.height + 5,
            width: size.width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(
                      AppTheme.backgroundColor.red,
                      AppTheme.backgroundColor.green,
                      AppTheme.backgroundColor.blue,
                      0.9),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuButton(context, 'Reply', Icons.reply, () {
                      Provider.of<ChatState>(context, listen: false)
                          .setReplyToMessage(message);
                      overlayEntry?.remove();
                    }),
                    const SizedBox(width: 8),
                    _menuButton(context, 'Copy', Icons.copy, () {
                      Clipboard.setData(ClipboardData(text: messageText));
                      overlayEntry?.remove();
                    }),
                    const SizedBox(width: 8),
                    _menuButton(context, 'Delete', Icons.delete, () {
                      chatService.deleteMessage(docId);
                      overlayEntry?.remove();
                    }, color: AppTheme.errorColor),
                  ],
                ),
              ),
            ).animate().slideY(
                  begin: 0.5,
                  end: 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(overlayEntry);
  }

  Widget _menuButton(
      BuildContext context, String label, IconData icon, VoidCallback onTap,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.white, size: 24),
          Text(label,
              style: TextStyle(color: color ?? Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAvatar(
      BuildContext context, SquadState squadState, String sender) {
    String? profileImage = squadState.memberProfileImages[sender];
    if (profileImage == null ||
        profileImage.isEmpty ||
        !Uri.parse(profileImage).isAbsolute) {
      debugPrint('Avatar URL invalid for $sender: $profileImage');
      return Semantics(
        label: 'Avatar of $sender',
        child: const SizedBox(
          width: 32,
          height: 32,
          child: CircleAvatar(
            radius: 16,
            child: Icon(Icons.person, color: AppTheme.accentColor),
          ),
        ),
      );
    }
    return Semantics(
      label: 'Avatar of $sender',
      child: SizedBox(
        width: 32,
        height: 32,
        child: showAvatar
            ? Builder(
                builder: (context) {
                  debugPrint('Rendering avatar for $sender: $profileImage');
                  try {
                    return CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(profileImage),
                      onBackgroundImageError: (exception, stackTrace) {
                        debugPrint(
                            'Error loading avatar for $sender: $exception, $stackTrace');
                      },
                    );
                  } catch (e, stackTrace) {
                    debugPrint(
                        'Error rendering avatar for $sender: $e, $stackTrace');
                    return CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person, color: AppTheme.accentColor),
                    );
                  }
                },
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSender(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        data['sender'] ?? 'Unknown',
        style: TextStyle(
          color: AppTheme.accentColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimestamp(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Center(
        child: Semantics(
          label:
              'Message sent on ${DateFormat('MMMM d, yyyy, HH:mm').format((data['timestamp'] as Timestamp).toDate())}',
          child: Text(
            DateFormat('MMM d, yyyy, HH:mm')
                .format((data['timestamp'] as Timestamp).toDate()),
            style: const TextStyle(color: AppTheme.hintColor, fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Map<String, dynamic> data) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.accentColor.withAlpha(50)
            : AppTheme.hintColor.withAlpha(51),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Semantics(
        label: 'Message from ${data['sender'] ?? 'Unknown'}',
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (data['replyToContent'] != null)
              GestureDetector(
                onTap: () {
                  Provider.of<ChatState>(context, listen: false)
                      .scrollToMessage(data['replyToMessageId']);
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  margin: EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    data['replyToContent'],
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            if (data['text']?.isNotEmpty ?? false) _buildText(data['text']),
            if (data['imageUrl'] != null)
              _buildImage(context, data['imageUrl']),
            if (data['videoUrl'] != null)
              Builder(
                builder: (context) {
                  debugPrint('Rendering video message: ${data['videoUrl']}');
                  try {
                    return VideoMessage(url: data['videoUrl']);
                  } catch (e, stackTrace) {
                    debugPrint(
                        'Error rendering video message ${data['videoUrl']}: $e, $stackTrace');
                    return const SizedBox(
                      width: 150,
                      height: 150,
                      child: Icon(Icons.error, color: Colors.red),
                    );
                  }
                },
              ),
            if (data['audioUrl'] != null)
              Builder(
                builder: (context) {
                  debugPrint('Rendering audio message: ${data['audioUrl']}');
                  try {
                    return AudioMessage(url: data['audioUrl']);
                  } catch (e, stackTrace) {
                    debugPrint(
                        'Error rendering audio message ${data['audioUrl']}: $e, $stackTrace');
                    return const SizedBox(
                      width: 150,
                      height: 150,
                      child: Icon(Icons.error, color: Colors.red),
                    );
                  }
                },
              ),
            _buildMessageStatus(data),
          ],
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 300));
  }

  Widget _buildText(String text) {
    return Semantics(
      label: text,
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty ||
        !Uri.parse(imageUrl).isAbsolute ||
        imageUrl == 'null') {
      debugPrint('Invalid image URL: $imageUrl');
      return const SizedBox(
        width: 150,
        height: 150,
        child: Icon(Icons.broken_image, color: Colors.grey),
      );
    }
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(imageUrl);
        if (await canLaunchUrl(uri)) {
          HapticFeedback.lightImpact();
          await launchUrl(uri);
        } else {
          debugPrint('Could not launch URL: $imageUrl');
        }
      },
      child: PinchZoom(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Builder(
            builder: (context) {
              debugPrint('Rendering message image: $imageUrl');
              try {
                return CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    width: 150,
                    height: 150,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) {
                    debugPrint('Error loading image $url: $error');
                    return const SizedBox(
                      width: 150,
                      height: 150,
                      child: Icon(Icons.error, color: Colors.red),
                    );
                  },
                );
              } catch (e, stackTrace) {
                debugPrint('Error rendering image $imageUrl: $e, $stackTrace');
                return const SizedBox(
                  width: 150,
                  height: 150,
                  child: Icon(Icons.error, color: Colors.red),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMessageStatus(Map<String, dynamic> data) {
    if (sendingStatus[message.id] == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Semantics(
          label: 'Sending',
          child: const Icon(Icons.access_time, size: 12, color: Colors.white70),
        ),
      );
    }
    if (sendingStatus[message.id] == false) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Semantics(
          label: 'Message unsent',
          child: const Text(
            'Unsent',
            style: TextStyle(fontSize: 10, color: Colors.white70),
          ),
        ),
      );
    }
    if (showReadIndicator && !sendingStatus.containsKey(message.id)) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (data['delivered'] == true)
              Semantics(
                label: 'Delivered',
                child: const Text(
                  'Delivered',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
            if (data['read'] == true)
              Semantics(
                label: 'Read',
                child: const Icon(Icons.done_all, color: Colors.blue, size: 12),
              ).animate().scale(duration: const Duration(milliseconds: 300)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
