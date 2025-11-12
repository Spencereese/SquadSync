import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';
import '../../services/ai_service.dart';
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
  String? _selectedTemplate;

  // Poll templates
  static const Map<String, Map<String, dynamic>> _pollTemplates = {
    'yes_no': {
      'title': 'Yes or No?',
      'options': ['Yes', 'No'],
      'multipleChoice': false,
      'anonymous': false,
    },
    'rating': {
      'title': 'Rate this (1-5)',
      'options': [
        '1 - Poor',
        '2 - Fair',
        '3 - Good',
        '4 - Very Good',
        '5 - Excellent'
      ],
      'multipleChoice': false,
      'anonymous': true,
    },
    'time_preference': {
      'title': 'What time works best?',
      'options': [
        'Morning (9-12)',
        'Afternoon (12-5)',
        'Evening (5-9)',
        'Night (9+)'
      ],
      'multipleChoice': true,
      'anonymous': false,
    },
    'game_choice': {
      'title': 'Which game should we play?',
      'options': ['Call of Duty', 'Fortnite', 'Apex Legends', 'Other'],
      'multipleChoice': false,
      'anonymous': false,
    },
  };

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    for (final controller in _optionControllers) {
      controller.addListener(_onOptionsChanged);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTitleChanged() {
    setState(() {});
  }

  void _onOptionsChanged() {
    setState(() {});
  }

  void _applyTemplate(String templateKey) {
    final template = _pollTemplates[templateKey];
    if (template == null) return;

    setState(() {
      _selectedTemplate = templateKey;
      _titleController.text = template['title'] as String;

      // Clear existing controllers
      for (final controller in _optionControllers) {
        controller.dispose();
      }
      _optionControllers.clear();

      // Add new controllers with template options
      final options = template['options'] as List<String>;
      for (final option in options) {
        _optionControllers.add(TextEditingController(text: option));
      }

      // Apply settings
      _settings = _settings.copyWith(
        isMultipleChoice: template['multipleChoice'] as bool,
        isAnonymous: template['anonymous'] as bool,
      );
    });
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
      _optionControllers.last.addListener(_onOptionsChanged);
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

  void _reorderOptions(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _optionControllers.removeAt(oldIndex);
    _optionControllers.insert(newIndex, item);
    setState(() {});
  }

  bool _hasDuplicateOptions() {
    final options = _optionControllers
        .map((controller) => controller.text.trim().toLowerCase())
        .where((text) => text.isNotEmpty)
        .toList();

    return options.length != options.toSet().length;
  }

  List<String> _getDuplicateOptions() {
    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final seen = <String>{};
    final duplicates = <String>[];

    for (final option in options) {
      final lowerOption = option.toLowerCase();
      if (seen.contains(lowerOption)) {
        if (!duplicates.contains(option)) {
          duplicates.add(option);
        }
      } else {
        seen.add(lowerOption);
      }
    }

    return duplicates;
  }

  bool _canCreatePoll() {
    return _titleController.text.trim().isNotEmpty &&
        _optionControllers.length >= 2 &&
        _optionControllers
            .every((controller) => controller.text.trim().isNotEmpty) &&
        !_hasDuplicateOptions();
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
    final hasDuplicates = _hasDuplicateOptions();
    final duplicateOptions = hasDuplicates ? _getDuplicateOptions() : [];

    return Dialog(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 800),
        child: Row(
          children: [
            // Main content (left side)
            Expanded(
              flex: 3,
              child: Padding(
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
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

                    // Template selector
                    Text(
                      'Quick Templates',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _pollTemplates.entries.map((entry) {
                          final isSelected = _selectedTemplate == entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                entry.value['title'] as String,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.black : Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  _applyTemplate(entry.key);
                                } else {
                                  setState(() => _selectedTemplate = null);
                                }
                              },
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
                              selectedColor: Colors.cyanAccent,
                              checkmarkColor: Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
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
                          borderSide:
                              const BorderSide(color: Colors.cyanAccent),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.cyanAccent, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        errorText:
                            hasDuplicates ? 'Duplicate options found' : null,
                      ),
                      maxLength: 200,
                    ),
                    const SizedBox(height: 24),

                    // Options
                    Row(
                      children: [
                        Text(
                          'Options',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const Spacer(),
                        Text(
                          '${_optionControllers.length} options',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Options list with reordering
                    Flexible(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasDuplicates
                                ? Colors.red.withValues(alpha: 0.5)
                                : Colors.white24,
                          ),
                        ),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _optionControllers.length,
                          onReorder: _reorderOptions,
                          itemBuilder: (context, index) {
                            final controller = _optionControllers[index];
                            final isDuplicate = duplicateOptions
                                .contains(controller.text.trim());

                            return Container(
                              key: ValueKey('option_$index'),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  // Drag handle
                                  ReorderableDragStartListener(
                                    index: index,
                                    child: const Icon(
                                      Icons.drag_handle,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Option input
                                  Expanded(
                                    child: TextField(
                                      controller: controller,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        hintText: 'Option ${index + 1}',
                                        hintStyle: const TextStyle(
                                            color: Colors.white38),
                                        border: InputBorder.none,
                                        errorText: isDuplicate
                                            ? 'Duplicate option'
                                            : null,
                                        errorStyle: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 12),
                                      ),
                                      maxLength: 100,
                                    ),
                                  ),

                                  // Remove button
                                  if (_optionControllers.length > 2)
                                    IconButton(
                                      onPressed: () => _removeOption(index),
                                      icon: const Icon(Icons.remove_circle,
                                          color: Colors.red),
                                      tooltip: 'Remove option',
                                      iconSize: 20,
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Add option button
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(Icons.add, color: Colors.cyanAccent),
                        label: const Text(
                          'Add Option',
                          style: TextStyle(color: Colors.cyanAccent),
                        ),
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
                          _settings =
                              _settings.copyWith(isMultipleChoice: value);
                        });
                      },
                      activeThumbColor: Colors.cyanAccent,
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
                      activeThumbColor: Colors.cyanAccent,
                    ),

                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isLoading || !_canCreatePoll()
                              ? null
                              : _createPoll,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black),
                                  ),
                                )
                              : const Text('Create Poll'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Preview panel (right side)
            Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.preview, color: Colors.cyanAccent),
                      const SizedBox(width: 8),
                      Text(
                        'Live Preview',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildPollPreview(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollPreview() {
    if (_titleController.text.trim().isEmpty) {
      return const Center(
        child: Text(
          'Enter a poll question to see preview',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    final validOptions = _optionControllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .map((controller) => controller.text.trim())
        .toList();

    if (validOptions.isEmpty) {
      return const Center(
        child: Text(
          'Add options to see preview',
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll header
          Row(
            children: [
              const Icon(Icons.poll, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _titleController.text.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Poll metadata
          Row(
            children: [
              Text(
                'by You',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '0 votes',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              if (_settings.isMultipleChoice) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  color: Colors.cyanAccent.withValues(alpha: 0.7),
                  size: 14,
                ),
                Text(
                  'Multiple choice',
                  style: TextStyle(
                    color: Colors.cyanAccent.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Poll options preview
          ...validOptions.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        option,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '0%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Poll status
          if (_settings.isAnonymous) ...[
            const SizedBox(height: 8),
            Text(
              'Anonymous poll',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
