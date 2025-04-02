import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for SystemChannels
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
  final VoidCallback onPlusMenu;
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
    required this.onPlusMenu,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildPlusButton(),
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
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlusButton() {
    return GestureDetector(
      onTap: onPlusMenu,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: const Icon(
          Icons.add,
          size: 24,
          color: Colors.grey,
          shadows: [
            Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButton() {
    return GestureDetector(
      onTap: onMedia,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/images/photo_icon.png',
          width: 24,
          height: 24,
          color: Colors.grey,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Failed to load photo_icon.png: $error');
            return const Icon(
              Icons.photo,
              size: 24,
              color: Colors.grey,
              shadows: [
                Shadow(
                    color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: isRecording ? onRecordStop : onRecordStart,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          isRecording
              ? 'assets/images/mic_off_icon.png'
              : 'assets/images/mic_on_icon.png',
          width: 24,
          height: 24,
          color: isRecording ? Colors.redAccent : Colors.grey,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Failed to load mic icon: $error');
            return Icon(
              isRecording ? Icons.mic_off : Icons.mic,
              size: 24,
              color: isRecording ? Colors.redAccent : Colors.grey,
              shadows: const [
                Shadow(
                    color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 100),
      decoration: BoxDecoration(
        color:
            Colors.black.withAlpha(217), // Replaced withOpacity with withAlpha
        borderRadius: BorderRadius.circular(25),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: 'Aa',
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 40, 12),
        ),
        style: const TextStyle(fontSize: 16, color: Colors.white),
        minLines: 1,
        maxLines: 3,
        onChanged: onTextChanged,
        onSubmitted: (_) => onSend(),
        textInputAction: TextInputAction.send,
        keyboardType: TextInputType.multiline,
      ),
    );
  }

  Widget _buildEmojiButton(BuildContext context) {
    return Positioned(
      right: 8,
      child: GestureDetector(
        onTap: () {
          // Switch to emoji keyboard safely
          if (!context.mounted) return; // Guard against async gaps
          FocusScope.of(context).unfocus(); // Dismiss current keyboard
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!context.mounted) return;
            SystemChannels.textInput.invokeMethod('TextInput.show');
            // Suggest emoji keyboard (platform-dependent behavior)
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
                  color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: isUploading || controller.text.isEmpty ? null : onSend,
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
            : Image.asset(
                'assets/images/send_icon.png',
                width: 24,
                height: 24,
                color: controller.text.isEmpty
                    ? Colors.grey
                    : AppTheme.primaryColor,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Failed to load send_icon.png: $error');
                  return Icon(
                    Icons.send,
                    size: 24,
                    color: controller.text.isEmpty
                        ? Colors.grey
                        : AppTheme.primaryColor,
                    shadows: const [
                      Shadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(1, 1)),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key}); // Added key parameter

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Stack(
        children: [
          ListView.builder(
            itemCount: 20,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) => ListTile(
              title: Text('Message $index'),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ChatInputBar(
              controller: controller,
              isRecording: false,
              isUploading: false,
              onSend: () => debugPrint('Send pressed'),
              onMedia: () => debugPrint('Media pressed'),
              onRecordStart: () => debugPrint('Record started'),
              onRecordStop: () => debugPrint('Record stopped'),
              onPlusMenu: () => debugPrint('Plus menu pressed'),
              onTextChanged: (text) => debugPrint('Text changed: $text'),
            ),
          ),
        ],
      ),
    );
  }
}
