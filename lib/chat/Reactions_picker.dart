import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import '../../app_theme.dart';

class ReactionPicker extends StatelessWidget {
  final String docId;
  final Function(String) onReactionSelected;

  const ReactionPicker({
    super.key,
    required this.docId,
    required this.onReactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEmojiKeyboard(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: const Text(
          'React',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  void _showEmojiKeyboard(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final controller = TextEditingController();
        return Padding(
          padding: const EdgeInsets.all(16.0)
              .copyWith(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: controller,
                placeholder: 'Type an emoji...',
                placeholderStyle: const TextStyle(color: AppTheme.hintColor),
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.text,
                autofocus: true,
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    onReactionSelected(value);
                    Navigator.pop(context);
                  }
                },
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => FocusScope.of(context).unfocus());
  }
}
