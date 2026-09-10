import 'package:freezed_annotation/freezed_annotation.dart';

part 'game.freezed.dart';
part 'game.g.dart';

@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
class Game with _$Game {
  const factory Game({
    required String name,
    required String slug,
    required int? igdbId,
    required String? coverUrl,
    required String? summary,
    required DateTime? firstReleaseDate,
    required List<String> genres,
    required List<String> platforms,
    required int? maxSpots,
    required bool isCached,
    required DateTime? cachedAt,
  }) = _Game;

  factory Game.fromJson(Map<String, dynamic> json) => _$GameFromJson(json);

  factory Game.fromIgdb(Map<String, dynamic> data) {
    // Normalize IGDB cover URL (add https scheme and upscale from thumb)
    final rawCover = data['cover']?['url'];
    final processedCover = rawCover != null
        ? 'https:${rawCover.replaceAll('t_thumb', 't_cover_big')}'
        : null;
    return Game(
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      igdbId: data['id'],
      coverUrl: processedCover,
      summary: data['summary'],
      firstReleaseDate: data['first_release_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              data['first_release_date'] * 1000)
          : null,
      genres: (data['genres'] as List<dynamic>?)
              ?.map((g) => g['name'] as String? ?? '')
              .where((g) => g.isNotEmpty)
              .toList() ??
          [],
      platforms: (data['platforms'] as List<dynamic>?)
              ?.map((p) => p['name'] as String? ?? '')
              .where((p) => p.isNotEmpty)
              .toList() ??
          [],
      maxSpots: null,
      isCached: false,
      cachedAt: null,
    );
  }

  factory Game.fromCache(Map<String, dynamic> data) {
    // Ensure cached cover URLs have scheme and preferred size
    final cachedCover = data['coverUrl'];
    String? normalizedCover;
    if (cachedCover is String) {
      normalizedCover = cachedCover.startsWith('http')
          ? cachedCover.replaceAll('t_thumb', 't_cover_big')
          : 'https:${cachedCover.replaceAll('t_thumb', 't_cover_big')}';
    }
    return Game(
      name: data['name'] ?? '',
      slug: data['slug'] ?? '',
      igdbId: data['igdbId'],
      coverUrl: normalizedCover,
      summary: data['summary'],
      firstReleaseDate: data['firstReleaseDate'] != null
          ? DateTime.parse(data['firstReleaseDate'])
          : null,
      genres: List<String>.from(data['genres'] ?? []),
      platforms: List<String>.from(data['platforms'] ?? []),
      maxSpots: data['maxSpots'],
      isCached: true,
      cachedAt:
          data['cachedAt'] != null ? DateTime.parse(data['cachedAt']) : null,
    );
  }
}
