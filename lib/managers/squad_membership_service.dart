import 'squad_manager.dart';
import 'state_initializer.dart';

/// Service for handling squad membership operations like joining, leaving, and selecting squads
class SquadMembershipService {
  final SquadManager _squadManager;
  final StateInitializer _stateInitializer;

  SquadMembershipService(this._squadManager, this._stateInitializer);

  /// Leave the currently selected squad
  Future<void> leaveSquad(
    String? selectedSquadId,
    List<String> userSquadIds,
    Map<String, Map<String, dynamic>> userSquads,
    void Function() onSquadChanged,
  ) async {
    if (selectedSquadId != null) {
      await _squadManager.leaveSquad(selectedSquadId);
      userSquadIds.remove(selectedSquadId);
      onSquadChanged();
    }
  }

  /// Select a squad and load its data
  void selectSquad(
    String squadId,
    List<String> userSquadIds,
    Map<String, Map<String, dynamic>> userSquads,
    void Function() onSquadChanged,
  ) {
    if (userSquadIds.contains(squadId)) {
      _stateInitializer.loadSquadData(squadId);
      onSquadChanged();
    }
  }
}
