import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/user_notifier.dart';

class PinnedMessagesScreen extends ConsumerWidget {
  const PinnedMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStateAsync = ref.watch(userNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinned Messages'),
        elevation: 0,
      ),
      body: userStateAsync.when(
        data: (userState) =>
            _buildContent(context, ref, userState?.pinnedMessages ?? []),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading pinned messages: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<String> pinnedMessageIds) {
    if (pinnedMessageIds.isEmpty) {
      return _buildEmptyState(context);
    }

    // For now, show the message IDs. In a real implementation, you'd fetch the message data
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pinnedMessageIds.length,
      itemBuilder: (context, index) {
        final messageId = pinnedMessageIds[index];
        return ListTile(
          title: Text('Message ID: $messageId'),
          trailing: IconButton(
            icon: const Icon(Icons.push_pin_outlined),
            onPressed: () =>
                ref.read(userNotifierProvider.notifier).unpinMessage(messageId),
            tooltip: 'Unpin message',
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.push_pin_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No pinned messages',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pin important messages to keep them easily accessible',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
