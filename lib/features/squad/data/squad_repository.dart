import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

abstract class SquadRepository {
  Future<Squad> load();

  Future<AddMember> addMember(Member member);

  Future<RemoveMember> removeMember(String memberId);
}
