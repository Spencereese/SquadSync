import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/interfaces.dart';

/// Manages game selection, lobbies, and game data
class GameManager with ChangeNotifier implements IGameManager {
  static const String _backendUrl =
      'http://localhost:8080'; // Replace with your deployed backend URL
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

  GameManager() {
    // Try to fetch games from API in the background
    _initializeGames();
  }

  Future<void> _initializeGames() async {
    try {
      await fetchGames(pageSize: 50); // Fetch some games to populate Firestore
    } catch (e) {
      // Ignore errors during initialization - fallback games are already available
    }
  }

  @override
  List<Map<String, dynamic>> get availableGames => _availableGames;
  @override
  Map<String, List<Map<String, dynamic>>> get gameLobbies => _gameLobbies;
  @override
  Set<String> get preferredPeacockGames => _preferredPeacockGames;
  @override
  Set<String> get mutedGames => _mutedGames;
  @override
  Set<String> get hiddenGames => _hiddenGames;

  @override
  set availableGames(List<Map<String, dynamic>> value) {
    _availableGames = value;
    notifyListeners();
  }

  @override
  set gameLobbies(Map<String, List<Map<String, dynamic>>> value) {
    _gameLobbies = value;
    notifyListeners();
  }

  @override
  set preferredPeacockGames(Set<String> value) {
    _preferredPeacockGames = value;
    notifyListeners();
  }

  @override
  set mutedGames(Set<String> value) {
    _mutedGames = value;
    notifyListeners();
  }

  @override
  set hiddenGames(Set<String> value) {
    _hiddenGames = value;
    notifyListeners();
  }

  @override
  Map<String, dynamic>? get currentGame => _currentGame;
  @override
  set currentGame(Map<String, dynamic>? value) {
    _currentGame = value;
    notifyListeners();
  }

  void selectGame(Map<String, dynamic> game) {
    _currentGame = game;
    notifyListeners();
  }

  void joinLobby(String lobbyId, String playerName) {
    // Implementation from original SquadState
  }

  void addGame(Map<String, dynamic> game) {
    _availableGames.add(game);
    notifyListeners();
  }

  void editGame(int index, Map<String, dynamic> updatedGame) {
    if (index >= 0 && index < _availableGames.length) {
      _availableGames[index] = updatedGame;
      notifyListeners();
    }
  }

  void deleteGame(int index) {
    if (index >= 0 && index < _availableGames.length) {
      _availableGames.removeAt(index);
      notifyListeners();
    }
  }

  void addPreferredPeacockGame(String gameName) {
    _preferredPeacockGames.add(gameName);
    notifyListeners();
  }

  void removePreferredPeacockGame(String gameName) {
    _preferredPeacockGames.remove(gameName);
    notifyListeners();
  }

  void muteGame(String gameName) {
    _mutedGames.add(gameName);
    notifyListeners();
  }

  void unmuteGame(String gameName) {
    _mutedGames.remove(gameName);
    notifyListeners();
  }

  void hideGame(String gameName) {
    _hiddenGames.add(gameName);
    muteGame(gameName); // Hidden games are automatically muted
    notifyListeners();
  }

  void unhideGame(String gameName) {
    _hiddenGames.remove(gameName);
    unmuteGame(gameName); // Unhide also unmutes
    notifyListeners();
  }

  bool isGameHidden(String gameName) {
    return _hiddenGames.contains(gameName);
  }

  @override
  void togglePreferredPeacockGame(String gameName) {
    if (_preferredPeacockGames.contains(gameName)) {
      _preferredPeacockGames.remove(gameName);
    } else {
      _preferredPeacockGames.add(gameName);
    }
    notifyListeners();
  }

  @override
  void toggleMutedGame(String gameName) {
    if (_mutedGames.contains(gameName)) {
      _mutedGames.remove(gameName);
    } else {
      _mutedGames.add(gameName);
    }
    notifyListeners();
  }

  @override
  void toggleHiddenGame(String gameName) {
    if (_hiddenGames.contains(gameName)) {
      _hiddenGames.remove(gameName);
      unmuteGame(gameName); // Unhide also unmutes
    } else {
      _hiddenGames.add(gameName);
      muteGame(gameName); // Hidden games are automatically muted
    }
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> searchGames(String query) async {
    if (query.isEmpty) return [];

    print('GameManager: Searching for games with query: "$query"');

    try {
      // Call backend IGDB search
      print('GameManager: Attempting backend IGDB search...');
      final response = await http.get(
        Uri.parse(
            '$_backendUrl/igdb/search?q=${Uri.encodeComponent(query)}&limit=10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final igdbResults =
            List<Map<String, dynamic>>.from(data['games'] ?? []);
        print(
            'GameManager: Backend IGDB search returned ${igdbResults.length} results');
        if (igdbResults.isNotEmpty) {
          // Cache results in Firestore for future offline access
          final batch = FirebaseFirestore.instance.batch();
          for (final game in igdbResults) {
            final gameData = Map<String, dynamic>.from(game);
            gameData['name_lowercase'] = game['name']?.toString().toLowerCase();
            final docRef = FirebaseFirestore.instance
                .collection('games')
                .doc(game['slug']);
            batch.set(docRef, gameData, SetOptions(merge: true));
          }
          await batch.commit();
          return igdbResults;
        }
      } else {
        print(
            'Backend IGDB search failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Backend IGDB search failed: $e');
    }

    // Fallback to Firestore search
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('games')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .get();

      final firestoreResults = snapshot.docs.map((doc) => doc.data()).toList();

      if (firestoreResults.isNotEmpty) {
        return firestoreResults;
      }
    } catch (e) {
      print('Firestore search failed: $e');
    }

    // Final fallback to local search
    print('No games found in IGDB or Firestore, using local fallback');
    return _availableGames
        .where((game) =>
            game['name']?.toLowerCase().contains(query.toLowerCase()) ?? false)
        .toList();
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

      final batch = FirebaseFirestore.instance.batch();
      int totalFetched = 0;

      for (final query in popularQueries) {
        if (totalFetched >= pageSize) break;

        final response = await http.get(
          Uri.parse(
              '$_backendUrl/igdb/search?q=${Uri.encodeComponent(query)}&limit=3'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = List<Map<String, dynamic>>.from(data['games'] ?? []);
          for (final game in results) {
            if (totalFetched >= pageSize) break;

            final docRef = FirebaseFirestore.instance
                .collection('games')
                .doc(game['slug']);
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
      final response = await http.get(
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
