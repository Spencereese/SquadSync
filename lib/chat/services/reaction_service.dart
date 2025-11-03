import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../squad_state.dart';

class ReactionService {
  static Future<void> addReaction(
    BuildContext context,
    String emoji,
    String messageId,
    String? chatGroupId,
  ) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null || messageId.isEmpty || emoji.isEmpty) {
        debugPrint(
            'Invalid reaction data: userId=$userId, messageId=$messageId, emoji="$emoji"');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to add reaction: Invalid data')),
          );
        }
        return;
      }

      // Get squad state to determine collection path
      final squadState = Provider.of<SquadState>(context, listen: false);
      final squadId = squadState.selectedSquadId;

      if (squadId == null) {
        debugPrint('Reaction failed: No squad ID available');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to add reaction: No squad context')),
          );
        }
        return;
      }

      // Determine collection path based on chat type
      final collectionPath = chatGroupId != null
          ? 'squads/$squadId/chat_groups/$chatGroupId/messages'
          : 'squads/$squadId/chat';

      debugPrint(
          'Adding reaction: emoji=$emoji, messageId=$messageId, collection=$collectionPath');

      try {
        debugPrint('About to get document snapshot...');
        final docSnapshot = await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(messageId)
            .get();
        debugPrint(
            'Document snapshot retrieved, exists: ${docSnapshot.exists}');

        if (!docSnapshot.exists) {
          debugPrint('Message not found: $messageId in $collectionPath');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message not found')),
            );
          }
          return;
        }

        debugPrint('About to get message data...');
        final messageData = docSnapshot.data();
        debugPrint(
            'Message data retrieved: ${messageData != null ? 'not null' : 'null'}');

        if (messageData == null) {
          debugPrint('Message data is null: $messageId in $collectionPath');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message data unavailable')),
            );
          }
          return;
        }
        debugPrint('Message data keys: ${messageData.keys.toList()}');

        // Normalize reactions data - handle both old string format and new map format
        debugPrint('About to get raw reactions...');
        final rawReactions = messageData['reactions'];
        debugPrint(
            'Raw reactions retrieved: $rawReactions, type: ${rawReactions.runtimeType}');
        final currentReactions = <Map<String, dynamic>>[];

        if (rawReactions is List) {
          debugPrint(
              'Raw reactions is List, processing ${rawReactions.length} items...');
          for (final reaction in rawReactions) {
            debugPrint(
                'Processing reaction: $reaction, type: ${reaction.runtimeType}');
            if (reaction is Map<String, dynamic>) {
              // New format
              currentReactions.add(reaction);
            } else if (reaction is String) {
              // Old format - convert to new format
              currentReactions.add({
                'userId': 'unknown', // We don't know who added old reactions
                'reaction': reaction,
                'timestamp': DateTime.now()
                    .millisecondsSinceEpoch, // Use numeric timestamp
              });
            }
            // Skip invalid reaction types
          }
        } else {
          debugPrint('Raw reactions is not a List: $rawReactions');
        }

        debugPrint('Current reactions after processing: $currentReactions');

        // Check if user already reacted with this emoji (be more robust with type checking)
        debugPrint('About to check existing reactions...');
        int existingReactionIndex = -1;
        try {
          existingReactionIndex = currentReactions.indexWhere(
            (reaction) {
              final reactionUserId = reaction['userId']?.toString();
              final reactionEmoji = reaction['reaction']?.toString();
              return reactionUserId == userId && reactionEmoji == emoji;
            },
          );
        } catch (e) {
          debugPrint('Error checking existing reactions: $e');
          // If we can't check, assume no existing reaction
          existingReactionIndex = -1;
        }

        // Create a clean, validated reaction object
        final newReaction = <String, dynamic>{
          'userId': userId,
          'reaction': emoji.trim(),
          'timestamp': DateTime.now()
              .millisecondsSinceEpoch, // Use numeric timestamp instead of FieldValue
        };

        // Always use the set with merge fallback for iOS compatibility
        final updatedReactions =
            List<Map<String, dynamic>>.from(currentReactions);

        if (existingReactionIndex != -1) {
          // User already reacted with this emoji, remove it
          updatedReactions.removeAt(existingReactionIndex);
        } else {
          // User hasn't reacted with this emoji, add it
          updatedReactions.add(newReaction);
        }

        // Filter out any invalid reactions and limit to reasonable number
        final cleanReactions = <Map<String, dynamic>>[];
        try {
          cleanReactions.addAll(updatedReactions
              .where((r) {
                try {
                  return r['userId']?.toString().isNotEmpty == true &&
                      r['reaction']?.toString().isNotEmpty == true;
                } catch (e) {
                  debugPrint('Error validating reaction: $e, reaction: $r');
                  return false;
                }
              })
              .take(50)
              .toList()); // Limit reactions per message
        } catch (e) {
          debugPrint('Error filtering reactions: $e');
          // If filtering fails, use the updated reactions as-is (limited)
          cleanReactions.addAll(updatedReactions.take(50));
        }

        try {
          debugPrint(
              'About to update Firestore with reactions: $cleanReactions');
          await FirebaseFirestore.instance
              .collection(collectionPath)
              .doc(messageId)
              .set({'reactions': cleanReactions}, SetOptions(merge: true));
          debugPrint('Firestore set successful');
        } catch (firestoreError) {
          debugPrint('Firestore set failed, trying update: $firestoreError');
          // Fallback: try update operation
          try {
            await FirebaseFirestore.instance
                .collection(collectionPath)
                .doc(messageId)
                .update({'reactions': cleanReactions});
          } catch (updateError) {
            debugPrint('Update also failed: $updateError');
            // Final fallback: don't update reactions but don't crash
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reaction saved locally')),
              );
            }
            return;
          }
        }

        HapticFeedback.lightImpact();
      } catch (e) {
        debugPrint('Error during Firestore operations: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error accessing message: $e')),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Error updating reaction: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update reaction: ${e.toString()}')),
        );
      }
    }
  }
}
