import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/domain/entities/game.dart';

void main() {
  group('Game Entity', () {
    const testGame = Game(
      name: 'Call of Duty: Modern Warfare',
      slug: 'call-of-duty-modern-warfare',
      igdbId: 12345,
      coverUrl: 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg',
      summary: 'A first-person shooter game',
      firstReleaseDate: null,
      genres: ['Shooter', 'Action'],
      platforms: ['PC', 'PlayStation', 'Xbox'],
      maxSpots: 4,
      isCached: false,
      cachedAt: null,
    );

    test('should create Game with required fields', () {
      expect(testGame.name, 'Call of Duty: Modern Warfare');
      expect(testGame.slug, 'call-of-duty-modern-warfare');
      expect(testGame.igdbId, 12345);
      expect(testGame.genres, ['Shooter', 'Action']);
      expect(testGame.platforms, ['PC', 'PlayStation', 'Xbox']);
      expect(testGame.maxSpots, 4);
      expect(testGame.isCached, false);
    });

    test('should support equality', () {
      const game1 = Game(
        name: 'Test Game',
        slug: 'test-game',
        igdbId: 1,
        coverUrl: null,
        summary: null,
        firstReleaseDate: null,
        genres: [],
        platforms: [],
        maxSpots: null,
        isCached: false,
        cachedAt: null,
      );

      const game2 = Game(
        name: 'Test Game',
        slug: 'test-game',
        igdbId: 1,
        coverUrl: null,
        summary: null,
        firstReleaseDate: null,
        genres: [],
        platforms: [],
        maxSpots: null,
        isCached: false,
        cachedAt: null,
      );

      expect(game1, equals(game2));
    });

    test('should support hashCode', () {
      const game1 = Game(
        name: 'Test Game',
        slug: 'test-game',
        igdbId: 1,
        coverUrl: null,
        summary: null,
        firstReleaseDate: null,
        genres: [],
        platforms: [],
        maxSpots: null,
        isCached: false,
        cachedAt: null,
      );

      const game2 = Game(
        name: 'Test Game',
        slug: 'test-game',
        igdbId: 1,
        coverUrl: null,
        summary: null,
        firstReleaseDate: null,
        genres: [],
        platforms: [],
        maxSpots: null,
        isCached: false,
        cachedAt: null,
      );

      expect(game1.hashCode, equals(game2.hashCode));
    });

    test('should support copyWith', () {
      final copied = testGame.copyWith(
        name: 'Call of Duty: Warzone',
        maxSpots: 6,
      );

      expect(copied.name, 'Call of Duty: Warzone');
      expect(copied.slug, testGame.slug);
      expect(copied.maxSpots, 6);
      expect(copied.genres, testGame.genres);
    });

    test('should serialize to JSON', () {
      final json = testGame.toJson();

      expect(json['name'], 'Call of Duty: Modern Warfare');
      expect(json['slug'], 'call-of-duty-modern-warfare');
      expect(json['igdbId'], 12345);
      expect(json['coverUrl'], 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg');
      expect(json['summary'], 'A first-person shooter game');
      expect(json['genres'], ['Shooter', 'Action']);
      expect(json['platforms'], ['PC', 'PlayStation', 'Xbox']);
      expect(json['maxSpots'], 4);
      expect(json['isCached'], false);
    });

    test('should deserialize from JSON', () {
      final json = {
        'name': 'Call of Duty: Modern Warfare',
        'slug': 'call-of-duty-modern-warfare',
        'igdbId': 12345,
        'coverUrl': 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg',
        'summary': 'A first-person shooter game',
        'firstReleaseDate': null,
        'genres': ['Shooter', 'Action'],
        'platforms': ['PC', 'PlayStation', 'Xbox'],
        'maxSpots': 4,
        'isCached': false,
        'cachedAt': null,
      };

      final game = Game.fromJson(json);

      expect(game, testGame);
    });

    test('should create from IGDB data', () {
      final igdbData = {
        'id': 12345,
        'name': 'Call of Duty: Modern Warfare',
        'slug': 'call-of-duty-modern-warfare',
        'cover': {
          'url': '//images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg'
        },
        'summary': 'A first-person shooter game',
        'first_release_date': 1577836800, // 2020-01-01
        'genres': [
          {'name': 'Shooter'},
          {'name': 'Action'}
        ],
        'platforms': [
          {'name': 'PC'},
          {'name': 'PlayStation 4'},
          {'name': 'Xbox One'}
        ],
      };

      final game = Game.fromIgdb(igdbData);

      expect(game.name, 'Call of Duty: Modern Warfare');
      expect(game.slug, 'call-of-duty-modern-warfare');
      expect(game.igdbId, 12345);
      expect(game.coverUrl, '//images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg');
      expect(game.summary, 'A first-person shooter game');
      expect(game.firstReleaseDate!.toUtc().year, 2020);
      expect(game.firstReleaseDate!.toUtc().month, 1);
      expect(game.firstReleaseDate!.toUtc().day, 1);
      expect(game.genres, ['Shooter', 'Action']);
      expect(game.platforms, ['PC', 'PlayStation 4', 'Xbox One']);
      expect(game.maxSpots, null);
      expect(game.isCached, false);
    });

    test('should handle null IGDB data gracefully', () {
      final igdbData = {
        'id': null,
        'name': null,
        'slug': null,
        'cover': null,
        'summary': null,
        'first_release_date': null,
        'genres': null,
        'platforms': null,
      };

      final game = Game.fromIgdb(igdbData);

      expect(game.name, '');
      expect(game.slug, '');
      expect(game.igdbId, null);
      expect(game.coverUrl, null);
      expect(game.summary, null);
      expect(game.firstReleaseDate, null);
      expect(game.genres, []);
      expect(game.platforms, []);
    });

    test('should create from cache data', () {
      final cacheData = {
        'name': 'Call of Duty: Modern Warfare',
        'slug': 'call-of-duty-modern-warfare',
        'igdbId': 12345,
        'coverUrl': 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg',
        'summary': 'A first-person shooter game',
        'firstReleaseDate': '2020-01-01T00:00:00.000',
        'genres': ['Shooter', 'Action'],
        'platforms': ['PC', 'PlayStation', 'Xbox'],
        'maxSpots': 4,
        'cachedAt': '2023-01-01T00:00:00.000',
      };

      final game = Game.fromCache(cacheData);

      expect(game.name, 'Call of Duty: Modern Warfare');
      expect(game.slug, 'call-of-duty-modern-warfare');
      expect(game.igdbId, 12345);
      expect(game.coverUrl, 'https://images.igdb.com/igdb/image/upload/t_cover_big/co1uqy.jpg');
      expect(game.summary, 'A first-person shooter game');
      expect(game.firstReleaseDate!.toUtc().year, 2020);
      expect(game.firstReleaseDate!.toUtc().month, 1);
      expect(game.firstReleaseDate!.toUtc().day, 1);
      expect(game.genres, ['Shooter', 'Action']);
      expect(game.platforms, ['PC', 'PlayStation', 'Xbox']);
      expect(game.maxSpots, 4);
      expect(game.isCached, true);
      expect(game.cachedAt!.toUtc().year, 2023);
      expect(game.cachedAt!.toUtc().month, 1);
      expect(game.cachedAt!.toUtc().day, 1);
    });

    test('should handle edge cases in IGDB parsing', () {
      final igdbData = {
        'id': 12345,
        'name': 'Test Game',
        'slug': 'test-game',
        'genres': [
          {'name': 'Shooter'},
          {'name': null},
          {'name': ''},
        ],
        'platforms': [
          {'name': 'PC'},
          {'name': null},
        ],
      };

      final game = Game.fromIgdb(igdbData);

      expect(game.genres, ['Shooter']);
      expect(game.platforms, ['PC']);
    });
  });
}