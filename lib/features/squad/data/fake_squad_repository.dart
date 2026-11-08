import 'package:squadsync/core/repository_failure.dart';
import 'package:squadsync/features/squad/data/squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// In-memory squad. Set [fail] and every call throws without changing state.
/// [startEmpty] is a person with a profile and no squad yet.
class FakeSquadRepository implements SquadRepository {
  FakeSquadRepository({
    Squad? seed,
    this.fail = false,
    this.failEnsure = false,
    bool startEmpty = false,
    this.profileMissing = false,
  }) : _profile = _ownerFrom(seed),
       _squad = startEmpty ? null : (seed ?? Squad.seed());

  Member _profile;
  bool profileMissing;
  Squad? _squad;

  bool fail;
  bool failEnsure;

  Squad get snapshot => _squad ?? (throw StateError('no squad'));

  @override
  Future<Member?> myProfile() async {
    _guard('profile');
    if (profileMissing) return null;
    return _profile;
  }

  @override
  Future<Member> ensureMyProfile({
    required String displayName,
    required String defaultGame,
  }) async {
    _guard('profile');
    if (failEnsure) {
      throw const RepositoryFailure(
        'The server cannot create your profile yet. Nothing was saved.',
      );
    }
    if (!profileMissing) return _profile;
    final next = Member(
      id: _profile.id,
      displayName: displayName.trim(),
      defaultGame: defaultGame.trim(),
    );
    if (!next.isValid) {
      throw const RepositoryFailure('profile is incomplete');
    }
    _profile = next;
    profileMissing = false;
    return next;
  }

  @override
  Future<Member> saveProfile({
    required String displayName,
    required String defaultGame,
  }) async {
    _guard('profile');
    if (profileMissing) {
      throw const RepositoryFailure(
        'The server cannot create your profile yet. Nothing was saved.',
      );
    }
    final next = Member(
      id: _profile.id,
      displayName: displayName.trim(),
      defaultGame: defaultGame.trim(),
    );
    if (!next.isValid) {
      throw const RepositoryFailure('profile is incomplete');
    }
    _profile = next;
    final squad = _squad;
    if (squad != null) {
      _squad = Squad(
        id: squad.id,
        ownerId: squad.ownerId,
        members: [
          for (final member in squad.members)
            if (member.id == next.id) next else member,
        ],
      );
    }
    return next;
  }

  @override
  Future<Squad?> findMine() async {
    _guard('load');
    return _squad;
  }

  @override
  Future<Squad> createMine() async {
    _guard('create');
    final existing = _squad;
    if (existing != null) return existing;
    final created = Squad(
      id: 'squad-${_profile.id}',
      ownerId: _profile.id,
      members: [_profile],
    );
    _squad = created;
    return created;
  }

  @override
  Future<Squad> load() async {
    _guard('load');
    final squad = _squad;
    if (squad == null) {
      throw const RepositoryFailure('not in a squad');
    }
    return squad;
  }

  @override
  Future<AddMember> addMember(Member member) async {
    _guard('add');
    final squad = _squad;
    if (squad == null) {
      throw const RepositoryFailure('not in a squad');
    }
    final result = squad.add(member);
    if (result is AddMemberAccepted) _squad = result.squad;
    return result;
  }

  @override
  Future<RemoveMember> removeMember(String memberId) async {
    _guard('remove');
    final squad = _squad;
    if (squad == null) {
      throw const RepositoryFailure('not in a squad');
    }
    final result = squad.remove(memberId);
    if (result is RemoveMemberAccepted) _squad = result.squad;
    return result;
  }

  void _guard(String operation) {
    if (fail) throw RepositoryFailure('squad $operation failed');
  }
}

Member _ownerFrom(Squad? seed) {
  if (seed == null) return spencer;
  for (final member in seed.members) {
    if (member.id == seed.ownerId) return member;
  }
  return spencer;
}
