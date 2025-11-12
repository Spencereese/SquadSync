import 'package:flutter/material.dart';
import '../models/thread_data.dart';
import '../services/thread_service.dart';
import 'thread_bubble.dart';

/// Widget for displaying a list of threads in a chat
class ThreadList extends StatefulWidget {
  final String chatGroupId;
  final String currentUserId;
  final VoidCallback? onThreadTap;

  const ThreadList({
    super.key,
    required this.chatGroupId,
    required this.currentUserId,
    this.onThreadTap,
  });

  @override
  State<ThreadList> createState() => _ThreadListState();
}

class _ThreadListState extends State<ThreadList> {
  final ThreadService _threadService = ThreadService();
  late Stream<List<ThreadData>> _threadsStream;

  @override
  void initState() {
    super.initState();
    _threadsStream = _threadService.getThreadsForChatGroup(widget.chatGroupId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ThreadData>>(
      stream: _threadsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load threads',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final threads = snapshot.data ?? [];
        if (threads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'No threads yet',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a conversation to create the first thread',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: threads.length,
          itemBuilder: (context, index) {
            final thread = threads[index];

            return ThreadBubble(
              thread: thread,
              currentUserId: widget.currentUserId,
              onTap: () => _onThreadSelected(thread),
            );
          },
        );
      },
    );
  }

  void _onThreadSelected(ThreadData thread) {
    // Navigate to thread view or show thread in modal
    widget.onThreadTap?.call();

    // For now, show a simple dialog with thread details
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          child: ThreadBubble(
            thread: thread,
            currentUserId: widget.currentUserId,
            onTap: () {},
            showFullThread: true,
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying thread indicators on message bubbles
class ThreadIndicator extends StatelessWidget {
  final int replyCount;
  final bool isActive;
  final VoidCallback? onTap;

  const ThreadIndicator({
    super.key,
    required this.replyCount,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (replyCount == 0) return const SizedBox.shrink();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 14,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              '$replyCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget for creating new threads
class CreateThreadButton extends StatelessWidget {
  final String chatGroupId;
  final String currentUserId;
  final String currentUserName;

  const CreateThreadButton({
    super.key,
    required this.chatGroupId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showCreateThreadDialog(context),
      tooltip: 'Create Thread',
      child: const Icon(Icons.add_comment),
    );
  }

  void _showCreateThreadDialog(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    ThreadType selectedType = ThreadType.discussion;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Thread'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Thread Title',
                    hintText: 'What is this thread about?',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ThreadType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Thread Type',
                  ),
                  items: ThreadType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_getThreadTypeDisplayName(type)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedType = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Initial Message',
                    hintText: 'Start the conversation...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                    ),
                  );
                  return;
                }

                try {
                  final threadService = ThreadService();
                  // For now, create thread without initial message
                  // TODO: Create root message first, then thread
                  await threadService.createThread(
                    rootMessageId:
                        'temp_${DateTime.now().millisecondsSinceEpoch}', // Temporary
                    chatGroupId: chatGroupId,
                    title: titleController.text.trim(),
                    type: selectedType,
                    creatorUid: currentUserId,
                    creatorName: currentUserName,
                  );

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Thread created successfully!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create thread: $e'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  static String _getThreadTypeDisplayName(ThreadType type) {
    switch (type) {
      case ThreadType.question:
        return 'Question';
      case ThreadType.discussion:
        return 'Discussion';
      case ThreadType.announcement:
        return 'Announcement';
      case ThreadType.reply:
        return 'Reply Thread';
    }
  }
}
