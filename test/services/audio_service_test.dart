import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/audio_service.dart';
import 'package:squad_sync/services/interfaces.dart';

class _FakeAudioPlayer extends Fake implements AudioPlayer {
  final List<Source> plays = [];
  int disposeCount = 0;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    plays.add(source);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
  }
}

void main() {
  group('achievementSoundAsset', () {
    test('no sting below streak 3', () {
      expect(achievementSoundAsset(0), isNull);
      expect(achievementSoundAsset(1), isNull);
      expect(achievementSoundAsset(2), isNull);
    });

    test('turkey at streak 3', () {
      expect(achievementSoundAsset(3), 'sounds/turkey.wav');
    });

    test('duck from streak 4 through 9', () {
      expect(achievementSoundAsset(4), 'sounds/duck.mp3');
      expect(achievementSoundAsset(9), 'sounds/duck.mp3');
    });

    test('turducken at streak 10+', () {
      expect(achievementSoundAsset(10), 'sounds/turducken.wav');
      expect(achievementSoundAsset(99), 'sounds/turducken.wav');
    });
  });

  group('AudioService', () {
    test('implements IAudioService', () {
      final player = _FakeAudioPlayer();
      final service = AudioService(player: player);
      expect(service, isA<IAudioService>());
      service.dispose();
    });

    test('initialize is idempotent', () async {
      final service = AudioService(player: _FakeAudioPlayer());
      await service.initialize();
      await service.initialize();
      service.dispose();
    });

    test('playVictorySound plays the victory asset', () async {
      final player = _FakeAudioPlayer();
      final service = AudioService(player: player);
      await service.playVictorySound();
      expect(player.plays, hasLength(1));
      final source = player.plays.single as AssetSource;
      expect(source.path, kVictorySoundAsset);
      service.dispose();
    });

    test('playAchievementSound is a no-op below streak 3', () async {
      final player = _FakeAudioPlayer();
      final service = AudioService(player: player);
      await service.playAchievementSound(2);
      expect(player.plays, isEmpty);
      service.dispose();
    });

    test('playAchievementSound plays the mapped asset', () async {
      final player = _FakeAudioPlayer();
      final service = AudioService(player: player);
      await service.playAchievementSound(3);
      await service.playAchievementSound(4);
      await service.playAchievementSound(10);
      expect(
        player.plays.map((s) => (s as AssetSource).path),
        [
          'sounds/turkey.wav',
          'sounds/duck.mp3',
          'sounds/turducken.wav',
        ],
      );
      service.dispose();
    });

    test('dispose releases the player', () {
      final player = _FakeAudioPlayer();
      final service = AudioService(player: player);
      service.dispose();
      expect(player.disposeCount, 1);
    });
  });
}
