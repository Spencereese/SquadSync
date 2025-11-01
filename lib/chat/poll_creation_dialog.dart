import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';
import '../../chat/chat_service.dart';

class PollCreationDialog extends StatefulWidget {
  final String? chatGroupId;
  final ChatType chatType;
  final Function(Poll)? onPollCreated;

  const PollCreationDialog({
    super.key,
    this.chatGroupId,
    required this.chatType,
    this.onPollCreated,
  });

  static Future<void> show(BuildContext context,
      {String? chatGroupId, required ChatType chatType}) {
    return showDialog(
      context: context,
      builder: (context) =>
          PollCreationDialog(chatGroupId: chatGroupId, chatType: chatType),
    );
  }

  @override
  State<PollCreationDialog> createState() => _PollCreationDialogState();
}

class _PollCreationDialogState extends State<PollCreationDialog> {
  final _titleController = TextEditingController();
  final _optionControllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController()
  ];
  final _pollService = PollService();

  PollSettings _settings = PollSettings();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  bool _canCreatePoll() {
    return _titleController.text.trim().isNotEmpty &&
        _optionControllers.length >= 2 &&
        _optionControllers
            .every((controller) => controller.text.trim().isNotEmpty);
  }

  Future<void> _createPoll() async {
    if (!_canCreatePoll()) return;

    setState(() => _isLoading = true);

    try {
      final options = _optionControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final pollId = await _pollService.createPoll(
        title: _titleController.text.trim(),
        options: options,
        settings: _settings,
        chatGroupId: widget.chatGroupId,
      );

      if (pollId != null && mounted) {
        // Send a chat message with the poll
        final chatService = ChatService();
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          await chatService.sendMessage(
            context,
            senderUid: currentUser.uid,
            text: '📊 ${_titleController.text.trim()}', // Poll emoji + title
            pollId: pollId,
            chatGroupId: widget.chatGroupId,
            chatType: widget.chatType,
          );
        }

        // Get the created poll to pass to callback
        final createdPoll =
            await _pollService.getPoll(pollId, chatGroupId: widget.chatGroupId);

        // ignore: use_build_context_synchronously
        Navigator.of(context).pop();
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poll created successfully!')),
        );

        // Call the callback with the created poll
        if (createdPoll != null && widget.onPollCreated != null) {
          widget.onPollCreated!(createdPoll);
        }
      } else {
        throw Exception('Failed to create poll');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create poll: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.poll, color: Colors.cyanAccent),
                const SizedBox(width: 12),
                Text(
                  'Create Poll',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title input
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Poll Question',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'What would you like to ask?',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
              ),
              maxLength: 200,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // Options
            Text(
              'Options',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _optionControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _optionControllers[index],
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Option ${index + 1}',
                              labelStyle:
                                  const TextStyle(color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Colors.cyanAccent),
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (_optionControllers.length > 2)
                          IconButton(
                            onPressed: () => _removeOption(index),
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.red),
                            tooltip: 'Remove option',
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Add option button
            TextButton.icon(
              onPressed: _addOption,
              icon: const Icon(Icons.add, color: Colors.cyanAccent),
              label: const Text(
                'Add Option',
                style: TextStyle(color: Colors.cyanAccent),
              ),
            ),
            const SizedBox(height: 24),

            // Settings
            Text(
              'Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),

            // Multiple choice toggle
            SwitchListTile(
              title: const Text(
                'Multiple Choice',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Allow voters to select multiple options',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              value: _settings.isMultipleChoice,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(isMultipleChoice: value);
                });
              },
              activeColor: Colors.cyanAccent,
            ),

            // Anonymous toggle
            SwitchListTile(
              title: const Text(
                'Anonymous Poll',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Hide voter identities',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              value: _settings.isAnonymous,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(isAnonymous: value);
                });
              },
              activeColor: Colors.cyanAccent,
            ),

            const SizedBox(height: 32),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style:
                        TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed:
                      _isLoading || !_canCreatePoll() ? null : _createPoll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text('Create Poll'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
