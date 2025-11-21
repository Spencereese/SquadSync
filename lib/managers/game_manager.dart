import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:retry/retry.dart';
import 'package:riverpod/riverpod.dart';
import '../services/interfaces.dart';
import '../services/cache_service.dart';
import '../services/igdb_auth_service.dart';

/// Provider for CacheService
final cacheServiceProvider = Provider<CacheService>((ref) => CacheService());

/// Custom exception for IGDB API errors
class IgdbException implements Exception {
  final String message;
  final int? statusCode;

  IgdbException(this.message, {this.statusCode});

  @override
  String toString() =>
      'IgdbException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

/// State for game management
class GameState {
  final bool isLoading;
  final List<Map<String, dynamic>> games;
  final String? error;
  final bool isOffline;

  const GameState({
    this.isLoading = false,
    this.games = const [],
    this.error,
    this.isOffline = false,
  });

  GameState copyWith({
    bool? isLoading,
    List<Map<String, dynamic>>? games,
    String? error,
    bool? isOffline,
  }) {
    return GameState(
      isLoading: isLoading ?? this.isLoading,
      games: games ?? this.games,
      error: error ?? this.error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

/// Manages game selection, lobbies, and game data
class GameManager extends AsyncNotifier<GameState> {
  late http.Client httpClient = http.Client();
  late IgdbAuthService igdbAuth = IgdbAuthService();
  late FirebaseFirestore firestore = FirebaseFirestore.instance;
  static const String _backendUrl =
      'https://squadsync-backend-756172684661.us-central1.run.app'; // Replace with your deployed backend URL

  @override
  FutureOr<GameState> build() {
    // Watch cache service
    ref.watch(cacheServiceProvider);
    // Initialize with empty state
    return const GameState();
  }

  /// Refresh IGDB token if needed
  Future<void> refreshTokenIfNeeded() async {
    try {
      await igdbAuth.getAccessToken();
    } catch (e) {
      print(kDebugMode ? 'Failed to refresh IGDB token: $e' : '');
      throw IgdbException('Failed to refresh IGDB token: $e');
    }
  }

  Map<String, dynamic>? _currentGame;
  List<Map<String, dynamic>> _availableGames = [
    {
      'id': '1',
      'name': 'Call of Duty: Warzone',
      'genres': ['Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '2',
      'name': 'Call of Duty: Modern Warfare III',
      'genres': ['Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '3',
      'name': 'Call of Duty: Modern Warfare II',
      'genres': ['Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '4',
      'name': 'Fortnite',
      'genres': ['Battle Royale', 'Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox', 'Mobile']
    },
    {
      'id': '5',
      'name': 'Apex Legends',
      'genres': ['Battle Royale', 'Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '6',
      'name': 'Counter-Strike 2',
      'genres': ['Shooter'],
      'platforms': ['PC']
    },
    {
      'id': '7',
      'name': 'Valorant',
      'genres': ['Shooter'],
      'platforms': ['PC']
    },
    {
      'id': '8',
      'name': 'Overwatch 2',
      'genres': ['Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '9',
      'name': 'Rainbow Six Siege',
      'genres': ['Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '10',
      'name': 'Destiny 2',
      'genres': ['Shooter', 'RPG'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '11',
      'name': 'Halo Infinite',
      'genres': ['Shooter'],
      'platforms': ['PC', 'Xbox']
    },
    {
      'id': '12',
      'name': 'Battlefield 2042',
      'genres': ['Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '13',
      'name': 'The Finals',
      'genres': ['Shooter'],
      'platforms': ['PC', 'PlayStation', 'Xbox']
    },
    {
      'id': '14',
      'name': 'Escape from Tarkov',
      'genres': ['Shooter'],
      'platforms': ['PC']
    },
    {
      'id': '15',
      'name': 'PlayerUnknown\'s Battlegrounds',
      'genres': ['Battle Royale', 'Shooter'],
      'platforms': ['PC', 'Mobile']
    },
  ];
  Map<String, List<Map<String, dynamic>>> _gameLobbies = {};
  Set<String> _preferredPeacockGames = {};
  Set<String> _mutedGames = {};
  Set<String> _hiddenGames = {};

  List<Map<String, dynamic>> get availableGames => _availableGames;
  Map<String, List<Map<String, dynamic>>> get gameLobbies => _gameLobbies;
  Set<String> get preferredPeacockGames => _preferredPeacockGames;
  Set<String> get mutedGames => _mutedGames;
  Set<String> get hiddenGames => _hiddenGames;

  set availableGames(List<Map<String, dynamic>> value) {
    _availableGames = value;
  }

  set gameLobbies(Map<String, List<Map<String, dynamic>>> value) {
    _gameLobbies = value;
  }

  set preferredPeacockGames(Set<String> value) {
    _preferredPeacockGames = value;
  }

  set mutedGames(Set<String> value) {
    _mutedGames = value;
  }

  set hiddenGames(Set<String> value) {
    _hiddenGames = value;
  }

  Map<String, dynamic>? get currentGame => _currentGame;
  set currentGame(Map<String, dynamic>? value) {
    _currentGame = value;
  }

  void selectGame(Map<String, dynamic> game) {
    _currentGame = game;
  }

  void joinLobby(String lobbyId, String playerName) {
    // Implementation from original SquadState
  }

  void addGame(Map<String, dynamic> game) {
    _availableGames.add(game);
  }

  void editGame(int index, Map<String, dynamic> updatedGame) {
    if (index >= 0 && index < _availableGames.length) {
      _availableGames[index] = updatedGame;
    }
  }

  void deleteGame(int index) {
    if (index >= 0 && index < _availableGames.length) {
      _availableGames.removeAt(index);
    }
  }

  void addPreferredPeacockGame(String gameName) {
    _preferredPeacockGames.add(gameName);
  }

  void removePreferredPeacockGame(String gameName) {
    _preferredPeacockGames.remove(gameName);
  }

  void muteGame(String gameName) {
    _mutedGames.add(gameName);
  }

  void unmuteGame(String gameName) {
    _mutedGames.remove(gameName);
  }

  void hideGame(String gameName) {
    _hiddenGames.add(gameName);
    muteGame(gameName); // Hidden games are automatically muted
  }

  void unhideGame(String gameName) {
    _hiddenGames.remove(gameName);
    unmuteGame(gameName); // Unhide also unmutes
  }

  bool isGameHidden(String gameName) {
    return _hiddenGames.contains(gameName);
  }

  void togglePreferredPeacockGame(String gameName) {
    if (_preferredPeacockGames.contains(gameName)) {
      _preferredPeacockGames.remove(gameName);
    } else {
      _preferredPeacockGames.add(gameName);
    }
  }

  void toggleMutedGame(String gameName) {
    if (_mutedGames.contains(gameName)) {
      _mutedGames.remove(gameName);
    } else {
      _mutedGames.add(gameName);
    }
  }

  void toggleHiddenGame(String gameName) {
    if (_hiddenGames.contains(gameName)) {
      _hiddenGames.remove(gameName);
      unmuteGame(gameName); // Unhide also unmutes
    } else {
      _hiddenGames.add(gameName);
      muteGame(gameName); // Hidden games are automatically muted
    }
  }

  Future<List<Map<String, dynamic>>> fetchGamesFromIGDB(String query) async {
    state = const AsyncValue.loading();
    try {
      await refreshTokenIfNeeded();
      final token = await igdbAuth.getAccessToken();
      final clientId = igdbAuth.getClientId();
      if (clientId == null) throw IgdbException('IGDB client ID not found.');

      final result = await retry(
        () async {
          final response = await httpClient.post(
            Uri.parse('https://api.igdb.com/v4/games'),
            headers: {
              'Client-ID': clientId,
              'Authorization': 'Bearer $token',
            },
            body: 'fields *; search "$query"; limit 50;',
          );
          if (response.statusCode != 200) {
            throw Exception(
                'IGDB API error: ${response.statusCode} - ${response.body}');
          }
          return response;
        },
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );

      final data = json.decode(result.body) as List<dynamic>;
      final games = data.map((game) => game as Map<String, dynamic>).toList();
      state = AsyncValue.data(GameState(games: games));
      return games;
    } catch (e) {
      print(kDebugMode ? 'IGDB fetch failed: $e' : '');
      // Fallback to cached games
      try {
        final cachedGames = await getCachedGames(query);
        state = AsyncValue.data(GameState(games: cachedGames, isOffline: true));
        return cachedGames;
      } catch (cacheError) {
        state = AsyncValue.error(
            IgdbException('Failed to fetch games: $e'), StackTrace.current);
        throw IgdbException('Failed to fetch games: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getCachedGames(String query) async {
    try {
      final snapshot = await firestore
          .collection('games')
          .where('name_lowercase', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('name_lowercase',
              isLessThanOrEqualTo: '${query.toLowerCase()}\uf8ff')
          .limit(10)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print(kDebugMode ? 'Cache fetch failed: $e' : '');
      throw IgdbException('Failed to fetch cached games: $e');
    }
  }

  Future<void> fetchGames({int page = 1, int pageSize = 20}) async {
    // For prod, proxy token/search via backend to hide secret
    // This is a dev implementation using IGDB directly

    print('GameManager: Starting fetchGames with pageSize: $pageSize');

    try {
      // Seed with some popular games using hardcoded queries
      final popularQueries = [
        'call of duty',
        'apex legends',
        'fortnite',
        'counter strike',
        'valorant',
        'overwatch',
        'league of legends',
        'dota 2',
        'world of warcraft',
        'minecraft',
        'grand theft auto',
        'fifa',
        'madden',
        'rocket league',
        'rainbow six siege',
        'destiny 2',
        'halo',
        'battlefield',
        'the finals',
        'escape from tarkov'
      ];

      final batch = firestore.batch();
      int totalFetched = 0;

      for (final query in popularQueries) {
        if (totalFetched >= pageSize) break;

        final response = await httpClient.get(
          Uri.parse(
              '$_backendUrl/igdb/search?q=${Uri.encodeComponent(query)}&limit=3'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = List<Map<String, dynamic>>.from(data['games'] ?? []);
          for (final game in results) {
            if (totalFetched >= pageSize) break;

            final docRef = firestore.collection('games').doc(game['slug']);
            batch.set(docRef, game, SetOptions(merge: true));
            totalFetched++;
          }
        }

        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await batch.commit();
      print(
          'Successfully fetched and cached $totalFetched games from IGDB API');
    } catch (e) {
      print('Error fetching games from IGDB API: $e');
      print('Falling back to local games list');
    }
  }

  /// Enrich a game with IGDB data by searching for matching games
  Future<Map<String, dynamic>> enrichGameWithIgdbData(
      Map<String, dynamic> game) async {
    try {
      final gameName = game['name'] as String?;
      if (gameName == null || gameName.isEmpty) return game;

      // Search IGDB for this game via backend
      final response = await httpClient.get(
        Uri.parse(
            '$_backendUrl/igdb/search?q=${Uri.encodeComponent(gameName)}&limit=5'),
      );
      List<Map<String, dynamic>> igdbResults = [];
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        igdbResults = List<Map<String, dynamic>>.from(data['games'] ?? []);
      }

      // Find the best match (exact name match preferred)
      Map<String, dynamic>? bestMatch;
      for (final igdbGame in igdbResults) {
        if (igdbGame['name']?.toString().toLowerCase() ==
            gameName.toLowerCase()) {
          bestMatch = igdbGame;
          break;
        }
      }

      // If no exact match, use the first result
      bestMatch ??= igdbResults.isNotEmpty ? igdbResults.first : null;

      if (bestMatch != null) {
        return {
          ...game,
          'coverUrl': bestMatch['coverUrl'],
          'igdbId': bestMatch['id'],
          'igdbSlug': bestMatch['slug'],
          'summary': bestMatch['summary'],
          'releaseDate': bestMatch['releaseDate'],
          'genres': bestMatch['genres'],
        };
      }
    } catch (e) {
      print('Error enriching game ${game['name']} with IGDB data: $e');
    }

    return game; // Return original game if enrichment fails
  }

  /// Enrich a list of games with IGDB data
  Future<List<Map<String, dynamic>>> enrichGamesWithIgdbData(
      List<Map<String, dynamic>> games) async {
    final enrichedGames = <Map<String, dynamic>>[];

    for (final game in games) {
      final enrichedGame = await enrichGameWithIgdbData(game);
      enrichedGames.add(enrichedGame);

      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return enrichedGames;
  }
}

/// Provider for GameManager
final gameManagerProvider =
    AsyncNotifierProvider<GameManager, GameState>(() => GameManager());
