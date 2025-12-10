import 'package:squad_sync/domain/repositories/lobby_repository.dart';

/// Use case for creating a lobby linked to a chat group
/// This is a thin wrapper over LobbyRepository.createLobby that ensures
/// lobbies are properly associated with their chat groups
class CreateLobbyForGroup {
  final LobbyRepository _repository;

  CreateLobbyForGroup(this._repository);

  /// Creates a lobby for the given chat group
  /// 
  /// [chatGroupId] - The ID of the chat group this lobby belongs to
  /// [gameName] - Optional game name for the lobby
  /// [name] - Optional custom name (defaults to "Lobby")
  /// [maxSpots] - Maximum number of spots (defaults to 8)
  /// 
  /// Returns the ID of the created lobby
  Future<String> call({
    required String chatGroupId,
    String? gameName,
    String? name,
    int maxSpots = 8,
  }) async {
    final lobby = await _repository.createLobby(
      name ?? 'Lobby',
      gameName ?? '',
      maxSpots,
    );
    
    return lobby.id;
  }
}
