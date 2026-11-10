import 'package:flutter/material.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// Horizontal strip of the squad. Never more than [squadCapacity] chips.
class MemberStrip extends StatelessWidget {
  const MemberStrip({required this.members, super.key});

  final List<Member> members;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(squadCapacity).toList(growable: false);
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
          height: MediaQuery.textScalerOf(context).scale(56).clamp(56, 72),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final member in shown)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      key: Key('member-${member.id}'),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${member.displayName} · ${member.defaultGame}',
                      ),
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
