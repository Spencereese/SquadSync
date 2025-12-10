import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../domain/entities/lobby.dart';

final discoveryFilterProvider =
    StateProvider<String>((ref) => 'hot'); // 'hot' | 'new' | gameId | 'friends'

final publicLobbiesProvider = StreamProvider<List<Lobby>>((ref) async* {
  final filter = ref.watch(discoveryFilterProvider);

  // Build Supabase query based on filter
  late final Stream<List<Map<String, dynamic>>> query;

  if (filter == 'hot') {
    query = SupabaseService.client
        .from('lobbies')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(50)
        .map((data) =>
            data.where((lobby) => lobby['is_active'] == true).toList());
  } else if (filter == 'new') {
    query = SupabaseService.client
        .from('lobbies')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(50)
        .map((data) =>
            data.where((lobby) => lobby['is_active'] == true).toList());
  } else {
    // game-specific filter - filter in-memory after receiving stream
    final baseQuery = SupabaseService.client
        .from('lobbies')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(100); // Get more to filter

    query = baseQuery.map((data) => data
        .where((lobby) =>
            lobby['is_active'] == true && lobby['game_name'] == filter)
        .take(50)
        .toList());
  }

  await for (final data in query) {
    final lobbies = data.map((json) => Lobby.fromJson(json)).toList();
    yield lobbies;
  }
});

final popularGamesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await SupabaseService.client
      .from('lobbies')
      .select('game_name')
      .eq('is_public', true);

  final Map<String, int> counts = {};
  for (var row in data) {
    final gameName = row['game_name'] as String?;
    final isActive = row['is_active'] as bool? ?? true;
    if (gameName != null && isActive) {
      counts[gameName] = (counts[gameName] ?? 0) + 1;
    }
  }

  return counts.entries
      .map((e) => {'gameName': e.key, 'count': e.value})
      .toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
});
