import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Existing-media open hook for You / stats last-5 clip rows.
typedef OpenSessionClip = Future<bool> Function(
  BuildContext context,
  SessionClip clip,
);

/// Swap the video_player host in tests. Live path uses [SessionClipPlayer].
typedef SessionClipPlayerBuilder = Widget Function(String mediaUrl);

typedef LaunchSessionClipUrl = Future<bool> Function(Uri uri);

/// Open the ticket-9 gallery/http clip via existing video_player media.
///
/// Not a clips product: no comments, hype, or chat group. Skip when there is
/// no `video_url` on the rated-session notes.
Future<bool> openSessionClipMedia(
  BuildContext context,
  SessionClip clip, {
  SessionClipPlayerBuilder? playerBuilder,
  LaunchSessionClipUrl? launchUrlFn,
}) async {
  if (!canOpenSessionClip(clip)) return false;
  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => SessionClipPlaybackDialog(
      clip: clip,
      playerBuilder: playerBuilder,
      launchUrlFn: launchUrlFn,
    ),
  );
  return true;
}

class SessionClipPlaybackDialog extends StatelessWidget {
  const SessionClipPlaybackDialog({
    super.key,
    required this.clip,
    this.playerBuilder,
    this.launchUrlFn,
  });

  final SessionClip clip;
  final SessionClipPlayerBuilder? playerBuilder;
  final LaunchSessionClipUrl? launchUrlFn;

  @override
  Widget build(BuildContext context) {
    final url = sessionClipMediaUrl(clip)!;
    final player = playerBuilder?.call(url) ?? SessionClipPlayer(url: url);
    final network = sessionClipIsNetworkMedia(clip);
    return AlertDialog(
      key: const Key('session-clip-playback'),
      title: Text(sessionClipPlaybackTitle(clip)),
      content: SizedBox(
        width: 320,
        child: player,
      ),
      actions: [
        if (network)
          TextButton(
            key: const Key('session-clip-playback-open'),
            onPressed: () => _openExternal(clip),
            child: const Text('Open'),
          ),
        TextButton(
          key: const Key('session-clip-playback-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _openExternal(SessionClip clip) async {
    final uri = sessionClipMediaUri(clip);
    if (uri == null) return;
    final launch = launchUrlFn ?? _launchExternal;
    await launch(uri);
  }
}

Future<bool> _launchExternal(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  return false;
}

VideoPlayerController videoControllerForSessionClipUrl(String url) {
  final uri = uriForSessionClipMedia(url);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    return VideoPlayerController.networkUrl(uri);
  }
  final path =
      (uri != null && uri.scheme == 'file') ? uri.toFilePath() : url;
  return VideoPlayerController.file(File(path));
}

/// Existing video_player host (same stack as chat [VideoMessage]).
class SessionClipPlayer extends StatefulWidget {
  const SessionClipPlayer({super.key, required this.url});

  final String url;

  @override
  State<SessionClipPlayer> createState() => _SessionClipPlayerState();
}

class _SessionClipPlayerState extends State<SessionClipPlayer> {
  late final VideoPlayerController _controller;
  bool _isError = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = videoControllerForSessionClipUrl(widget.url);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isInitialized = true);
      _controller.play();
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _isError = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_isInitialized || _isError) return;
    HapticFeedback.lightImpact();
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return const SizedBox(
        key: Key('session-clip-player-error'),
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: Colors.redAccent),
              SizedBox(height: 8),
              Text('Can\'t play clip'),
            ],
          ),
        ),
      );
    }
    if (!_isInitialized) {
      return const SizedBox(
        key: Key('session-clip-player-loading'),
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final playing = _controller.value.isPlaying;
    return GestureDetector(
      key: const Key('session-clip-player'),
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio == 0
            ? 16 / 9
            : _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            if (!playing)
              const Icon(
                Icons.play_circle_filled,
                size: 48,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}
