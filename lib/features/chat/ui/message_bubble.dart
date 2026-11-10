import 'package:flutter/material.dart';
import 'package:squadsync/features/chat/domain/chat_message.dart';
import 'package:squadsync/features/chat/domain/messenger.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.mine,
    required this.onRetry,
    this.chips = const [],
    this.seen = '',
    this.onLongPress,
    this.onToggle,
    super.key,
  });

  final ChatMessage message;
  final bool mine;
  final ValueChanged<String> onRetry;
  final List<ReactionChip> chips;
  final String seen;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = message.delivery == Delivery.failed;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        key: Key('message-${message.id}'),
        onTap: failed ? () => onRetry(message.id) : null,
        onLongPress: onLongPress,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.replyText != null &&
                          message.replyText!.isNotEmpty) ...[
                        DecoratedBox(
                          key: Key('quote-box-${message.id}'),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(color: scheme.primary, width: 3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                            child: Text(
                              message.replyText!,
                              key: Key('quote-${message.id}'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurface),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(message.text),
                    ],
                  ),
                ),
              ),
              if (chips.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: [
                    for (final chip in chips)
                      Semantics(
                        button: true,
                        label: chip.spoken,
                        excludeSemantics: true,
                        child: TextButton(
                          key: Key('reaction-${message.id}-${chip.emoji}'),
                          onPressed: onToggle == null
                              ? null
                              : () => onToggle!(chip.emoji),
                          child: Text('${chip.emoji} ${chip.count}'),
                        ),
                      ),
                  ],
                ),
              if (mine) _Status(message: message),
              if (seen.isNotEmpty)
                Semantics(
                  label: seen,
                  excludeSemantics: true,
                  child: Text(seen, key: Key('seen-${message.id}')),
                ),
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
