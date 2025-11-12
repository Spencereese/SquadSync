import 'package:flutter/material.dart';

/// Message reactions component - displays reaction emojis below messages
class MessageReactions extends StatelessWidget {
  final List<String> reactions;
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
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: reactions
                    .map((reaction) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(reaction,
                              style: const TextStyle(fontSize: 14)),
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
