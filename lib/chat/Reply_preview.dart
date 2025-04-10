import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReplyPreview extends StatelessWidget {
  final DocumentSnapshot replyToMessage;
  final VoidCallback onCancel;

  const ReplyPreview({required this.replyToMessage, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final data = replyToMessage.data() as Map<String, dynamic>? ?? {};
    return Animate(
      effects: [SlideEffect(duration: 200.ms, curve: Curves.easeInOut)],
      child: Container(
        padding: EdgeInsets.all(8),
        margin: EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CupertinoColors.systemGrey4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to ${data['sender'] ?? 'Unknown'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.systemGrey,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    data['text'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CupertinoColors.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onCancel,
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                color: CupertinoColors.systemGrey,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
