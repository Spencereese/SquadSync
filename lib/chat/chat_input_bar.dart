import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isRecording;
  final bool isUploading;
  final VoidCallback onSend;
  final VoidCallback onMedia;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;
  final VoidCallback onPlusMenu;
  final ValueChanged<String> onTextChanged;
  final String quickReactionEmoji;
  final String hintText;
  final FocusNode? focusNode;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.isUploading,
    required this.onSend,
    required this.onMedia,
    required this.onRecordStart,
    required this.onRecordStop,
    required this.onPlusMenu,
    required this.onTextChanged,
    required this.quickReactionEmoji,
    this.hintText = 'Message',
    this.focusNode,
  });

  @override
  _ChatInputBarState createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late final FocusNode _focusNode;
  bool _showMentions = false;
  List<String> _mentionSuggestions = [];

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() {});
    });
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
    _checkForMentions();
  }

  void _checkForMentions() {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    if (cursorPosition > 0) {
      final textBeforeCursor = text.substring(0, cursorPosition);
      final lastAtIndex = textBeforeCursor.lastIndexOf('@');

      if (lastAtIndex != -1) {
        final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
        if (!textAfterAt.contains(' ')) {
          // Show mention suggestions
          _showMentions = true;
          // TODO: Get actual user list from squad state
          _mentionSuggestions = ['Alice', 'Bob', 'Charlie', 'David']
              .where((user) =>
                  user.toLowerCase().contains(textAfterAt.toLowerCase()))
              .toList();
        } else {
          _showMentions = false;
        }
      } else {
        _showMentions = false;
      }
    } else {
      _showMentions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mention suggestions
        if (_showMentions && _mentionSuggestions.isNotEmpty)
          _buildMentionSuggestions(),
        // Input bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Plus button like iMessage
              _buildPlusButton(context),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(context, hasText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlusButton(BuildContext context) {
    return Semantics(
      label: 'More options',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPlusMenu();
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white, // White background to match input bar
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.add,
            size: 24,
            color: Colors.black, // Black icon on white background
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, bool hasText) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 36,
        maxHeight: 120,
      ),
      decoration: BoxDecoration(
        color: Colors.white, // Solid white background to appear above blur
        borderRadius: BorderRadius.circular(20),
        border: null, // Remove blue border when focused
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onTextChanged,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: const TextStyle(
                color: Colors.black, // Black text on light background
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Colors.grey[500], // Darker hint text
                  fontSize: 16,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                filled: true,
                fillColor: Colors.grey[200],
              ),
              textCapitalization: TextCapitalization.sentences,
              autocorrect: true,
              enableSuggestions: true,
            ),
          ),
          if (hasText)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Semantics(
                label: 'Send message',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onSend();
                  },
                  onLongPress: () => _showMessageEffects(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFF007AFF), // iMessage blue
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Semantics(
                label: 'Record voice message',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (widget.isRecording) {
                      widget.onRecordStop();
                    } else {
                      widget.onRecordStart();
                    }
                  },
                  onLongPressStart: (_) {
                    HapticFeedback.lightImpact();
                    widget.onRecordStart();
                  },
                  onLongPressEnd: (_) {
                    widget.onRecordStop();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.isRecording
                          ? Colors.red // Red when recording
                          : Colors.grey[400], // Grey when not recording
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isRecording ? Icons.stop : Icons.mic,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMentionSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (context, index) {
          final user = _mentionSuggestions[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: Text(
                user[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            title: Text(
              user,
              style: const TextStyle(fontSize: 14, color: Colors.black),
            ),
            onTap: () => _selectMention(user),
          );
        },
      ),
    );
  }

  void _selectMention(String user) {
    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    if (cursorPosition > 0) {
      final textBeforeCursor = text.substring(0, cursorPosition);
      final lastAtIndex = textBeforeCursor.lastIndexOf('@');

      if (lastAtIndex != -1) {
        final newText =
            '${textBeforeCursor.substring(0, lastAtIndex)}@$user ${text.substring(cursorPosition)}';
        widget.controller.text = newText;
        widget.controller.selection = TextSelection.collapsed(
          offset: lastAtIndex + user.length + 2,
        );
      }
    }

    setState(() {
      _showMentions = false;
    });
  }

  void _showMessageEffects(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Send with effect',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildEffectOption(
                icon: Icons.waves,
                label: 'Slam',
                onTap: () {
                  Navigator.pop(context);
                  widget.onSend();
                  // TODO: Add slam animation effect
                },
              ),
              _buildEffectOption(
                icon: Icons.blur_on,
                label: 'Gentle',
                onTap: () {
                  Navigator.pop(context);
                  widget.onSend();
                  // TODO: Add gentle animation effect
                },
              ),
              _buildEffectOption(
                icon: Icons.volume_up,
                label: 'Loud',
                onTap: () {
                  Navigator.pop(context);
                  widget.onSend();
                  // TODO: Add loud animation effect
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEffectOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
