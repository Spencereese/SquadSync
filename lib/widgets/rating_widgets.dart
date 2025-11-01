import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../managers/user_manager.dart';
import '../managers/review_manager.dart';
import '../chat/chat_service.dart';

/// Conditional rating nudge shown only for first-time users of a game
class RatingNudge extends StatefulWidget {
  final String gameName;
  final String chatGroupId;
  final ChatType chatType;
  final VoidCallback? onRatingSubmitted;

  const RatingNudge({
    super.key,
    required this.gameName,
    required this.chatGroupId,
    required this.chatType,
    this.onRatingSubmitted,
  });

  @override
  State<RatingNudge> createState() => _RatingNudgeState();
}

class _RatingNudgeState extends State<RatingNudge> {
  bool _wantsToRate = false;

  @override
  Widget build(BuildContext context) {
    final userManager = Provider.of<UserManager>(context);

    // Only show if user hasn't rated this game
    final hasRated = userManager.hasRatedGame[widget.gameName] ?? false;
    if (hasRated) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'New to ${widget.gameName}? Quick rate after?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Checkbox(
            value: _wantsToRate,
            onChanged: (value) {
              setState(() => _wantsToRate = value ?? false);
            },
            activeColor: Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  bool get wantsToRate => _wantsToRate;
}

/// Dialog for submitting game reviews
class ReviewSubmitDialog extends StatefulWidget {
  final String gameName;
  final String chatGroupId;
  final ChatType chatType;
  final VoidCallback? onSubmitted;

  const ReviewSubmitDialog({
    super.key,
    required this.gameName,
    required this.chatGroupId,
    required this.chatType,
    this.onSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required String gameName,
    required String chatGroupId,
    required ChatType chatType,
    VoidCallback? onSubmitted,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => ReviewSubmitDialog(
        gameName: gameName,
        chatGroupId: chatGroupId,
        chatType: chatType,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<ReviewSubmitDialog> createState() => _ReviewSubmitDialogState();
}

class _ReviewSubmitDialogState extends State<ReviewSubmitDialog> {
  double _rating = 5.5;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Text(
        'Rate ${widget.gameName}',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Star rating slider
            Row(
              children: [
                const Text(
                  'Rating:',
                  style: TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                    value: _rating,
                    min: 1.0,
                    max: 10.0,
                    divisions: 90,
                    label: '${_rating.toStringAsFixed(1)}/10',
                    activeColor: Colors.cyanAccent,
                    onChanged: (value) {
                      setState(() => _rating = value);
                    },
                  ),
                ),
                Text(
                  '${_rating.toStringAsFixed(1)} ⭐',
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Review text field
            TextField(
              controller: _reviewController,
              maxLength: 50,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Optional review (50 chars max)',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReview,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
      final reviewManager = Provider.of<ReviewManager>(context, listen: false);
      final userManager = Provider.of<UserManager>(context, listen: false);
      final chatService = ChatService();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      // Submit review to Firestore
      await reviewManager.submitReview(
        gameName: widget.gameName,
        rating: _rating,
        reviewText: _reviewController.text.trim(),
        chatGroupId: widget.chatGroupId,
      );

      // Mark as rated in UserManager
      userManager.markGameAsRated(widget.gameName);

      // Send to chat thread
      final displayName = userManager.displayName ?? 'Unknown';
      final ratingText = '${_rating.toStringAsFixed(1)}/10';
      final reviewText = _reviewController.text.trim().isNotEmpty
          ? ' "${_reviewController.text.trim()}"'
          : '';

      await chatService.sendMessage(
        context,
        senderUid: user.uid,
        text: '$displayName rated ${widget.gameName} $ratingText$reviewText',
        chatGroupId: widget.chatGroupId,
        chatType: widget.chatType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSubmitted?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
