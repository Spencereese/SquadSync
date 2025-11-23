import 'package:squad_sync/domain/repositories/chat_repository.dart';

class VotePoll {
  final ChatRepository _repository;

  VotePoll(this._repository);

  Future<void> call(String chatGroupId, String pollId, String option, String voterId) =>
      _repository.votePoll(chatGroupId, pollId, option, voterId);
}