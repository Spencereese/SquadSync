import 'package:flutter/material.dart';
import '../models/message_data.dart';

/// Message sender name component
class MessageSender extends StatelessWidget {
  final MessageData message;

  const MessageSender({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show sender name for Grok shadow messages
    if (message.isGrokMessage) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        message.sender,
        style: TextStyle(
          color: message.isAiResponse
              ? const Color(0xFF00D4FF) // Electric blue for evil AI theme
              : Colors.cyanAccent
                  .withValues(alpha: 0.8), // Regular sender color
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
