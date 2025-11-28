import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Message reactions component - displays reaction emojis as corner badges
/// iMessage-style: stacked in bottom corner with count badges, tap to show details
class MessageReactions extends StatelessWidget {
  final List<Map<String, dynamic>> reactions;
  final void Function(String emoji)? onReactionTap;
  final bool isOutgoing; // true for outgoing messages, false for incoming

  const MessageReactions({
    super.key,
    required this.reactions,
    this.onReactionTap,
    required this.isOutgoing,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Group reactions by emoji and count them
    final reactionCounts = <String, int>{};
    for (final reaction in reactions) {
      final emoji = reaction['emoji']?.toString() ??
          reaction['reaction']?.toString() ??
          '';
      if (emoji.isNotEmpty) {
        reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
      }
    }

    if (reactionCounts.isEmpty) return const SizedBox.shrink();

    // Sort by count (most popular first) for better stacking
    final sortedEntries = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: EdgeInsets.only(
        bottom: 8,
        left: isOutgoing ? 8 : 0,
        right: isOutgoing ? 0 : 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: sortedEntries.map((entry) {
          final isFirst = sortedEntries.indexOf(entry) == 0;
          return Transform.translate(
            offset: Offset(isFirst ? 0 : -6, 0), // Overlap for stacking
            child: _buildReactionBadge(entry.key, entry.value, context),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReactionBadge(String emoji, int count, BuildContext context) {
    final hasMultiple = count > 1;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onReactionTap?.call(emoji);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]!.withValues(alpha: 0.9)
              : Colors.grey[200]!.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[600]!.withValues(alpha: 0.3)
                : Colors.grey[400]!.withValues(alpha: 0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 14),
            ),
            if (hasMultiple) ...[
              const SizedBox(width: 2),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().scale(
          duration: const Duration(milliseconds: 200),
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          curve: Curves.elasticOut,
        );
  }
}
