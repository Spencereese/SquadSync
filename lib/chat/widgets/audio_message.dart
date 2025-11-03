import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cod_squad_app/app_theme.dart';

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
