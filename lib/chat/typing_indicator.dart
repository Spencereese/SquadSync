import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_state_notifier.dart';

class TypingIndicator extends ConsumerWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typingUsers = ref
        .watch(chatStateNotifierProvider.select((state) => state.typingUsers));

    if (typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  ?.withOpacity(0.7),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
