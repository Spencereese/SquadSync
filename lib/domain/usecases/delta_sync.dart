import 'package:squad_sync/domain/repositories/chat_repository.dart';

class DeltaSync {
  final ChatRepository _repository;

  DeltaSync(this._repository);

  Future<void> call(String chatGroupId, {DateTime? since}) =>
      _repository.syncMessages(chatGroupId, since: since);
}