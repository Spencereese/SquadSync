import "package:flutter/material.dart";

/// Backgrounds tab wrapper for ChatInfoScreen
/// This component delegates to the parent's _buildBackgroundsTab method
/// Full extraction will happen in Phase 7
class ChatInfoBackgroundsTab extends StatelessWidget {
  final Widget Function(BuildContext, Color) builder;
  final Color neonColor;

  const ChatInfoBackgroundsTab({
    super.key,
    required this.builder,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, neonColor);
  }
}
