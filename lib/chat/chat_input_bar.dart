import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';

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
  });

  @override
  _ChatInputBarState createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _isExpanded = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isExpanded = _focusNode.hasFocus;
      });
    });
    widget.controller.addListener(() {
      setState(() {}); // Ensure UI updates when text changes
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    widget.controller.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!_isExpanded) _buildActionSheetButton(context),
          if (!_isExpanded) const SizedBox(width: 8),
          if (!_isExpanded) _buildMediaButton(),
          if (!_isExpanded) const SizedBox(width: 8),
          if (!_isExpanded) _buildRecordButton(),
          if (!_isExpanded) const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                _buildTextField(context),
                Positioned(
                  right: 8,
                  child: _isExpanded
                      ? _buildCollapseButton(context)
                      : _buildEmojiButton(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildActionButton(context, hasText),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSheetButton(BuildContext context) {
    return Semantics(
      label: 'More options',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPlusMenu();
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: const Icon(
            Icons.add_circle_outline,
            size: 24,
            color: Colors.grey,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaButton() {
    return Semantics(
      label: 'Send media',
      child: GestureDetector(
        onTap: widget.isUploading
            ? null
            : () {
                HapticFeedback.lightImpact();
                widget.onMedia();
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            'assets/images/photo_icon.png',
            width: 24,
            height: 24,
            color:
                widget.isUploading ? Colors.grey.withAlpha(128) : Colors.grey,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Failed to load photo_icon.png: $error');
              return Icon(
                Icons.photo,
                size: 24,
                color: widget.isUploading
                    ? Colors.grey.withAlpha(128)
                    : Colors.grey,
                shadows: const [
                  Shadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(1, 1))
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return Semantics(
      label: widget.isRecording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTap: widget.isUploading
            ? null
            : () {
                HapticFeedback.mediumImpact();
                widget.isRecording
                    ? widget.onRecordStop()
                    : widget.onRecordStart();
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Image.asset(
            widget.isRecording
                ? 'assets/images/mic_off_icon.png'
                : 'assets/images/mic_on_icon.png',
            width: 24,
            height: 24,
            color: widget.isUploading
                ? Colors.grey.withAlpha(128)
                : (widget.isRecording ? Colors.redAccent : Colors.grey),
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Failed to load mic icon: $error');
              return Icon(
                widget.isRecording ? Icons.mic_off : Icons.mic,
                size: 24,
                color: widget.isUploading
                    ? Colors.grey.withAlpha(128)
                    : (widget.isRecording ? Colors.redAccent : Colors.grey),
                shadows: const [
                  Shadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(1, 1))
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isExpanded
          ? MediaQuery.of(context).size.width - 60
          : MediaQuery.of(context).size.width - 150,
      constraints: const BoxConstraints(maxHeight: 100),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(217),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Semantics(
        label: 'Type a message',
        child: GestureDetector(
          onDoubleTap: () => _showPasteWidget(context),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Aa',
              hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w400),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 40, 12),
            ),
            style: const TextStyle(fontSize: 16, color: Colors.white),
            minLines: 1,
            maxLines: 3,
            onChanged: widget.onTextChanged,
            onSubmitted: (_) {
              if (widget.controller.text.isNotEmpty) {
                widget.onSend();
                widget.controller.clear();
              }
            },
            textInputAction: TextInputAction.send,
            keyboardType: TextInputType.text,
            autocorrect: true,
            enableSuggestions: true,
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiButton(BuildContext context) {
    return Semantics(
      label: 'Emoji keyboard',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          if (!context.mounted) return;
          FocusScope.of(context).unfocus();
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!context.mounted) return;
            SystemChannels.textInput.invokeMethod('TextInput.show');
            FocusScope.of(context).requestFocus(_focusNode);
          });
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: const Icon(
            Icons.emoji_emotions_outlined,
            size: 24,
            color: Colors.grey,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(BuildContext context) {
    return Semantics(
      label: 'Collapse options',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _focusNode.unfocus();
          setState(() => _isExpanded = false);
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: const Icon(
            Icons.arrow_forward_ios,
            size: 24,
            color: Colors.grey,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, bool hasText) {
    return Semantics(
      label: hasText ? 'Send message' : 'Send quick reaction',
      enabled: !widget.isUploading,
      child: GestureDetector(
        onTap: widget.isUploading
            ? null
            : () {
                HapticFeedback.mediumImpact();
                if (hasText) {
                  widget.onSend();
                  widget.controller.clear();
                } else {
                  widget.controller.text = widget.quickReactionEmoji;
                  widget.onTextChanged(widget.quickReactionEmoji);
                  widget.onSend();
                  widget.controller.clear();
                }
              },
        child: Container(
          key: ValueKey(hasText ? 'send' : 'quick_reaction'),
          padding: const EdgeInsets.all(8),
          child: widget.isUploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : hasText
                  ? Image.asset(
                      'assets/images/send_icon.png',
                      width: 24,
                      height: 24,
                      color: AppTheme.primaryColor,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Failed to load send_icon.png: $error');
                        return Icon(
                          Icons.send,
                          size: 24,
                          color: AppTheme.primaryColor,
                          shadows: const [
                            Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(1, 1))
                          ],
                        );
                      },
                    )
                  : Text(
                      widget.quickReactionEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
        ),
      ),
    );
  }

  void _showPasteWidget(BuildContext context) async {
    HapticFeedback.mediumImpact();
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || !context.mounted) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final cursorPosition = widget.controller.selection.baseOffset;
    final textPosition = _getTextPosition(context, cursorPosition);

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + textPosition.dx + 16,
        offset.dy + textPosition.dy - 20,
        offset.dx + textPosition.dx + 16,
        offset.dy + textPosition.dy - 20,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.content_paste, color: Colors.white),
              const SizedBox(width: 8),
              Text('Paste', style: TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () {
            final currentText = widget.controller.text;
            final newText = currentText.substring(0, cursorPosition) +
                data.text! +
                currentText.substring(cursorPosition);
            widget.controller.text = newText;
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: cursorPosition + data.text!.length),
            );
            widget.onTextChanged(newText);
          },
        ),
      ],
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Offset _getTextPosition(BuildContext context, int cursorPosition) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: widget.controller.text.substring(0, cursorPosition),
        style: const TextStyle(fontSize: 16, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: MediaQuery.of(context).size.width - 100);
    return Offset(textPainter.width, textPainter.height);
  }
}
