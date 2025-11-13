import 'package:flutter/material.dart';
import 'widgets/thread_list.dart';
import 'widgets/thread_bubble.dart';
import 'services/thread_service.dart';
import 'models/thread_data.dart';
import '../services/ai_service.dart';

/// Screen for displaying and managing threads in a chat
class ThreadScreen extends StatefulWidget {
  final String chatGroupId;
  final String currentUserId;
  final String currentUserName;
  final ChatType chatType;

  const ThreadScreen({
    super.key,
    required this.chatGroupId,
    required this.currentUserId,
    required this.currentUserName,
    required this.chatType,
  });

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  ThreadData? _selectedThread;
  bool _showThreadView = false;

  @override
  Widget build(BuildContext context) {
    if (_showThreadView && _selectedThread != null) {
      return _buildThreadView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Threads'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showThreadInfo,
          ),
        ],
      ),
      body: ThreadList(
        chatGroupId: widget.chatGroupId,
        currentUserId: widget.currentUserId,
        onThreadTap: () {
          // Handle thread selection if needed
        },
        chatType: widget.chatType,
      ),
      floatingActionButton: CreateThreadButton(
        chatGroupId: widget.chatGroupId,
        currentUserId: widget.currentUserId,
        currentUserName: widget.currentUserName,
      ),
    );
  }

  Widget _buildThreadView() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedThread!.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _showThreadView = false;
              _selectedThread = null;
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showThreadActions(_selectedThread!),
          ),
        ],
      ),
      body: ThreadBubble(
        thread: _selectedThread!,
        currentUserId: widget.currentUserId,
        onTap: () {},
        showFullThread: true,
        chatGroupId: widget.chatGroupId,
        chatType: widget.chatType,
      ),
    );
  }

  void _showThreadInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Threads'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Threads help organize conversations by grouping related messages together.',
                style: TextStyle(height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                'Thread Types:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Question: For asking questions and getting answers'),
              Text('• Discussion: For general conversations'),
              Text('• Announcement: For important updates'),
              Text('• Reply: For threaded replies to messages'),
              SizedBox(height: 16),
              Text(
                'How to use threads:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Tap on a message to reply and create a thread'),
              Text('• Use the + button to start a new thread'),
              Text('• Threads show reply counts and participant info'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showThreadActions(ThreadData thread) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Title'),
            onTap: () {
              Navigator.of(context).pop();
              _editThreadTitle(thread);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_off),
            title: const Text('Mute Thread'),
            onTap: () {
              Navigator.of(context).pop();
              _toggleThreadMute(thread, true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Unmute Thread'),
            onTap: () {
              Navigator.of(context).pop();
              _toggleThreadMute(thread, false);
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            title: const Text('Archive Thread'),
            onTap: () {
              Navigator.of(context).pop();
              _archiveThread(thread);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _editThreadTitle(ThreadData thread) {
    final controller = TextEditingController(text: thread.title);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Thread Title'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Thread Title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;

              try {
                final threadService = ThreadService();
                await threadService.updateThreadTitle(
                  thread.id,
                  controller.text.trim(),
                );

                if (mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pop();
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thread title updated'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update title: $e'),
                    ),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _toggleThreadMute(ThreadData thread, bool isMuted) async {
    try {
      final threadService = ThreadService();
      await threadService.toggleThreadMute(thread.id, isMuted);

      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isMuted ? 'Thread muted' : 'Thread unmuted'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to ${isMuted ? 'mute' : 'unmute'} thread: $e'),
          ),
        );
      }
    }
  }

  void _archiveThread(ThreadData thread) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Thread'),
        content: const Text(
          'Are you sure you want to archive this thread? It will be hidden from the main thread list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final threadService = ThreadService();
        await threadService.archiveThread(thread.id);

        if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thread archived'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive thread: $e'),
            ),
          );
        }
      }
    }
  }
}
