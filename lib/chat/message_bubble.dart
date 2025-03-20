import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'chat_service.dart';
import 'chat_state.dart';
import '../../app_theme.dart';

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
    final data = message.data() as Map<String, dynamic>;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender) _buildSender(),
                if (showTimestamp && message['timestamp'] != null)
                  _buildTimestamp(),
                _buildMessageContent(context, data),
                if (!isMe) _buildReactions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return SizedBox(
      width: 32,
      height: 32,
      child: showAvatar ? const UserAvatar() : const SizedBox.shrink(),
    );
  }

  Widget _buildSender() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        message['sender'],
        style: TextStyle(
          color: AppTheme.accentColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTimestamp() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Center(
        child: Text(
          DateFormat('MMM d, yyyy, HH:mm')
              .format((message['timestamp'] as Timestamp).toDate()),
          style: const TextStyle(color: AppTheme.hintColor, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isMe
              ? AppTheme.accentColor.withAlpha(50)
              : AppTheme.hintColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (data['text']?.isNotEmpty ?? false) _buildText(data['text']),
            if (data['imageUrl'] != null) _buildImage(data['imageUrl']),
            if (data['videoUrl'] != null) VideoMessage(url: data['videoUrl']),
            if (data['audioUrl'] != null) AudioMessage(url: data['audioUrl']),
            _buildMessageStatus(),
          ],
        ),
      ).animate().fadeIn(duration: const Duration(milliseconds: 300)),
    );
  }

  Widget _buildText(String text) =>
      Text(text, style: const TextStyle(fontSize: 16));

  Widget _buildImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _launchUrl(imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
          placeholder: (context, url) => const CircularProgressIndicator(),
          errorWidget: (context, url, error) => const Icon(Icons.error),
        ),
      ),
    );
  }

  Widget _buildMessageStatus() {
    if (sendingStatus[message.id] == true) {
      return const Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: Icon(Icons.access_time, size: 12),
      );
    }
    if (sendingStatus[message.id] == false) {
      return const Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: Text('Unsent', style: TextStyle(fontSize: 10)),
      );
    }
    if (showReadIndicator && !sendingStatus.containsKey(message.id)) {
      return const Padding(
        padding: EdgeInsets.only(top: 4.0),
        child: Icon(Icons.done_all, color: Colors.blue, size: 12),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildReactions() => ReactionsWidget(docId: message.id);

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircleAvatar(radius: 16);
        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final url = userData?['profilePictureUrl'];
        return CircleAvatar(
          radius: 16,
          backgroundImage: url != null ? NetworkImage(url) : null,
          child: url == null ? const Text('U') : null,
        );
      },
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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.url)
      ..initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
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
                const Icon(Icons.play_circle_filled,
                    size: 50, color: Colors.white70),
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
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
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

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _setupListeners();
  }

  void _setupListeners() {
    _player.onDurationChanged.listen((d) => setState(() => _duration = d));
    _player.onPositionChanged.listen((p) => setState(() => _position = p));
    _player.onPlayerStateChanged.listen(
        (state) => setState(() => _isPlaying = state == PlayerState.playing));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: AppTheme.hintColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: AppTheme.accentColor,
              size: 30,
            ),
            onPressed: _togglePlay,
          ),
          Expanded(
            child: Slider(
              value: _position.inSeconds.toDouble(),
              min: 0,
              max: _duration.inSeconds.toDouble(),
              onChanged: (value) =>
                  _player.seek(Duration(seconds: value.toInt())),
              activeColor: AppTheme.accentColor,
              inactiveColor: AppTheme.hintColor,
            ),
          ),
          Text(
            "${_position.inSeconds ~/ 60}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }
}

class ReactionsWidget extends StatelessWidget {
  final String docId;
  const ReactionsWidget({super.key, required this.docId});

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
        final reactionCounts = <String, int>{};
        for (var reaction in reactions) {
          final emoji = reaction['emoji'] as String;
          reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
        }

        return Padding(
          padding: const EdgeInsets.only(left: 40.0, top: 4.0),
          child: Wrap(
            spacing: 4,
            children: reactionCounts.entries
                .map((entry) => ReactionChip(
                      emoji: entry.key,
                      count: entry.value,
                      onTap: () => _addReaction(docId, entry.key),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _addReaction(String docId, String emoji) async {
    final user = FirebaseAuth.instance.currentUser!.displayName;
    final querySnapshot = await FirebaseFirestore.instance
        .collection('chat')
        .doc(docId)
        .collection('reactions')
        .where('user', isEqualTo: user)
        .get();

    await Future.wait(querySnapshot.docs.map((doc) => doc.reference.delete()));

    await FirebaseFirestore.instance
        .collection('chat')
        .doc(docId)
        .collection('reactions')
        .add({
      'emoji': emoji,
      'user': user,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

class ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final VoidCallback onTap;

  const ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$emoji $count',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
