import 'package:firebase_auth/firebase_auth.dart';
import 'squad_data_manager.dart';
import 'squad_persistence_service.dart';

/// Service responsible for managing lobbies and games.
///
/// This service handles all lobby-related operations including joining lobbies,
/// managing available games, and filtering lobbies based on user preferences
/// and blocks. It coordinates between data management and persistence layers.
///
/// Key responsibilities:
/// - Join players to lobbies
/// - Add, edit, and delete games from the available games list
/// - Filter lobbies to exclude blocked players
/// - Provide lobby information for players
/// - Validate game operations (prevent deleting current game)
class LobbyService {
  final SquadDataManager _dataManager;
  final SquadPersistenceService _persistenceService;

  LobbyService({
    required SquadDataManager dataManager,
    required SquadPersistenceService persistenceService,
  })  : _dataManager = dataManager,
        _persistenceService = persistenceService;

  /// Get visible lobbies for a game, filtered to exclude blocked players
  List<Map<String, dynamic>> getVisibleLobbies(
      String gameName, Map<String, Set<String>> userBlocks) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final currentUserBlocks = userBlocks[uid] ?? {};

    return _dataManager.gameLobbies[gameName]?.where((lobby) {
          final players = List<String>.from(lobby['players'] ?? []);
          // Filter out lobbies with blocked players
          return !players.any((player) => currentUserBlocks.contains(player));
        }).toList() ??
        [];
  }

  /// Join a player to a lobby
  void joinLobby(String lobbyId, String playerName) {
    _persistenceService.joinLobby(lobbyId, playerName);
  }

  /// Add a new game to the available games list
  void addGame(
      List<Map<String, dynamic>> availableGames, Map<String, dynamic> game) {
    if (!availableGames.any((g) => g['name'] == game['name'])) {
      availableGames.add(game);
      _persistenceService.addGame(game);
    }
  }

  /// Edit an existing game in the available games list
  void editGame(List<Map<String, dynamic>> availableGames, int index,
      Map<String, dynamic> updatedGame) {
    if (index >= 0 && index < availableGames.length) {
      availableGames[index] = updatedGame;
      _persistenceService.editGame(updatedGame);
    }
  }

  /// Delete a game from the available games list
  ///
  /// Returns true if the game was successfully deleted, false if it couldn't be deleted
  /// (e.g., it's the current game)
  bool deleteGame(List<Map<String, dynamic>> availableGames, int index,
      String? currentGameName) {
    if (index >= 0 && index < availableGames.length) {
      // Don't allow deleting if it's the current game
      if (availableGames[index]['name'] == currentGameName) {
        return false;
      }
      availableGames.removeAt(index);
      return true;
    }
    return false;
  }

  /// Get the lobby a specific player is in
  Map<String, dynamic>? getPlayerLobby(String playerName) {
    return _dataManager.getPlayerLobby(playerName);
  }

  /// Check if a lobby contains any players blocked by the current user
  bool hasBlockedPlayersInLobby(
      Map<String, dynamic> lobby, String currentUserId) {
    return _dataManager.hasBlockedPlayersInLobby(lobby, currentUserId);
  }

  /// Start a voice room for a squad
  /// Returns the voice room ID
  String startVoiceRoom(String squadId, String squadName) {
    // Generate a unique room ID based on squad ID
    final roomId = 'voice_${squadId}_${DateTime.now().millisecondsSinceEpoch}';

    // Here you would typically store the voice room info in Firestore
    // and notify squad members about the voice room

    return roomId;
  }
}
