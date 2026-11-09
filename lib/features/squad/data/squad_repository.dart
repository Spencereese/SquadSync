import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

abstract class SquadRepository {
  /// Null when the signed-in person has no profile row yet.
  Future<Member?> myProfile();

  /// Inserts only the signed-in person's row when it is missing.
  /// An existing row is returned unchanged.
  Future<Member> ensureMyProfile({
    required String displayName,
    required String defaultGame,
  });

  Future<Member> saveProfile({
    required String displayName,
    required String defaultGame,
  });

  /// Null when this person is not in a squad. Does not throw for that case.
  Future<Squad?> findMine();

  /// The squad this person is already in, or a new one they own.
  /// A second call does not create another squad.
  Future<Squad> createMine();

  /// Fires when this person's seat or their squad's member rows change.
  /// An empty stream is fine. Resume and pull-to-refresh do not depend on it.
  Stream<void> watchRoster({String? squadId, required String userId});

  Future<Squad> load();

  Future<AddMember> addMember(Member member);

  Future<RemoveMember> removeMember(String memberId);
}
