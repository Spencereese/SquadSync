import 'package:just_audio/just_audio.dart';
import 'interfaces.dart';

/// Service for handling audio playback operations
class AudioService implements IAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
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
      await _audioPlayer.setAsset('sounds/victory.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print('Failed to play victory sound: $e');
    }
  }

  /// Play achievement sound based on streak level
  @override
  Future<void> playAchievementSound(int streak) async {
    try {
      String soundAsset;
      if (streak >= 10) {
        soundAsset = 'sounds/turducken.wav';
      } else if (streak >= 4) {
        soundAsset = 'sounds/duck.mp3';
      } else if (streak >= 3) {
        soundAsset = 'sounds/turkey.wav';
      } else {
        return; // No sound for lower streaks
      }

      await _audioPlayer.setAsset(soundAsset);
      await _audioPlayer.play();
    } catch (e) {
      print('Failed to play achievement sound: $e');
    }
  }

  /// Dispose of audio resources
  @override
  void dispose() {
    _audioPlayer.dispose();
  }
}
