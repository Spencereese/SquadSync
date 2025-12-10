import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../domain/entities/lobby.dart';

final discoveryFilterProvider =
    StateProvider<String>((ref) => 'hot'); // 'hot' | 'new' | gameId | 'friends'

final publicSquadsProvider = StreamProvider<List<Lobby>>((ref) async* {
  final filter = ref.watch(discoveryFilterProvider);

  // Build Supabase query based on filter
  late final Stream<List<Map<String, dynamic>>> query;

  if (filter == 'hot') {
    query = SupabaseService.client
        .from('squads')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('bump_timestamp', ascending: false)
        .limit(50);
  } else if (filter == 'new') {
    query = SupabaseService.client
        .from('squads')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(50);
  } else {
    // game-specific filter - filter in-memory after receiving stream
    final baseQuery = SupabaseService.client
        .from('squads')
        .stream(primaryKey: ['id'])
        .eq('is_public', true)
        .order('bump_timestamp', ascending: false)
        .limit(100); // Get more to filter

    query = baseQuery.map((data) => data
        .where((squad) => squad['primary_game_id'] == filter)
        .take(50)
        .toList());
  }

  await for (final data in query) {
    final squads = data.map((json) => Squad.fromJson(json)).toList();
    yield squads;
  }
});

final popularGamesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await SupabaseService.client
      .from('squads')
      .select('primary_game_id')
      .eq('is_public', true);

  final Map<String, int> counts = {};
  for (var row in data) {
    final gameId = row['primary_game_id'] as String?;
    if (gameId != null) counts[gameId] = (counts[gameId] ?? 0) + 1;
  }

  return counts.entries.map((e) => {'gameId': e.key, 'count': e.value}).toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
});
