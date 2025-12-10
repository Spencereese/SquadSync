import 'package:flutter/material.dart';
import '../services/auth_service_supabase.dart';
import '../services/message_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';
import '../../services/ai_service.dart';
import '../../domain/entities/message.dart' hide Poll;
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../presentation/notifiers/user_notifier.dart';

class PollCreationDialog extends ConsumerStatefulWidget {
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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PollCreationDialog(
        chatGroupId: chatGroupId,
        chatType: chatType,
      ),
    );
  }

  @override
  ConsumerState<PollCreationDialog> createState() => _PollCreationDialogState();
}

class _PollCreationDialogState extends ConsumerState<PollCreationDialog> {
  final _titleController = TextEditingController();
  final _optionControllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController()
  ];
  final _pollService = PollService();
  final _aiService = AiService();

  PollSettings _settings = PollSettings();
  bool _isLoading = false;
  String? _selectedTemplate;

  // Poll templates
  static const Map<String, Map<String, dynamic>> _pollTemplates = {
    'yes_no': {
      'title': 'Yes or No?',
      'icon': '✅',
      'options': ['Yes', 'No'],
      'multipleChoice': false,
      'anonymous': false,
    },
    'rating': {
      'title': 'Rate this (1-5)',
      'icon': '⭐',
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
      'icon': '⏰',
      'options': [
        'Morning (9-12)',
        'Afternoon (12-5)',
        'Evening (5-9)',
        'Night (9+)'
      ],
      'multipleChoice': true,
      'anonymous': false,
    },
    'opinion': {
      'title': 'What\'s your opinion?',
      'icon': '💭',
      'options': [
        'Strongly Agree',
        'Agree',
        'Neutral',
        'Disagree',
        'Strongly Disagree'
      ],
      'multipleChoice': false,
      'anonymous': false,
    },
    'preference': {
      'title': 'Choose your preference',
      'icon': '🎯',
      'options': ['Option A', 'Option B', 'Option C'],
      'multipleChoice': false,
      'anonymous': false,
    },
    'meeting': {
      'title': 'When should we meet?',
      'icon': '📅',
      'options': ['Today', 'Tomorrow', 'This Week', 'Next Week', 'Whenever'],
      'multipleChoice': true,
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

  Future<void> _generateAISuggestions() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      // Get current game context for better suggestions
      final squadState = ref.read(ln.lobbyNotifierProvider).value;
      final currentGame = squadState?.currentGame;
      final gameContext = currentGame != null
          ? 'Current game: ${currentGame['name']} (${currentGame['genres']?.join(', ') ?? 'Unknown genre'})'
          : null;

      final suggestions = await _aiService.generatePollOptions(
        _titleController.text.trim(),
        context: gameContext,
      );

      if (suggestions.isNotEmpty && mounted) {
        // Replace empty options with suggestions, up to available slots
        int suggestionIndex = 0;
        for (int i = 0;
            i < _optionControllers.length &&
                suggestionIndex < suggestions.length;
            i++) {
          if (_optionControllers[i].text.trim().isEmpty) {
            _optionControllers[i].text = suggestions[suggestionIndex];
            suggestionIndex++;
          }
        }

        // Add more options if we have more suggestions and room
        while (suggestionIndex < suggestions.length &&
            _optionControllers.length < 8) {
          _optionControllers
              .add(TextEditingController(text: suggestions[suggestionIndex]));
          _optionControllers.last.addListener(_onOptionsChanged);
          suggestionIndex++;
        }

        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate suggestions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

      final creatorName =
          ref.read(userNotifierProvider).value?.displayName ?? 'Anonymous';

      final pollId = await _pollService.createPoll(
        title: _titleController.text.trim(),
        options: options,
        settings: _settings,
        chatGroupId: widget.chatGroupId,
        creatorName: creatorName,
      );

      if (pollId != null && mounted) {
        // Send a chat message with the poll
        final chatService = MessageService();
        final currentUser = AuthServiceSupabase().currentUser;
        if (currentUser != null) {
          await chatService.sendMessage(
            ref,
            senderUid: currentUser.id,
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF121212), // Dark card color from theme
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with drag handle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white10, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.cyanAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.poll,
                          color: Colors.cyanAccent,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Create Poll',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Templates
                    const Text(
                      'Quick Templates',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pollTemplates.length,
                        itemBuilder: (context, index) {
                          final entry = _pollTemplates.entries.elementAt(index);
                          final isSelected = _selectedTemplate == entry.key;
                          final template = entry.value;

                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 12),
                            child: Material(
                              color: isSelected
                                  ? Colors.cyanAccent.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () => _applyTemplate(entry.key),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        template['icon'] ?? '📊',
                                        style: const TextStyle(fontSize: 20),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        template['title'] as String,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.cyanAccent
                                              : Colors.white,
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Poll Question
                    const Text(
                      'Poll Question',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(color: Colors.white),
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'What would you like to ask?',
                        hintStyle: TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Colors.cyanAccent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Options
                    Row(
                      children: [
                        const Text(
                          'Options',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_optionControllers.length} options',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // AI Suggestions Button
                    if (_titleController.text.trim().isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: TextButton.icon(
                          onPressed: _generateAISuggestions,
                          icon: const Icon(
                            Icons.auto_awesome,
                            color: Colors.cyanAccent,
                            size: 18,
                          ),
                          label: const Text(
                            'AI Suggestions',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 14,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            backgroundColor:
                                Colors.cyanAccent.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),

                    // Options List
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasDuplicates
                              ? Colors.red.withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _optionControllers.length,
                        onReorder: _reorderOptions,
                        itemBuilder: (context, index) {
                          final controller = _optionControllers[index];
                          final isDuplicate =
                              duplicateOptions.contains(controller.text.trim());

                          return Container(
                            key: ValueKey('option_$index'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              border: index < _optionControllers.length - 1
                                  ? const Border(
                                      bottom: BorderSide(
                                        color: Colors.white10,
                                        width: 1,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                // Drag handle
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: const Icon(
                                      Icons.drag_indicator,
                                      color: Colors.white54,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Option input
                                Expanded(
                                  child: TextField(
                                    controller: controller,
                                    style: const TextStyle(color: Colors.white),
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
                                        fontSize: 12,
                                      ),
                                    ),
                                    maxLength: 100,
                                  ),
                                ),

                                // Remove button
                                if (_optionControllers.length > 2)
                                  IconButton(
                                    onPressed: () => _removeOption(index),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Remove option',
                                    iconSize: 20,
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Add option button
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        onPressed: _addOption,
                        icon: const Icon(
                          Icons.add,
                          color: Colors.cyanAccent,
                        ),
                        label: const Text(
                          'Add Option',
                          style: TextStyle(color: Colors.cyanAccent),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),

                    if (hasDuplicates) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Duplicate options found: ${duplicateOptions.join(", ")}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Settings
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Multiple choice toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Multiple Choice',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Allow voters to select multiple options',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        value: _settings.isMultipleChoice,
                        onChanged: (value) {
                          setState(() {
                            _settings =
                                _settings.copyWith(isMultipleChoice: value);
                          });
                        },
                        activeThumbColor: Colors.cyanAccent,
                        activeTrackColor:
                            Colors.cyanAccent.withValues(alpha: 0.3),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Anonymous toggle
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        title: const Text(
                          'Anonymous Poll',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Hide voter identities',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        value: _settings.isAnonymous,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(isAnonymous: value);
                          });
                        },
                        activeThumbColor: Colors.cyanAccent,
                        activeTrackColor:
                            Colors.cyanAccent.withValues(alpha: 0.3),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Colors.white24,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading || !_canCreatePoll()
                                ? null
                                : _createPoll,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
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
                                : const Text(
                                    'Create Poll',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),

                    // Bottom padding for keyboard
                    SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom + 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
