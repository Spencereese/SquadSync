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
import 'package:pinch_zoom/pinch_zoom.dart';
import 'dart:ui';
import '../../app_theme.dart';
import '../../squad_state.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final data = message.data() as Map<String, dynamic>? ?? {};
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        return Padding(
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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildMessageContent(context, data),
                            Positioned(
                              bottom: -10,
                              left: isMe ? -10 : null,
                              right: isMe ? null : -10,
                              child: ReactionsWidget(
                                  docId: message.id, isMe: isMe),
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

  Widget _buildAvatar(
      BuildContext context, SquadState squadState, String sender) {
    String? profileImage = squadState.memberProfileImages[sender];
    return Semantics(
      label: 'Avatar of $sender',
      child: SizedBox(
        width: 32,
        height: 32,
        child: showAvatar
            ? CircleAvatar(
                radius: 16,
                backgroundImage:
                    profileImage != null ? NetworkImage(profileImage) : null,
                child: profileImage == null
                    ? Text(sender.isNotEmpty ? sender[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.accentColor))
                    : null,
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
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTimestamp(Map<String, dynamic> data) {
    final timestamp = (data['timestamp'] as Timestamp).toDate();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Center(
        child: Semantics(
          label:
              'Message sent on ${DateFormat('MMMM d, yyyy, h:mm a').format(timestamp)}',
          child: Text(
            DateFormat('MMM d, yyyy, h:mm a').format(timestamp),
            style: const TextStyle(
              color: AppTheme.hintColor,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      onLongPress: () => _showReactionMenu(context, data),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.accentColor.withValues(alpha: 0.2)
              : AppTheme.hintColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Semantics(
          label: 'Message from ${data['sender'] ?? 'Unknown'}',
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (data['text']?.isNotEmpty ?? false) _buildText(data['text']),
              if (data['imageUrl'] != null)
                _buildImage(context, data['imageUrl']),
              if (data['videoUrl'] != null) VideoMessage(url: data['videoUrl']),
              if (data['audioUrl'] != null) AudioMessage(url: data['audioUrl']),
              _buildMessageStatus(data),
            ],
          ),
        ),
      ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
    );
  }

  Widget _buildText(String text) {
    return Semantics(
      label: 'Message text: $text',
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String imageUrl) {
    return GestureDetector(
      onTap: () => _launchUrl(imageUrl),
      child: PinchZoom(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: 150,
            height: 150,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error),
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
          label: 'Message is sending',
          child: const Icon(Icons.access_time, size: 12, color: Colors.white70),
        ),
      );
    }
    if (sendingStatus[message.id] == false) {
      return Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Semantics(
          label: 'Message failed to send',
          child: const Text('Unsent',
              style: TextStyle(fontSize: 10, color: Colors.white70)),
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
                label: 'Message delivered',
                child: const Text('Delivered',
                    style: TextStyle(fontSize: 10, color: Colors.white70)),
              ).animate().fadeIn(duration: const Duration(milliseconds: 500)),
            if (data['read'] == true)
              Semantics(
                label: 'Message read',
                child: const Icon(Icons.done_all, color: Colors.blue, size: 12),
              ).animate().scale(duration: const Duration(milliseconds: 300)),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
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
          message: message,
          isMe: isMe,
          data: data,
          onReply: () {
            if (!context.mounted) return;
            Provider.of<SquadState>(context, listen: false)
                .setReplyingTo(message);
          },
          onCopy: () {
            if (!context.mounted) return;
            Clipboard.setData(ClipboardData(text: message['text'] ?? ''));
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
                await Provider.of<SquadState>(context, listen: false)
                    .deleteMessage(message.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete message: $e')),
                  );
                }
              }
            }
          },
          onEmojiSelect: (emoji) => _addReaction(context, emoji),
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
    onLongPress();
  }

  Future<void> _addReaction(BuildContext context, String emoji) async {
    final user = FirebaseAuth.instance.currentUser!.displayName ??
        Provider.of<SquadState>(context, listen: false).displayName ??
        'User';
    final querySnapshot = await FirebaseFirestore.instance
        .collection('chat')
        .doc(message.id)
        .collection('reactions')
        .where('user', isEqualTo: user)
        .get();

    await Future.wait(querySnapshot.docs.map((doc) => doc.reference.delete()));
    await FirebaseFirestore.instance
        .collection('chat')
        .doc(message.id)
        .collection('reactions')
        .add({
      'emoji': emoji,
      'user': user,
      'timestamp': FieldValue.serverTimestamp(),
    });
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

class _MessageReactionDialog extends StatefulWidget {
  final DocumentSnapshot message;
  final bool isMe;
  final Map<String, dynamic> data;
  final VoidCallback onReply;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final Function(String) onEmojiSelect;

  const _MessageReactionDialog({
    required this.message,
    required this.isMe,
    required this.data,
    required this.onReply,
    required this.onCopy,
    required this.onDelete,
    required this.onEmojiSelect,
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
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Focused Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Transform.scale(
                    scale: 1.05,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: widget.isMe
                            ? AppTheme.accentColor.withValues(alpha: 0.3)
                            : AppTheme.hintColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: widget.isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (widget.data['text']?.isNotEmpty ?? false)
                            Text(
                              widget.data['text'],
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.white),
                            ),
                          if (widget.data['imageUrl'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: widget.data['imageUrl'],
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error),
                              ),
                            ),
                          if (widget.data['videoUrl'] != null)
                            VideoMessage(url: widget.data['videoUrl']),
                          if (widget.data['audioUrl'] != null)
                            AudioMessage(url: widget.data['audioUrl']),
                        ],
                      ),
                    ),
                  ),
                ),
                // Reaction Picker
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...['❤️', '👍', '😂', '😢', '😡'].map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
                                style: const TextStyle(fontSize: 32),
                              ),
                            ),
                          ),
                        ).animate().scale(
                              duration: const Duration(milliseconds: 200),
                              begin: Offset.zero,
                              end: const Offset(1.0, 1.0),
                              curve: Curves.easeOutBack,
                            );
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: IconButton(
                          icon: Icon(
                            _showReactionInput ? Icons.close : Icons.add,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () {
                            setState(() {
                              _showReactionInput = !_showReactionInput;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Custom Reaction Input
                if (_showReactionInput)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Material(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      child: TextField(
                        controller: _reactionController,
                        decoration: InputDecoration(
                          hintText: 'Type your reaction',
                          hintStyle: TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.grey[900],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            widget.onEmojiSelect(value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ),
                // Action Buttons
                Material(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  elevation: 2,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading:
                              const Icon(Icons.reply, color: Colors.white70),
                          title: const Text('Reply',
                              style: TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onReply();
                          },
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.copy, color: Colors.white70),
                          title: const Text('Copy',
                              style: TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onCopy();
                          },
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.delete, color: Colors.white70),
                          title: const Text('Delete',
                              style: TextStyle(color: Colors.white)),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onDelete();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
      }).catchError((e) {
        setState(() {
          _isError = true;
        });
        debugPrint('Video init error: $e');
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _isError
        ? Semantics(
            label: 'Video failed to load',
            child: const SizedBox(
              width: 150,
              height: 150,
              child: Icon(Icons.error),
            ),
          )
        : _controller.value.isInitialized
            ? GestureDetector(
                onTap: () => _launchUrl(widget.url),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                    Semantics(
                      label: 'Play video',
                      child: const Icon(Icons.play_circle_filled,
                          size: 50, color: Colors.white70),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: const Duration(milliseconds: 300))
            : const SizedBox(
                width: 150,
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              );
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
    _player = AudioPlayer();
    _setupListeners();
    _player.setSourceUrl(widget.url).catchError((e) {
      setState(() {
        _isError = true;
      });
      debugPrint('Audio init error: $e');
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
    return _isError
        ? Semantics(
            label: 'Audio failed to load',
            child: const SizedBox(
              width: 200,
              child: Icon(Icons.error),
            ),
          )
        : Container(
            width: 200,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: AppTheme.hintColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Semantics(
                  label: _isPlaying ? 'Pause audio' : 'Play audio',
                  child: IconButton(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: AppTheme.accentColor,
                      size: 30,
                    ),
                    onPressed: _togglePlay,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _position.inSeconds.toDouble(),
                    min: 0,
                    max: _duration.inSeconds.toDouble() > 0
                        ? _duration.inSeconds.toDouble()
                        : 1,
                    onChanged: (value) =>
                        _player.seek(Duration(seconds: value.toInt())),
                    activeColor: AppTheme.accentColor,
                    inactiveColor: AppTheme.hintColor,
                  ),
                ),
                Semantics(
                  label:
                      'Audio position ${_position.inMinutes}:${_position.inSeconds % 60}',
                  child: Text(
                    "${_position.inSeconds ~/ 60}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
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
      await _player.play(UrlSource(widget.url));
    }
  }
}

class ReactionsWidget extends StatelessWidget {
  final String docId;
  final bool isMe;

  const ReactionsWidget({super.key, required this.docId, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .doc(docId)
          .collection('reactions')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final reactions = snapshot.data!.docs;
        String? latestEmoji;
        if (reactions.isNotEmpty) {
          latestEmoji = reactions.last['emoji'] as String?;
        }

        return latestEmoji != null
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  latestEmoji,
                  style: const TextStyle(fontSize: 14),
                ),
              ).animate().scale(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                )
            : const SizedBox.shrink();
      },
    );
  }
}
