import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';

class CreateGroup {
  final ChatRepository _repository;

  CreateGroup(this._repository);

  Future<ChatGroup> call(String name, bool isPublic, {String? description}) =>
      _repository.createGroup(name, isPublic, description: description);
}