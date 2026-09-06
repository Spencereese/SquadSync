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

/// Swap the video_player initialize in tests (load fail / retry).
typedef SessionClipInitialize = Future<void> Function();

/// Open the ticket-9 gallery/http clip via existing video_player media.
///
/// Not a clips product: no comments, hype, or chat group. Skip when there is
/// no `video_url` on the rated-session notes. Missing clip is a no-op (You /
/// stats last-5 shows [kSessionClipUnavailableCopy]); load fail / offline
/// still opens the dialog so Retry can re-attempt.
Future<bool> openSessionClipMedia(
  BuildContext context,
  SessionClip clip, {
  SessionClipPlayerBuilder? playerBuilder,
  LaunchSessionClipUrl? launchUrlFn,
  SessionClipInitialize? initialize,
  bool isOffline = false,
}) async {
  if (!canOpenSessionClip(clip)) return false;
  if (!context.mounted) return false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => SessionClipPlaybackDialog(
      clip: clip,
      playerBuilder: playerBuilder,
      launchUrlFn: launchUrlFn,
      initialize: initialize,
      isOffline: isOffline,
    ),
  );
  return true;
}

/// Empty You/stats last-5 (or a row without media) is a no-op, not a crash.
Future<bool> openSessionClipFromYouStats(
  BuildContext context, {
  List<SessionRatingState>? sessions,
  int index = 0,
  SessionClipPlayerBuilder? playerBuilder,
  LaunchSessionClipUrl? launchUrlFn,
  SessionClipInitialize? initialize,
  bool isOffline = false,
}) async {
  final clip = sessionClipFromYouStats(sessions: sessions, index: index);
  if (!canOpenSessionClip(clip)) return false;
  return openSessionClipMedia(
    context,
    clip!,
    playerBuilder: playerBuilder,
    launchUrlFn: launchUrlFn,
    initialize: initialize,
    isOffline: isOffline,
  );
}

class SessionClipPlaybackDialog extends StatefulWidget {
  const SessionClipPlaybackDialog({
    super.key,
    required this.clip,
    this.playerBuilder,
    this.launchUrlFn,
    this.initialize,
    this.isOffline = false,
  });

  final SessionClip clip;
  final SessionClipPlayerBuilder? playerBuilder;
  final LaunchSessionClipUrl? launchUrlFn;
  final SessionClipInitialize? initialize;
  final bool isOffline;

  @override
  State<SessionClipPlaybackDialog> createState() =>
      _SessionClipPlaybackDialogState();
}

class _SessionClipPlaybackDialogState extends State<SessionClipPlaybackDialog> {
  late SessionClipPlaybackState _state;

  @override
  void initState() {
    super.initState();
    _state = reduceSessionClipPlayback(
      current: SessionClipPlaybackState.missing,
      event: SessionClipPlaybackEvent.open,
      clip: widget.clip,
      isOffline: widget.isOffline,
    );
  }

  void _retry() {
    setState(() {
      _state = reduceSessionClipPlayback(
        current: _state,
        event: SessionClipPlaybackEvent.retry,
        clip: widget.clip,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final phase = _state.phase;
    final url = sessionClipMediaUrl(clip);
    final network = sessionClipIsNetworkMedia(clip);
    final showPlayer = url != null &&
        (phase == SessionClipPlaybackPhase.ready ||
            phase == SessionClipPlaybackPhase.loading);
    final player = showPlayer
        ? (widget.playerBuilder?.call(url) ??
            SessionClipPlayer(
              url: url,
              initialize: widget.initialize,
            ))
        : SessionClipPlaybackStatus(
            phase: phase == SessionClipPlaybackPhase.loading
                ? SessionClipPlaybackPhase.loading
                : phase,
            error: _state.error,
            onRetry: _state.canRetry ? _retry : null,
          );
    return AlertDialog(
      key: const Key('session-clip-playback'),
      title: Text(sessionClipPlaybackTitle(clip)),
      content: SizedBox(
        width: 320,
        child: player,
      ),
      actions: [
        if (network && showPlayer)
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
    final launch = widget.launchUrlFn ?? _launchExternal;
    await launch(uri);
  }
}

/// Empty / error / retry body for clip playback. Missing has no Retry.
class SessionClipPlaybackStatus extends StatelessWidget {
  const SessionClipPlaybackStatus({
    super.key,
    required this.phase,
    this.error,
    this.onRetry,
  });

  final SessionClipPlaybackPhase phase;
  final Object? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (phase == SessionClipPlaybackPhase.loading) {
      return const SizedBox(
        key: Key('session-clip-player-loading'),
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final retry = onRetry != null && sessionClipPlaybackCanRetry(phase);
    return SizedBox(
      key: sessionClipPlaybackFeedbackKey(phase),
      height: retry ? 180 : 120,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              phase == SessionClipPlaybackPhase.missing
                  ? Icons.movie_outlined
                  : Icons.error,
              color: phase == SessionClipPlaybackPhase.missing
                  ? Colors.white54
                  : Colors.redAccent,
            ),
            const SizedBox(height: 8),
            Text(
              sessionClipPlaybackMessage(phase),
              textAlign: TextAlign.center,
            ),
            if (sessionClipPlaybackHint(phase) != null) ...[
              const SizedBox(height: 4),
              Text(
                sessionClipPlaybackHint(phase)!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            if (sessionRatingErrorDetail(error).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sessionRatingErrorDetail(error),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
            if (retry) ...[
              const SizedBox(height: 12),
              TextButton(
                key: sessionClipPlaybackRetryKey(phase),
                onPressed: onRetry,
                child: const Text(kSessionClipRetryLabel),
              ),
            ],
          ],
        ),
      ),
    );
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
  const SessionClipPlayer({
    super.key,
    required this.url,
    this.initialize,
    this.isOffline = false,
  });

  final String url;
  final SessionClipInitialize? initialize;
  final bool isOffline;

  @override
  State<SessionClipPlayer> createState() => _SessionClipPlayerState();
}

class _SessionClipPlayerState extends State<SessionClipPlayer> {
  VideoPlayerController? _controller;
  Object? _loadError;
  bool _isError = false;
  bool _isOffline = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _isOffline = widget.isOffline;
    if (_isOffline) {
      _isError = true;
    } else {
      _beginLoad();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _beginLoad() async {
    try {
      if (widget.initialize != null) {
        await widget.initialize!();
      } else {
        _controller?.dispose();
        _controller = videoControllerForSessionClipUrl(widget.url);
        await _controller!.initialize();
        if (!mounted) return;
        await _controller!.play();
      }
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _loadError = e;
        _isOffline = sessionClipPlaybackIsOfflineError(e);
      });
    }
  }

  void _retry() {
    setState(() {
      _isError = false;
      _isInitialized = false;
      _isOffline = false;
      _loadError = null;
    });
    _beginLoad();
  }

  void _togglePlay() {
    final controller = _controller;
    if (!_isInitialized || _isError || controller == null) return;
    HapticFeedback.lightImpact();
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      final phase = _isOffline
          ? SessionClipPlaybackPhase.offline
          : SessionClipPlaybackPhase.loadFailed;
      return SessionClipPlaybackStatus(
        phase: phase,
        error: _loadError,
        onRetry: _retry,
      );
    }
    if (!_isInitialized) {
      return const SessionClipPlaybackStatus(
        phase: SessionClipPlaybackPhase.loading,
      );
    }
    if (widget.initialize != null || _controller == null) {
      return const SizedBox(
        key: Key('session-clip-player'),
        height: 120,
        child: Center(
          child: Icon(
            Icons.play_circle_filled,
            size: 48,
            color: Colors.white,
          ),
        ),
      );
    }
    final controller = _controller!;
    final playing = controller.value.isPlaying;
    return GestureDetector(
      key: const Key('session-clip-player'),
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio == 0
            ? 16 / 9
            : controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
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
