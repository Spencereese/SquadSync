import 'package:flutter/material.dart';

/// Message reactions component - displays reaction emojis as corner badges
class MessageReactions extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final void Function(String emoji)? onReactionTap;

  const MessageReactions({
    super.key,
    required this.reactions,
    this.onReactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group reactions by emoji and count them
    final reactionCounts = <String, int>{};
    for (final reaction in reactions) {
      final emoji = reaction['reaction']?.toString() ?? '';
      if (emoji.isNotEmpty) {
        reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
      }
    }

    if (reactionCounts.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(
          maxWidth: 120), // Limit width for corner positioning
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: reactionCounts.entries.map((entry) {
          return GestureDetector(
            onTap: () => onReactionTap?.call(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '${entry.key}${entry.value > 1 ? entry.value : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
