import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart' as record_package;
import 'dart:io';
import '../../app_theme.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final bool isUploading;
  final VoidCallback onSend;
  final VoidCallback onMedia;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;
  final ValueChanged<String> onTextChanged;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isRecording,
    required this.isUploading,
    required this.onSend,
    required this.onMedia,
    required this.onRecordStart,
    required this.onRecordStop,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -62),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildMediaButton(),
            const SizedBox(width: 4),
            _buildRecordButton(),
            const SizedBox(width: 4),
            Expanded(
              child: _buildTextField(context),
            ),
            const SizedBox(width: 4),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButton() {
    return IconButton(
      icon: Image.asset(
        'assets/images/photo_icon.png',
        width: 24,
        height: 24,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Asset load error for photo_icon.png: $error');
          return const Icon(Icons.photo, size: 24);
        },
      ),
      tooltip: 'Send media',
      onPressed: onMedia,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildRecordButton() {
    return IconButton(
      icon: Image.asset(
        isRecording
            ? 'assets/images/mic_off_icon.png'
            : 'assets/images/mic_on_icon.png',
        width: 24,
        height: 24,
        color: isRecording ? AppTheme.errorColor : AppTheme.textColor,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Asset load error for mic icon: $error');
          return Icon(
            isRecording ? Icons.mic_off : Icons.mic,
            size: 24,
          );
        },
      ),
      tooltip: isRecording ? 'Stop recording' : 'Start recording',
      onPressed: isRecording ? onRecordStop : onRecordStart,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Type a message...',
        hintStyle: TextStyle(color: AppTheme.hintColor),
        filled: true,
        fillColor: AppTheme.hintColor.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      minLines: 1,
      maxLines: 5,
      onChanged: onTextChanged,
      onSubmitted: (_) => onSend(),
      textInputAction: TextInputAction.send,
    );
  }

  Widget _buildSendButton() {
    return isUploading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : IconButton(
            icon: Image.asset(
              'assets/images/send_icon.png',
              width: 24,
              height: 24,
              color: controller.text.isNotEmpty
                  ? AppTheme.primaryColor
                  : AppTheme.hintColor,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Asset load error for send_icon.png: $error');
                return const Icon(Icons.send, size: 24);
              },
            ),
            tooltip: 'Send message',
            onPressed: controller.text.isNotEmpty ? onSend : null,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(),
          );
  }
}
