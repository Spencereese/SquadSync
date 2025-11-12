import 'package:flutter/material.dart';

/// Message reactions component - displays reaction emojis below messages
class MessageReactions extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final bool isFromCurrentUser;
  final VoidCallback? onReactionTap;

  const MessageReactions({
    super.key,
    required this.reactions,
    required this.isFromCurrentUser,
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
      margin: EdgeInsets.only(
        top: 4,
        left: isFromCurrentUser ? 0 : 48,
        right: isFromCurrentUser ? 48 : 0,
      ),
      child: Row(
        mainAxisAlignment:
            isFromCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onReactionTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: reactionCounts.entries
                    .map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            '${entry.key}${entry.value > 1 ? entry.value : ''}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
