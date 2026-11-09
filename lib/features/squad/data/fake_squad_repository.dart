import 'dart:async';

import 'package:squadsync/core/sq8_database.dart';
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
  bool failCreate = false;

  /// Pauses [myProfile] so a test can switch accounts while a load is in flight.
  Future<void>? holdProfile;

  final _roster = StreamController<RosterSignal>.broadcast();

  /// Tells listeners that a member row changed. Tests use this as realtime.
  void notifyRoster() {
    _signal(RosterSignal.changed);
  }

  /// A member-row delete. The removed person may not receive this.
  void notifyDeleted() {
    _signal(RosterSignal.deleted);
  }

  void _signal(RosterSignal signal) {
    if (!_roster.isClosed) _roster.add(signal);
  }

  /// Drops this person's seat without a realtime event.
  void unseat() {
    _squad = null;
  }

  Squad get snapshot => _squad ?? (throw StateError('no squad'));

  @override
  Future<Member?> myProfile() async {
    final hold = holdProfile;
    if (hold != null) await hold;
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
    if (failCreate) {
      throw const RepositoryFailure(
        'The squad was not opened. Nothing is on screen until the server returns it.',
      );
    }
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

  /// Test seam. Joining a code seats this person in [squad].
  void seat(Squad squad) {
    _squad = squad;
  }

  @override
  Stream<RosterSignal> watchRoster({String? squadId, required String userId}) {
    return _roster.stream;
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
