import "package:flutter/material.dart";

/// Links and Files tabs wrapper for ChatInfoScreen
/// This component delegates to the parent's _buildLinksTab and _buildFilesTab methods
/// Full extraction will happen in Phase 7
class ChatInfoLinksFilesTab extends StatelessWidget {
  final Widget Function(BuildContext, Color) builder;
  final Color neonColor;

  const ChatInfoLinksFilesTab({
    super.key,
    required this.builder,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, neonColor);
  }
}
