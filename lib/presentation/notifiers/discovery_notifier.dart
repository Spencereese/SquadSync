import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/squad.dart';

final discoveryFilterProvider =
    StateProvider<String>((ref) => 'hot'); // 'hot' | 'new' | gameId | 'friends'

final publicSquadsProvider = StreamProvider<List<Squad>>((ref) async* {
  final filter = ref.watch(discoveryFilterProvider);

  Query query = FirebaseFirestore.instance
      .collection('squads')
      .where('isPublic', isEqualTo: true);

  if (filter == 'hot') {
    query = query.orderBy('bumpTimestamp', descending: true);
  } else if (filter == 'new') {
    query = query.orderBy('createdAt', descending: true);
  } else {
    // game-specific
    query = query
        .where('primaryGameId', isEqualTo: filter)
        .orderBy('bumpTimestamp', descending: true);
  }

  await for (final snapshot in query.limit(50).snapshots()) {
    final squads = snapshot.docs
        .map((doc) => Squad.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
    yield squads;
  }
});

final popularGamesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('squads')
      .where('isPublic', isEqualTo: true)
      .get();

  final Map<String, int> counts = {};
  for (var doc in snapshot.docs) {
    final gameId = doc['primaryGameId'] as String?;
    if (gameId != null) counts[gameId] = (counts[gameId] ?? 0) + 1;
  }

  return counts.entries.map((e) => {'gameId': e.key, 'count': e.value}).toList()
    ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
});
