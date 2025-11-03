import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReactionsWidget extends StatelessWidget {
  final List<dynamic> reactions;
  final bool isMe;

  const ReactionsWidget(
      {super.key, required this.reactions, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group reactions by emoji and count them
    final reactionCounts = <String, int>{};
    for (final reaction in reactions) {
      if (reaction is Map<String, dynamic>) {
        final emoji = reaction['reaction'] as String?;
        if (emoji != null) {
          reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
        }
      } else if (reaction is String) {
        reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
      }
    }

    if (reactionCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort reactions by count (highest first) and then by emoji
    final sortedReactions = reactionCounts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : a.key.compareTo(b.key);
      });

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sortedReactions.map((entry) {
        final emoji = entry.key;
        final count = entry.value;

        return Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[800]!.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 12),
              ),
              if (count > 1) ...[
                const SizedBox(width: 2),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: const Duration(milliseconds: 200));
  }
}
