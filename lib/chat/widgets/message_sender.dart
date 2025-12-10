import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_data.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;

/// Message sender name component
class MessageSender extends ConsumerWidget {
  final MessageData message;

  const MessageSender({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Don't show sender name for Grok shadow messages
    if (message.isGrokMessage) {
      return const SizedBox.shrink();
    }

    // Get the display name from the cache instead of using the cached sender name
    final displayName = ref.watch(ln.lobbyNotifierProvider.select(
      (state) => state.maybeWhen(
        data: (data) =>
            data.memberDisplayNames[message.senderUid] ?? message.sender,
        orElse: () => message.sender,
      ),
    ));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        displayName,
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
