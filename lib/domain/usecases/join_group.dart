import 'package:squad_sync/domain/repositories/chat_repository.dart';

class JoinGroup {
  final ChatRepository _repository;

  JoinGroup(this._repository);

  Future<void> call(String groupId) => _repository.joinGroup(groupId);
}