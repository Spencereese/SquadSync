import 'package:flutter/material.dart';

/// Manages game selection, lobbies, and game data
class GameManager with ChangeNotifier {
  Map<String, dynamic>? _currentGame;
  List<Map<String, dynamic>> _availableGames = [];
  Map<String, List<Map<String, dynamic>>> _gameLobbies = {};
  Set<String> _preferredPeacockGames = {};
  Set<String> _mutedGames = {};

  List<Map<String, dynamic>> get availableGames => _availableGames;
  Map<String, List<Map<String, dynamic>>> get gameLobbies => _gameLobbies;
  Set<String> get preferredPeacockGames => _preferredPeacockGames;
  Set<String> get mutedGames => _mutedGames;

  set availableGames(List<Map<String, dynamic>> value) {
    _availableGames = value;
    notifyListeners();
  }

  set gameLobbies(Map<String, List<Map<String, dynamic>>> value) {
    _gameLobbies = value;
    notifyListeners();
  }

  set preferredPeacockGames(Set<String> value) {
    _preferredPeacockGames = value;
    notifyListeners();
  }

  set mutedGames(Set<String> value) {
    _mutedGames = value;
    notifyListeners();
  }

  Map<String, dynamic>? get currentGame => _currentGame;
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

  bool isGameMuted(String gameName) {
    return _mutedGames.contains(gameName);
  }
}
