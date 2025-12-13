import "package:flutter/material.dart";

/// Media tabs wrapper for ChatInfoScreen (Clips and Photos)
/// This component delegates to the parent's _buildClipsTab and _buildPhotosTab methods
/// Full extraction will happen in Phase 7
class ChatInfoMediaTab extends StatelessWidget {
  final Widget Function(BuildContext, Color) builder;
  final Color neonColor;

  const ChatInfoMediaTab({
    super.key,
    required this.builder,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, neonColor);
  }
}
