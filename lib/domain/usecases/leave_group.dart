import 'package:squad_sync/domain/repositories/chat_repository.dart';

class LeaveGroup {
  final ChatRepository _repository;

  LeaveGroup(this._repository);

  Future<void> call(String groupId) => _repository.leaveGroup(groupId);
}