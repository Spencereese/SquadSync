import 'dart:ui';
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
  final List<String>?
      availableMembers; // List of member display names for mentions
  final Map<String, String>? memberAvatars; // Map of display name to avatar URL
  final Color? backgroundColor; // Background color for adaptive glass UI

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
    this.availableMembers,
    this.memberAvatars,
    this.backgroundColor,
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

    // Don't show mentions if no members available
    if (widget.availableMembers == null || widget.availableMembers!.isEmpty) {
      setState(() {
        _showMentions = false;
      });
      return;
    }

    if (cursorPosition > 0) {
      final textBeforeCursor = text.substring(0, cursorPosition);
      final lastAtIndex = textBeforeCursor.lastIndexOf('@');

      if (lastAtIndex != -1) {
        final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
        if (!textAfterAt.contains(' ')) {
          // Show mention suggestions filtered by actual members + Grok
          final searchQuery = textAfterAt.toLowerCase();
          final memberSuggestions = widget.availableMembers!
              .where((user) => user.toLowerCase().contains(searchQuery))
              .toList();

          // Add Grok if search matches
          final allSuggestions = <String>[];
          if ('grok'.contains(searchQuery)) {
            allSuggestions.add('Grok');
          }
          allSuggestions.addAll(memberSuggestions);

          _mentionSuggestions = allSuggestions;

          setState(() {
            _showMentions = _mentionSuggestions.isNotEmpty;
          });
        } else {
          setState(() {
            _showMentions = false;
          });
        }
      } else {
        setState(() {
          _showMentions = false;
        });
      }
    } else {
      setState(() {
        _showMentions = false;
      });
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
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
    // Adaptive glass effect based on background luminance
    final bgLuminance = widget.backgroundColor?.computeLuminance() ?? 0.0;
    final isLightBackground = bgLuminance > 0.5;

    final glassColor = isLightBackground
        ? Colors.black.withOpacity(0.4)
        : Colors.white.withOpacity(0.15);

    final borderColor = isLightBackground
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.2);

    final iconColor = isLightBackground ? Colors.black87 : Colors.white;

    return Semantics(
      label: 'More options',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPlusMenu();
        },
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: glassColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: isLightBackground ? 1.0 : 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isLightBackground
                        ? Colors.black.withOpacity(0.3)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: isLightBackground ? 12 : 6,
                    offset: Offset(0, isLightBackground ? 6 : 3),
                    spreadRadius: isLightBackground ? 2 : 0,
                  ),
                  if (isLightBackground)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                ],
              ),
              child: Icon(
                Icons.add,
                size: 22,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context, bool hasText) {
    // Adaptive glass effect based on background luminance
    final bgLuminance = widget.backgroundColor?.computeLuminance() ?? 0.0;
    final isLightBackground = bgLuminance > 0.5;

    // For light backgrounds: use darker glass
    // For dark backgrounds: use lighter glass
    final glassColor = isLightBackground
        ? Colors.black.withOpacity(0.4)
        : Colors.white.withOpacity(0.15);

    final borderColor = isLightBackground
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.2);

    final textColor = isLightBackground ? Colors.black87 : Colors.white;
    final hintColor = isLightBackground
        ? Colors.black.withOpacity(0.5)
        : Colors.white.withOpacity(0.5);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 36,
            maxHeight: 120,
          ),
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: isLightBackground ? 1.5 : 0.5,
            ),
            boxShadow: [
              // Strong drop shadow for visibility on all backgrounds
              BoxShadow(
                color: isLightBackground
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.15),
                blurRadius: isLightBackground ? 20 : 8,
                offset: Offset(0, isLightBackground ? 8 : 3),
                spreadRadius: isLightBackground ? 4 : 0,
              ),
              // Secondary softer shadow for light backgrounds
              if (isLightBackground)
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 15),
                  spreadRadius: 2,
                ),
            ],
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
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: hintColor,
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
        ),
      ),
    );
  }

  Widget _buildMentionSuggestions() {
    // Adaptive glass effect for mention suggestions
    final bgLuminance = widget.backgroundColor?.computeLuminance() ?? 0.0;
    final isLightBackground = bgLuminance > 0.5;

    final suggestionBgColor = isLightBackground
        ? Colors.grey[100]?.withValues(alpha: 0.98)
        : Colors.grey[900]?.withValues(alpha: 0.95);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: suggestionBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withValues(alpha: isLightBackground ? 0.5 : 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isLightBackground ? 0.25 : 0.3),
            blurRadius: isLightBackground ? 16 : 8,
            offset: Offset(0, isLightBackground ? 6 : 2),
            spreadRadius: isLightBackground ? 1 : 0,
          ),
          // Additional shadow for depth on light backgrounds
          if (isLightBackground)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _mentionSuggestions.length,
        itemBuilder: (context, index) {
          final user = _mentionSuggestions[index];
          final isGrok = user == 'Grok';
          final avatarUrl = widget.memberAvatars?[user];

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectMention(user),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Avatar or AI icon
                    if (isGrok)
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '🤖',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      )
                    else
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        backgroundImage:
                            avatarUrl != null && avatarUrl.isNotEmpty
                                ? NetworkImage(avatarUrl)
                                : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? Text(
                                user.isNotEmpty ? user[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    const SizedBox(width: 12),
                    // Username
                    Expanded(
                      child: Text(
                        user,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // @ icon
                    Icon(
                      Icons.alternate_email,
                      size: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
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
