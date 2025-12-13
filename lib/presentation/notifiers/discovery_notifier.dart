import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lobby.dart';
import '../../core/injection.dart';
import '../../services/grok_service.dart';

final discoveryFilterProvider = StateProvider<String>(
    (ref) => 'hot'); // 'hot' | 'new' | gameId | 'friends' | 'ai-match'

final publicLobbiesProvider = StreamProvider<List<Lobby>>((ref) {
  final filter = ref.watch(discoveryFilterProvider);
  final repository = ref.watch(lobbyRepositoryProvider);

  // Determine filter parameters based on filter type
  String? gameFocus;
  String orderBy = 'created_at';
  int limit = 50;

  if (filter == 'hot') {
    // Hot lobbies: ordered by recent activity (created_at for now)
    orderBy = 'created_at';
    limit = 50;
  } else if (filter == 'new') {
    // New lobbies: ordered by creation date
    orderBy = 'created_at';
    limit = 50;
  } else {
    // Game-specific filter
    gameFocus = filter;
    orderBy = 'created_at';
    limit = 50;
  }

  // Use repository to get public lobbies stream
  return repository.getPublicLobbiesStream(
    isActive: true,
    gameFocus: gameFocus,
    limit: limit,
    orderBy: orderBy,
    ascending: false,
  );
});

final popularGamesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  // This could be optimized with a dedicated repository method
  // For now, we'll need to fetch all public lobbies and aggregate
  // TODO: Add getPopularGames method to LobbyRepository for better performance

  final repository = ref.watch(lobbyRepositoryProvider);

  // Get a snapshot of public lobbies (not real-time)
  // We'll use a workaround: listen to stream and take first value
  final lobbiesStream = repository.getPublicLobbiesStream(
    isActive: true,
    limit: 1000, // Get more for better aggregation
    orderBy: 'created_at',
    ascending: false,
  );

  final lobbies = await lobbiesStream.first;

  final Map<String, int> counts = {};
  for (var lobby in lobbies) {
    final gameName = lobby.gameName;
    counts[gameName] = (counts[gameName] ?? 0) + 1;
  }

  return counts.entries
      .map((e) => {'gameName': e.key, 'count': e.value})
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
});

/// AI Matchmaking provider - recommends lobbies based on user's pinned games and preferences
final aiMatchmakingProvider =
    FutureProvider.family<AiMatchmakingResponse, Map<String, dynamic>>(
  (ref, params) async {
    final grokService = GrokService();
    final repository = ref.watch(lobbyRepositoryProvider);

    // Get pinned games from params
    final pinnedGames =
        params['pinnedGames'] as List<Map<String, dynamic>>? ?? [];
    final userPreferences = params['userPreferences'] as Map<String, dynamic>?;

    // Get available public lobbies for AI analysis
    final lobbiesStream = repository.getPublicLobbiesStream(
      isActive: true,
      limit: 50,
      orderBy: 'created_at',
      ascending: false,
    );

    final lobbies = await lobbiesStream.first;

    // Convert lobbies to simple maps for API
    final availableLobbies = lobbies
        .map((lobby) => {
              'id': lobby.id,
              'gameName': lobby.gameName,
              'name': lobby.name,
              'description': lobby.description ?? '',
              'spotsOpen': lobby.spots.where((s) => s == null).length,
              'spotsTotal': lobby.maxSpots,
              'isActive': lobby.isActive,
              'memberCount': lobby.memberUids.length,
            })
        .toList();

    // Get AI matchmaking recommendations
    return await grokService.getAiMatchmaking(
      pinnedGames: pinnedGames,
      userPreferences: userPreferences,
      availableLobbies: availableLobbies,
    );
  },
);
