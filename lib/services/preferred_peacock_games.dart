import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/lobby_state.dart';

/// Preferred Peacock Games: persist + filter only.
///
/// Empty set is unfiltered (all peacock offers pass). A non-empty set keeps
/// offers whose game is in the set. Not a matchmaking rewrite.
const kPreferredPeacockGamesPrefsKey = 'preferred_peacock_games';

bool peacockOfferAllowed({
  required String? gameName,
  required Set<String> preferredPeacockGames,
}) {
  if (preferredPeacockGames.isEmpty) return true;
  final game = gameName?.trim() ?? '';
  if (game.isEmpty) return false;
  return preferredPeacockGames.contains(game);
}

/// Game names shown on the existing Preferred Peacock Games chips.
List<String> preferredPeacockGameChoices(LobbyState? state) {
  if (state == null) return const [];
  final names = <String>{};
  void add(String? raw) {
    final name = raw?.trim() ?? '';
    if (name.isNotEmpty) names.add(name);
  }

  for (final game in state.availableGames) {
    add(game['name']?.toString());
  }
  add(state.currentGame?['name']?.toString());
  for (final name in state.gameLobbies.keys) {
    add(name);
  }
  names.addAll(state.preferredPeacockGames);
  for (final lobby in state.userLobbies.values) {
    add(lobby.gameName);
  }
  final sorted = names.toList()..sort();
  return sorted;
}

LobbyState overlayPreferredPeacockGames(
  LobbyState loaded, {
  Set<String>? preferred,
}) {
  final games = preferred ?? PreferredPeacockGamesStore.instance.snapshot;
  if (setEquals(loaded.preferredPeacockGames, games)) return loaded;
  return loaded.copyWith(preferredPeacockGames: games);
}

/// In-memory + SharedPreferences. [LobbyNotifier] hydrates LobbyState.
class PreferredPeacockGamesStore {
  PreferredPeacockGamesStore();

  static const prefsKey = kPreferredPeacockGamesPrefsKey;

  static final PreferredPeacockGamesStore instance =
      PreferredPeacockGamesStore();

  final Set<String> games = {};

  Set<String> get snapshot => Set<String>.from(games);

  bool contains(String gameName) {
    final name = gameName.trim();
    if (name.isEmpty) return false;
    return games.contains(name);
  }

  Future<void> toggle(String gameName) async {
    final name = gameName.trim();
    if (name.isEmpty) return;
    if (!games.add(name)) {
      games.remove(name);
    }
    await save();
  }

  Future<void> replaceAll(Iterable<String> names) async {
    games
      ..clear()
      ..addAll(names.map((n) => n.trim()).where((n) => n.isNotEmpty));
    await save();
  }

  /// First run: copy the existing LobbyState field into prefs.
  Future<void> seedIfEmpty(Iterable<String> fromState) async {
    if (games.isNotEmpty) return;
    final seeded = fromState.map((n) => n.trim()).where((n) => n.isNotEmpty);
    if (seeded.isEmpty) return;
    games.addAll(seeded);
    await save();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(prefsKey);
      if (stored == null) return;
      games
        ..clear()
        ..addAll(stored.map((n) => n.trim()).where((n) => n.isNotEmpty));
    } catch (e) {
      debugPrint('PreferredPeacockGamesStore.load failed: $e');
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, games.toList());
    } catch (e) {
      debugPrint('PreferredPeacockGamesStore.save failed: $e');
    }
  }

  @visibleForTesting
  void reset() {
    games.clear();
  }
}

Future<LobbyState> syncPreferredPeacockGames(LobbyState loaded) async {
  final store = PreferredPeacockGamesStore.instance;
  await store.seedIfEmpty(loaded.preferredPeacockGames);
  return overlayPreferredPeacockGames(loaded, preferred: store.snapshot);
}
