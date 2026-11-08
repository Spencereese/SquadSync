import 'package:audioplayers/audioplayers.dart';
import 'package:logger/logger.dart';
import 'interfaces.dart';

/// Victory sting played after a win. Path is relative to `assets/`.
const String kVictorySoundAsset = 'sounds/victory.mp3';

/// Asset path (audioplayers [AssetSource], relative to `assets/`) for a
/// streak sting, or null when the streak is too low to play anything.
String? achievementSoundAsset(int streak) {
  if (streak >= 10) return 'sounds/turducken.wav';
  if (streak >= 4) return 'sounds/duck.mp3';
  if (streak >= 3) return 'sounds/turkey.wav';
  return null;
}

/// Service for handling audio playback operations.
///
/// Uses audioplayers (same stack as chat audio messages) so the app has a
/// single playback plugin.
class AudioService implements IAudioService {
  AudioService({AudioPlayer? player}) : _audioPlayer = player ?? AudioPlayer();

  final Logger _logger = Logger();
  final AudioPlayer _audioPlayer;
  bool _isInitialized = false;

  /// Initialize the audio service
  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    // Audio player is already initialized in constructor
  }

  /// Play victory sound
  @override
  Future<void> playVictorySound() async {
    try {
      await _audioPlayer.play(AssetSource(kVictorySoundAsset));
    } catch (e) {
      _logger.e('Failed to play victory sound: $e');
    }
  }

  /// Play achievement sound based on streak level
  @override
  Future<void> playAchievementSound(int streak) async {
    final soundAsset = achievementSoundAsset(streak);
    if (soundAsset == null) return;

    try {
      await _audioPlayer.play(AssetSource(soundAsset));
    } catch (e) {
      _logger.e('Failed to play achievement sound: $e');
    }
  }

  /// Dispose of audio resources
  @override
  void dispose() {
    _audioPlayer.dispose();
  }
}
