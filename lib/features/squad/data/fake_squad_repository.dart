import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/squad/data/squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// In-memory squad. Set [fail] and every call throws without changing state.
class FakeSquadRepository implements SquadRepository {
  FakeSquadRepository({Squad? seed, this.fail = false})
    : _squad = seed ?? Squad.seed();

  Squad _squad;

  bool fail;

  Squad get snapshot => _squad;

  @override
  Future<Squad> load() async {
    _guard('load');
    return _squad;
  }

  @override
  Future<AddMember> addMember(Member member) async {
    _guard('add');
    final result = _squad.add(member);
    if (result is AddMemberAccepted) _squad = result.squad;
    return result;
  }

  @override
  Future<RemoveMember> removeMember(String memberId) async {
    _guard('remove');
    final result = _squad.remove(memberId);
    if (result is RemoveMemberAccepted) _squad = result.squad;
    return result;
  }

  void _guard(String operation) {
    if (fail) throw RepositoryFailure('squad $operation failed');
  }
}
