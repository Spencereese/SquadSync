import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/lobby_state.dart';

/// Preferred Peacock Games: persist + filter only.
///
/// Empty set is unfiltered (all peacock offers pass). A non-empty set keeps
/// offers whose game is in the set. Not a matchmaking rewrite.
const kPreferredPeacockGamesPrefsKey = 'preferred_peacock_games';

String? _trimmedGameName(String? raw) {
  final name = raw?.trim() ?? '';
  return name.isEmpty ? null : name;
}

bool peacockOfferAllowed({
  required String? gameName,
  required Set<String> preferredPeacockGames,
}) {
  if (preferredPeacockGames.isEmpty) return true;
  final game = _trimmedGameName(gameName);
  if (game == null) return false;
  if (preferredPeacockGames.contains(game)) return true;
  final needle = game.toLowerCase();
  for (final preferred in preferredPeacockGames) {
    final name = _trimmedGameName(preferred);
    if (name != null && name.toLowerCase() == needle) return true;
  }
  return false;
}

/// Prefs snapshot wins after a successful load (including an empty list).
/// LobbyState is only a first-run seed when the prefs key was never written.
Set<String> resolvedPreferredPeacockGames(LobbyState? lobbyState) {
  final store = PreferredPeacockGamesStore.instance;
  if (store.hasStoredPreference) return store.snapshot;
  final fromState = lobbyState?.preferredPeacockGames ?? const <String>{};
  if (fromState.isNotEmpty) return Set<String>.from(fromState);
  return store.snapshot;
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

/// Filter mapper for preferred peacock games.
///
/// Persist/load throw is [PreferredPeacockFilterOutcome.failed]. Empty
/// preferred is no-games-selected (offers stay unfiltered). Non-empty
/// preferred with no matching offers is no-matches. Retry is calling
/// [runPreferredPeacockFilter] again.
enum PreferredPeacockFilterOutcome { data, empty, failed }

enum PreferredPeacockFilterEmptyKind { none, noGamesSelected, noMatches }

const kPreferredPeacockGamesTitle = 'Preferred Peacock Games';
const kPreferredPeacockFilterRetryLabel = 'Retry';
const kPreferredPeacockFilterErrorCopy = "Couldn't update preferred games";
const kPreferredPeacockFilterErrorHint = 'Check your connection and try again.';
const kPreferredPeacockFilterNoCatalogCopy =
    'No games yet — add one to filter peacock offers';
const kPreferredPeacockFilterNoGamesSelectedCopy = 'No games selected';
const kPreferredPeacockFilterNoGamesSelectedHint =
    'Tap a game to filter peacock offers. None selected stays unfiltered.';
const kPreferredPeacockFilterNoMatchesCopy = 'No matching peacock offers';
const kPreferredPeacockFilterNoMatchesHint =
    'Queued offers do not match your preferred games.';

class PreferredPeacockFilterResult {
  const PreferredPeacockFilterResult.data(this.matches)
      : outcome = PreferredPeacockFilterOutcome.data,
        emptyKind = PreferredPeacockFilterEmptyKind.none,
        error = null;

  const PreferredPeacockFilterResult.empty({
    this.emptyKind = PreferredPeacockFilterEmptyKind.noGamesSelected,
    this.matches = const [],
  })  : outcome = PreferredPeacockFilterOutcome.empty,
        error = null;

  const PreferredPeacockFilterResult.failed(this.error,
      {this.matches = const []})
      : outcome = PreferredPeacockFilterOutcome.failed,
        emptyKind = PreferredPeacockFilterEmptyKind.none;

  final PreferredPeacockFilterOutcome outcome;
  final PreferredPeacockFilterEmptyKind emptyKind;
  final List<String> matches;
  final Object? error;

  bool get isData => outcome == PreferredPeacockFilterOutcome.data;
  bool get isEmpty => outcome == PreferredPeacockFilterOutcome.empty;
  bool get isFailed => outcome == PreferredPeacockFilterOutcome.failed;
}

class PreferredPeacockPersistResult {
  const PreferredPeacockPersistResult.ok() : error = null;
  const PreferredPeacockPersistResult.failed(this.error);

  final Object? error;

  bool get isOk => error == null;
  bool get isFailed => error != null;
}

Key preferredPeacockFilterKey(PreferredPeacockFilterResult result) {
  switch (result.outcome) {
    case PreferredPeacockFilterOutcome.data:
      return const Key('preferred-peacock-games');
    case PreferredPeacockFilterOutcome.empty:
      return result.emptyKind == PreferredPeacockFilterEmptyKind.noMatches
          ? const Key('preferred-peacock-games-empty-matches')
          : const Key('preferred-peacock-games-empty-selected');
    case PreferredPeacockFilterOutcome.failed:
      return const Key('preferred-peacock-games-error');
  }
}

Key preferredPeacockFilterHintKey(PreferredPeacockFilterResult result) {
  switch (result.outcome) {
    case PreferredPeacockFilterOutcome.failed:
      return const Key('preferred-peacock-games-error-hint');
    case PreferredPeacockFilterOutcome.empty:
      return result.emptyKind == PreferredPeacockFilterEmptyKind.noMatches
          ? const Key('preferred-peacock-games-empty-matches-hint')
          : const Key('preferred-peacock-games-empty-selected-hint');
    case PreferredPeacockFilterOutcome.data:
      return const Key('preferred-peacock-games');
  }
}

Key preferredPeacockFilterRetryKey() =>
    const Key('preferred-peacock-games-retry');

Key preferredPeacockFilterDetailKey() =>
    const Key('preferred-peacock-games-error-detail');

String preferredPeacockFilterMessage(PreferredPeacockFilterResult result) {
  switch (result.outcome) {
    case PreferredPeacockFilterOutcome.failed:
      return kPreferredPeacockFilterErrorCopy;
    case PreferredPeacockFilterOutcome.empty:
      return result.emptyKind == PreferredPeacockFilterEmptyKind.noMatches
          ? kPreferredPeacockFilterNoMatchesCopy
          : kPreferredPeacockFilterNoGamesSelectedCopy;
    case PreferredPeacockFilterOutcome.data:
      return kPreferredPeacockGamesTitle;
  }
}

String? preferredPeacockFilterHint(PreferredPeacockFilterResult result) {
  switch (result.outcome) {
    case PreferredPeacockFilterOutcome.failed:
      return kPreferredPeacockFilterErrorHint;
    case PreferredPeacockFilterOutcome.empty:
      return result.emptyKind == PreferredPeacockFilterEmptyKind.noMatches
          ? kPreferredPeacockFilterNoMatchesHint
          : kPreferredPeacockFilterNoGamesSelectedHint;
    case PreferredPeacockFilterOutcome.data:
      return null;
  }
}

String preferredPeacockFilterErrorDetail(Object? error) {
  if (error == null) return '';
  final text = error.toString().trim();
  if (text.isEmpty) return '';
  const prefix = 'Exception: ';
  if (text.startsWith(prefix) && text.length > prefix.length) {
    return text.substring(prefix.length);
  }
  return text;
}

/// Map preferred-games filter. Persist/load [error] wins. Empty preferred
/// is no-games-selected. Non-empty preferred with no matching offers is
/// no-matches. Offer gating still uses [peacockOfferAllowed].
PreferredPeacockFilterResult mapPreferredPeacockFilter({
  required Set<String> preferredPeacockGames,
  Iterable<String?> offerGameNames = const [],
  Object? error,
}) {
  if (error != null) {
    return PreferredPeacockFilterResult.failed(error);
  }
  if (preferredPeacockGames.isEmpty) {
    return const PreferredPeacockFilterResult.empty(
      emptyKind: PreferredPeacockFilterEmptyKind.noGamesSelected,
    );
  }
  final matches = <String>[];
  for (final raw in offerGameNames) {
    if (!peacockOfferAllowed(
      gameName: raw,
      preferredPeacockGames: preferredPeacockGames,
    )) {
      continue;
    }
    final name = _trimmedGameName(raw);
    if (name != null) matches.add(name);
  }
  if (matches.isEmpty) {
    return const PreferredPeacockFilterResult.empty(
      emptyKind: PreferredPeacockFilterEmptyKind.noMatches,
    );
  }
  return PreferredPeacockFilterResult.data(matches);
}

/// Map a persist/load attempt then the filter. Thrown write is error.
/// Retry is calling this again with the same persist.
Future<PreferredPeacockFilterResult> runPreferredPeacockFilter(
  Future<void> Function() persist, {
  required Set<String> preferredPeacockGames,
  Iterable<String?> offerGameNames = const [],
}) async {
  try {
    await persist();
  } catch (e) {
    return PreferredPeacockFilterResult.failed(e);
  }
  return mapPreferredPeacockFilter(
    preferredPeacockGames: preferredPeacockGames,
    offerGameNames: offerGameNames,
  );
}

Future<PreferredPeacockFilterResult> retryPreferredPeacockFilter(
  Future<void> Function() persist, {
  required Set<String> preferredPeacockGames,
  Iterable<String?> offerGameNames = const [],
}) =>
    runPreferredPeacockFilter(
      persist,
      preferredPeacockGames: preferredPeacockGames,
      offerGameNames: offerGameNames,
    );

/// Map a prefs persist/load. Thrown write is error. Retry is calling this
/// again.
Future<PreferredPeacockPersistResult> runPreferredPeacockPersist(
  Future<void> Function() persist,
) async {
  try {
    await persist();
    return const PreferredPeacockPersistResult.ok();
  } catch (e) {
    return PreferredPeacockPersistResult.failed(e);
  }
}

Future<PreferredPeacockPersistResult> retryPreferredPeacockPersist(
  Future<void> Function() persist,
) =>
    runPreferredPeacockPersist(persist);

/// In-memory + SharedPreferences. [LobbyNotifier] hydrates LobbyState.
class PreferredPeacockGamesStore {
  PreferredPeacockGamesStore();

  static const prefsKey = kPreferredPeacockGamesPrefsKey;

  static final PreferredPeacockGamesStore instance =
      PreferredPeacockGamesStore();

  final Set<String> games = {};

  /// True once SharedPreferences has a value for [prefsKey], including [].
  /// Distinguishes "never written" (seed from LobbyState) from "user cleared".
  bool _hydratedFromPrefs = false;
  bool _lastPersistWasSave = false;

  /// Last prefs persist/load error. Null after a successful write or load.
  Object? lastError;

  Set<String> get snapshot => Set<String>.from(games);

  bool get hasStoredPreference => _hydratedFromPrefs;

  bool contains(String gameName) {
    final name = _trimmedGameName(gameName);
    if (name == null || games.isEmpty) return false;
    if (games.contains(name)) return true;
    final needle = name.toLowerCase();
    for (final game in games) {
      if (game.toLowerCase() == needle) return true;
    }
    return false;
  }

  /// Record a persist/load failure from prefs or lobby-state save.
  void markError(Object error, {required bool wasSave}) {
    lastError = error;
    _lastPersistWasSave = wasSave;
  }

  Future<PreferredPeacockPersistResult> toggle(String gameName) async {
    final name = gameName.trim();
    if (name.isEmpty) {
      return lastError != null
          ? PreferredPeacockPersistResult.failed(lastError!)
          : const PreferredPeacockPersistResult.ok();
    }
    if (!games.add(name)) {
      games.remove(name);
    }
    return save();
  }

  Future<PreferredPeacockPersistResult> replaceAll(
      Iterable<String> names) async {
    games
      ..clear()
      ..addAll(names.map((n) => n.trim()).where((n) => n.isNotEmpty));
    return save();
  }

  /// First run: copy the existing LobbyState field into prefs.
  /// No-ops when the prefs key already exists — even as an empty list —
  /// so clearing chips stays unfiltered across launches.
  Future<PreferredPeacockPersistResult> seedIfEmpty(
    Iterable<String> fromState,
  ) async {
    if (lastError != null || _hydratedFromPrefs || games.isNotEmpty) {
      return lastError != null
          ? PreferredPeacockPersistResult.failed(lastError!)
          : const PreferredPeacockPersistResult.ok();
    }
    final seeded = fromState.map((n) => n.trim()).where((n) => n.isNotEmpty);
    if (seeded.isEmpty) return const PreferredPeacockPersistResult.ok();
    games.addAll(seeded);
    return save();
  }

  Future<PreferredPeacockPersistResult> load() async {
    _lastPersistWasSave = false;
    final result = await runPreferredPeacockPersist(() async {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(prefsKey);
      if (stored == null) {
        _hydratedFromPrefs = false;
        return;
      }
      _hydratedFromPrefs = true;
      games
        ..clear()
        ..addAll(stored.map((n) => n.trim()).where((n) => n.isNotEmpty));
    });
    lastError = result.error;
    if (result.isFailed) {
      debugPrint('PreferredPeacockGamesStore.load failed: ${result.error}');
    }
    return result;
  }

  Future<PreferredPeacockPersistResult> save() async {
    _lastPersistWasSave = true;
    final result = await runPreferredPeacockPersist(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefsKey, games.toList());
      _hydratedFromPrefs = true;
    });
    lastError = result.error;
    if (result.isFailed) {
      debugPrint('PreferredPeacockGamesStore.save failed: ${result.error}');
    }
    return result;
  }

  /// Re-run the last persist. Failed writes save current memory; otherwise
  /// reload from disk.
  Future<PreferredPeacockPersistResult> retry() =>
      _lastPersistWasSave ? save() : load();

  /// Drop in-memory games. Does not write SharedPreferences.
  void reset() {
    games.clear();
    _hydratedFromPrefs = false;
    _lastPersistWasSave = false;
    lastError = null;
  }
}

Future<LobbyState> syncPreferredPeacockGames(LobbyState loaded) async {
  final store = PreferredPeacockGamesStore.instance;
  final loadedPrefs = await store.load();
  if (loadedPrefs.isOk) {
    await store.seedIfEmpty(loaded.preferredPeacockGames);
  }
  return overlayPreferredPeacockGames(loaded, preferred: store.snapshot);
}
