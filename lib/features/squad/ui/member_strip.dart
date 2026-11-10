import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/features/presence/ui/app_presence_controller.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// Horizontal strip of the squad. Never more than [squadCapacity] chips.
/// A green dot means that person has the app open. It is not their check-in
/// and it is not Steam.
class MemberStrip extends ConsumerWidget {
  const MemberStrip({required this.members, super.key});

  final List<Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(appPresenceControllerProvider);
    final shown = members.take(squadCapacity).toList(growable: false);
    final dot = MediaQuery.textScalerOf(context).scale(10);
    return Column(
      key: const Key('member-strip'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${shown.length} of $squadCapacity',
            key: const Key('squad-count'),
          ),
        ),
        SizedBox(
          key: const Key('member-row'),
          height: MediaQuery.textScalerOf(context).scale(56),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final member in shown)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _MemberChip(
                      member: member,
                      presence: presence.available
                          ? presence.isHere(member.id)
                          : null,
                      dot: dot,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({
    required this.member,
    required this.presence,
    required this.dot,
  });

  final Member member;

  /// Null when presence is not available. True is in the app.
  final bool? presence;
  final double dot;

  @override
  Widget build(BuildContext context) {
    final here = presence == true;
    final spoken = presence == null
        ? null
        : '${member.displayName}, ${member.defaultGame}. ${here ? 'in the app' : 'not in the app'}';
    final chip = Chip(
      key: Key('member-${member.id}'),
      visualDensity: VisualDensity.compact,
      avatar: presence == null
          ? null
          : ExcludeSemantics(
              child: Container(
                key: Key(here ? 'in-app-${member.id}' : 'away-${member.id}'),
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: here
                      ? const Color(0xFF1B8A3A)
                      : const Color(0x00000000),
                ),
              ),
            ),
      label: Text('${member.displayName} · ${member.defaultGame}'),
    );
    if (spoken == null) return chip;
    return Semantics(label: spoken, excludeSemantics: true, child: chip);
  }
}
