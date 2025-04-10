import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app_theme.dart';
import 'chat_state.dart';
import 'reply_preview.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final bool isUploading;
  final VoidCallback onSend;
  final VoidCallback onMedia;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;
  final VoidCallback onPlusMenu;
  final ValueChanged<String> onTextChanged;
  final DocumentSnapshot? replyToMessage;

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
    this.replyToMessage,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Column(
          children: [
            if (replyToMessage != null)
              ReplyPreview(
                replyToMessage: replyToMessage!,
                onCancel: () {
                  context.read<ChatState>().setReplyToMessage(null);
                },
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildActionSheetButton(context),
                const SizedBox(width: 8),
                _buildMediaButton(),
                const SizedBox(width: 8),
                _buildRecordButton(),
                const SizedBox(width: 8),
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      _buildTextField(context),
                      _buildEmojiButton(context),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildSendButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSheetButton(BuildContext context) {
    return Semantics(
      label: 'More options',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onPlusMenu();
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
        onTap: isUploading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onMedia();
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Builder(
            builder: (context) {
              try {
                return Image.asset(
                  'assets/images/photo_icon.png',
                  width: 24,
                  height: 24,
                  color: isUploading ? Colors.grey.withAlpha(128) : Colors.grey,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Failed to load photo_icon.png: $error');
                    return Icon(
                      Icons.photo,
                      size: 24,
                      color: isUploading
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
                );
              } catch (e) {
                debugPrint('Error rendering photo_icon.png: $e');
                return Icon(
                  Icons.photo,
                  size: 24,
                  color: isUploading ? Colors.grey.withAlpha(128) : Colors.grey,
                  shadows: const [
                    Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(1, 1))
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return Semantics(
      label: isRecording ? 'Stop recording' : 'Start recording',
      child: GestureDetector(
        onTap: isUploading
            ? null
            : () {
                HapticFeedback.mediumImpact();
                isRecording ? onRecordStop() : onRecordStart();
              },
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Builder(
            builder: (context) {
              try {
                return Image.asset(
                  isRecording
                      ? 'assets/images/mic_off_icon.png'
                      : 'assets/images/mic_on_icon.png',
                  width: 24,
                  height: 24,
                  color: isUploading
                      ? Colors.grey.withAlpha(128)
                      : (isRecording ? Colors.redAccent : Colors.grey),
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint('Failed to load mic icon: $error');
                    return Icon(
                      isRecording ? Icons.mic_off : Icons.mic,
                      size: 24,
                      color: isUploading
                          ? Colors.grey.withAlpha(128)
                          : (isRecording ? Colors.redAccent : Colors.grey),
                      shadows: const [
                        Shadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(1, 1))
                      ],
                    );
                  },
                );
              } catch (e) {
                debugPrint('Error rendering mic icon: $e');
                return Icon(
                  isRecording ? Icons.mic_off : Icons.mic,
                  size: 24,
                  color: isUploading
                      ? Colors.grey.withAlpha(128)
                      : (isRecording ? Colors.redAccent : Colors.grey),
                  shadows: const [
                    Shadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(1, 1))
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(217),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Semantics(
        label: 'Type a message',
        child: TextField(
          controller: controller,
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
          onChanged: (value) {
            onTextChanged(value);
            _checkClipboard(context);
          },
          onSubmitted: (_) => _handleSend(context),
          textInputAction: TextInputAction.send,
          keyboardType: TextInputType.multiline,
          autocorrect: true,
          enableSuggestions: true,
        ),
      ),
    );
  }

  Widget _buildEmojiButton(BuildContext context) {
    return Positioned(
      right: 8,
      child: Semantics(
        label: 'Emoji keyboard',
        child: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (!context.mounted) return;
            FocusScope.of(context).unfocus();
            Future.delayed(const Duration(milliseconds: 100), () {
              if (!context.mounted) return;
              SystemChannels.textInput.invokeMethod('TextInput.show');
              FocusScope.of(context).requestFocus(FocusNode());
            });
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.emoji_emotions_outlined,
              size: 24,
              color: Colors.grey,
              shadows: [
                Shadow(
                    color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(BuildContext context) {
    final isEnabled = !isUploading && controller.text.isNotEmpty;
    return Semantics(
      label: 'Send message',
      enabled: isEnabled,
      child: GestureDetector(
        onTap: isEnabled ? () => _handleSend(context) : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          child: isUploading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Builder(
                  builder: (context) {
                    try {
                      return Image.asset(
                        'assets/images/send_icon.png',
                        width: 24,
                        height: 24,
                        color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Failed to load send_icon.png: $error');
                          return Icon(
                            Icons.send,
                            size: 24,
                            color:
                                isEnabled ? AppTheme.primaryColor : Colors.grey,
                            shadows: const [
                              Shadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(1, 1))
                            ],
                          );
                        },
                      );
                    } catch (e) {
                      debugPrint('Error rendering send_icon.png: $e');
                      return Icon(
                        Icons.send,
                        size: 24,
                        color: isEnabled ? AppTheme.primaryColor : Colors.grey,
                        shadows: const [
                          Shadow(
                              color: Colors.black26,
                              blurRadius: 2,
                              offset: Offset(1, 1))
                        ],
                      );
                    }
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _checkClipboard(BuildContext context) async {
    if (!context.mounted) return;
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && controller.text != data.text) {
      controller.text = data.text ?? '';
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pasted from clipboard. Send?'),
          action: SnackBarAction(
            label: 'Send',
            onPressed: () => _handleSend(context),
          ),
        ),
      );
    }
  }

  void _handleSend(BuildContext context) {
    if (controller.text.isNotEmpty) {
      HapticFeedback.mediumImpact();
      onSend();
      controller.clear();
      context.read<ChatState>().setReplyToMessage(null);
    }
  }
}
