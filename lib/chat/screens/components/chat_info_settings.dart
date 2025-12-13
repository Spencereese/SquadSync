import "package:flutter/material.dart";

/// Settings/Info tab wrapper for ChatInfoScreen
/// This component delegates to the parent's _buildInfoTab method
/// Full extraction will happen in Phase 7
class ChatInfoSettingsTab extends StatelessWidget {
  final Widget Function(BuildContext, Color) builder;
  final Color neonColor;

  const ChatInfoSettingsTab({
    super.key,
    required this.builder,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, neonColor);
  }
}
