import 'dart:ui';
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

    final reactionCount = sortedEntries.length;

    // Dynamic spacing with overlap after 3 reactions
    // 1 reaction: no spacing
    // 2-3 reactions: 3px spacing (comfortable)
    // 4-5 reactions: -2px spacing (slight overlap)
    // 6+ reactions: -4px spacing (more overlap for stacked effect)
    final baseSpacing = reactionCount <= 1
        ? 0.0
        : reactionCount <= 3
            ? 3.0
            : reactionCount <= 5
                ? -2.0
                : -4.0;

    return Container(
      margin: EdgeInsets.only(
        bottom: 2,
        top: 2,
        left: isOutgoing ? 4 : 0,
        right: isOutgoing ? 0 : 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: sortedEntries.asMap().entries.map((mapEntry) {
          final index = mapEntry.key;
          final entry = mapEntry.value;
          final spacing = index > 0 ? baseSpacing : 0.0;

          final badge = _buildReactionBadge(entry.key, entry.value, context);

          // Use Transform.translate for overlap (negative spacing)
          if (spacing < 0) {
            return Transform.translate(
              offset: Offset(spacing, 0),
              child: badge,
            );
          } else {
            return Padding(
              padding: EdgeInsets.only(left: spacing),
              child: badge,
            );
          }
        }).toList(),
      ),
    );
  }

  Widget _buildReactionBadge(String emoji, int count, BuildContext context) {
    final hasMultiple = count > 1;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (onReactionTap != null) {
          HapticFeedback.lightImpact();
          onReactionTap!(emoji);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 18,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            if (hasMultiple) ...[
              const SizedBox(width: 3),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.95)
                      : Colors.black.withValues(alpha: 0.85),
                  height: 1.0,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 3,
                      offset: const Offset(0, 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        )
        .scale(
          duration: const Duration(milliseconds: 250),
          begin: const Offset(0.85, 0.85),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOut,
        );
  }
}
