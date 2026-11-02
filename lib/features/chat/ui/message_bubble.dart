import 'package:flutter/material.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.mine,
    required this.onRetry,
    super.key,
  });

  final ChatMessage message;
  final bool mine;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = message.delivery == Delivery.failed;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        key: Key('message-${message.id}'),
        onTap: failed ? () => onRetry(message.id) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: mine
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(message.text),
                ),
              ),
              if (mine) _Status(message: message),
            ],
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final key = Key('status-${message.id}');
    return switch (message.delivery) {
      Delivery.sending => Icon(
        Icons.schedule,
        key: key,
        size: 16,
        semanticLabel: 'Sending',
      ),
      Delivery.sent => Icon(
        Icons.check,
        key: key,
        size: 16,
        semanticLabel: 'Sent',
      ),
      Delivery.failed => Text(
        'Not sent. Tap to retry',
        key: key,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontSize: 12,
        ),
      ),
      null => const SizedBox.shrink(),
    };
  }
}
