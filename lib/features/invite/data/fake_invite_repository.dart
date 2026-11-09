import 'package:squadsync/features/invite/data/invite_repository.dart';
import 'package:squadsync/features/invite/domain/invite_code.dart';
import 'package:squadsync/features/squad/data/fake_squad_repository.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// In-memory codes. [notEnabled] is a live project that has no invite RPC.
class FakeInviteRepository implements InviteRepository {
  FakeInviteRepository({this.squads, this.notEnabled = false});

  final FakeSquadRepository? squads;
  bool notEnabled;
  SquadInvite? invite;
  var rotates = 0;

  @override
  Future<SquadInvite?> current() async {
    if (notEnabled) throw const InvitesNotEnabled();
    return invite;
  }

  @override
  Future<SquadInvite> createOrRotate() async {
    if (notEnabled) throw const InvitesNotEnabled();
    rotates += 1;
    invite = SquadInvite(
      code: 'CODE234$rotates',
      expiresAt: DateTime.utc(2026, 11, 16),
      squadId: 'squad',
    );
    return invite!;
  }

  @override
  Future<JoinDecision> join(String code) async {
    if (notEnabled) return const JoinDecision.notEnabled();
    final normalized = code.trim().toUpperCase().replaceAll(
      RegExp('[^A-Z0-9]'),
      '',
    );
    final error = switch (normalized) {
      'EXPIRED2' => JoinError.expired,
      'FULL2345' => JoinError.full,
      'MEMBER22' => JoinError.alreadyInSquad,
      'OWNS2345' => JoinError.ownsSquadWithMembers,
      'GOOD2345' => null,
      _ => JoinError.invalid,
    };
    if (error != null) return JoinDecision.failed(error);
    squads?.seat(
      Squad(
        id: 'joined',
        ownerId: 'owner',
        members: const [
          Member(
            id: 'owner',
            displayName: 'Owner',
            defaultGame: 'Call of Duty',
          ),
          spencer,
        ],
      ),
    );
    return const JoinDecision.joined('joined');
  }
}
