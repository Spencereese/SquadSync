import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app_theme.dart';

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
      ..initialize().then((_) => setState(() {})).catchError((e) {
        setState(() => _isError = true);
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
                width: 150, height: 150, child: Icon(Icons.error)))
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
                            child: VideoPlayer(_controller))),
                    Semantics(
                        label: 'Play video',
                        child: const Icon(Icons.play_circle_filled,
                            size: 50, color: Colors.white70)),
                  ],
                ),
              )
            : const SizedBox(
                width: 150,
                height: 150,
                child: Center(child: CircularProgressIndicator()));
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      HapticFeedback.lightImpact();
      await launchUrl(uri);
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
      setState(() => _isError = true);
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
            child: const SizedBox(width: 200, child: Icon(Icons.error)))
        : Container(
            width: 200,
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
                color: AppTheme.hintColor.withAlpha(51),
                borderRadius: BorderRadius.circular(12)),
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
                            size: 30),
                        onPressed: _togglePlay)),
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
                        inactiveColor: AppTheme.hintColor)),
                Semantics(
                    label:
                        'Audio position ${_position.inMinutes}:${_position.inSeconds % 60}',
                    child: Text(
                        "${_position.inSeconds ~/ 60}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70))),
              ],
            ),
          );
  }

  Future<void> _togglePlay() async {
    HapticFeedback.lightImpact();
    if (_isPlaying)
      await _player.pause();
    else
      await _player.play(UrlSource(widget.url));
  }
}
