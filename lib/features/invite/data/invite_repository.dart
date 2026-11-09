import 'package:squadsync/features/invite/domain/invite_code.dart';

/// The signed-in person's invite. A missing table or RPC is
/// [InvitesNotEnabled], not a made-up code.
abstract class InviteRepository {
  Future<SquadInvite?> current();

  /// Creates a code, or replaces the current one. The previous code stops working.
  Future<SquadInvite> createOrRotate();

  Future<JoinDecision> join(String code);
}

class InvitesNotEnabled implements Exception {
  const InvitesNotEnabled();
}
