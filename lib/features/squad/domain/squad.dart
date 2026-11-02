import 'package:squadsync/features/squad/domain/member.dart';

/// A squad never grows past this. The owner counts as one of the eight.
const int squadCapacity = 8;

enum AddRejection { invalid, duplicate, full }

enum RemoveRejection { owner, missing }

sealed class AddMember {
  const AddMember(this.squad);

  final Squad squad;
}

class AddMemberAccepted extends AddMember {
  const AddMemberAccepted(super.squad);
}

class AddMemberRejected extends AddMember {
  const AddMemberRejected(super.squad, this.reason);

  final AddRejection reason;
}

sealed class RemoveMember {
  const RemoveMember(this.squad);

  final Squad squad;
}

class RemoveMemberAccepted extends RemoveMember {
  const RemoveMemberAccepted(super.squad);
}

class RemoveMemberRejected extends RemoveMember {
  const RemoveMemberRejected(super.squad, this.reason);

  final RemoveRejection reason;
}

/// One private squad. The owner is always a member and cannot be removed.
class Squad {
  Squad({
    required this.id,
    required this.ownerId,
    required List<Member> members,
  }) : members = List<Member>.unmodifiable(members) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'must not be empty');
    }
    if (ownerId.trim().isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'must not be empty');
    }
    final ids = members.map((member) => member.id).toList();
    if (ids.toSet().length != ids.length) {
      throw ArgumentError('members must be unique');
    }
    if (members.length > squadCapacity) {
      throw ArgumentError('a squad holds at most $squadCapacity members');
    }
    if (!members.any((member) => member.id == ownerId)) {
      throw ArgumentError('the owner must be a member');
    }
  }

  /// Spencer alone, default game Call of Duty. Friends join with [add].
  factory Squad.seed() {
    return Squad(id: 'squad', ownerId: spencer.id, members: const [spencer]);
  }

  final String id;
  final String ownerId;
  final List<Member> members;

  /// This slice has one chat, and it belongs to the squad.
  String get chatId => id;

  AddMember add(Member member) {
    if (!member.isValid) {
      return AddMemberRejected(this, AddRejection.invalid);
    }
    if (members.any((existing) => existing.id == member.id)) {
      return AddMemberRejected(this, AddRejection.duplicate);
    }
    if (members.length >= squadCapacity) {
      return AddMemberRejected(this, AddRejection.full);
    }
    return AddMemberAccepted(
      Squad(id: id, ownerId: ownerId, members: [...members, member]),
    );
  }

  RemoveMember remove(String memberId) {
    if (memberId == ownerId) {
      return RemoveMemberRejected(this, RemoveRejection.owner);
    }
    if (!members.any((member) => member.id == memberId)) {
      return RemoveMemberRejected(this, RemoveRejection.missing);
    }
    return RemoveMemberAccepted(
      Squad(
        id: id,
        ownerId: ownerId,
        members: [
          for (final member in members)
            if (member.id != memberId) member,
        ],
      ),
    );
  }
}
