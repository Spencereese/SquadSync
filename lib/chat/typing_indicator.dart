import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart';

class TypingIndicator extends ConsumerWidget {
  final String chatGroupId;

  const TypingIndicator({
    super.key,
    required this.chatGroupId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatStateAsync = ref.watch(chatNotifierProvider);

    return chatStateAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (chatState) {
        final typingUids = chatState.typingIndicators[chatGroupId] ?? {};
        if (typingUids.isEmpty) {
          return const SizedBox.shrink();
        }

        // Convert UIDs to display names (simplified - in real app would need UID->name mapping)
        final typingUsers = typingUids.map((uid) => 'User $uid').toList();

        final typingText = typingUsers.length == 1
            ? '${typingUsers.first} is typing...'
            : '${typingUsers.length} people are typing...';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Animated dots
              SizedBox(
                width: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return AnimatedOpacity(
                      opacity: 1.0,
                      duration: Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                typingText,
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
