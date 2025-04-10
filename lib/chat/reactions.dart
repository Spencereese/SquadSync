import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../app_theme.dart';
import '../../squad_state.dart';

class ReactionsWidget extends StatelessWidget {
  final String docId;
  const ReactionsWidget({super.key, required this.docId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!.displayName ??
        Provider.of<SquadState>(context, listen: false).displayName ??
        'User';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .doc(docId)
          .collection('reactions')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final reactions = snapshot.data!.docs;
        final reactionCounts = <String, Map<String, dynamic>>{};
        for (var reaction in reactions) {
          final emoji = reaction['emoji'] as String;
          final user = reaction['user'] as String;
          if (!reactionCounts.containsKey(emoji)) {
            reactionCounts[emoji] = {'count': 0, 'hasCurrentUser': false};
          }
          reactionCounts[emoji]!['count'] =
              (reactionCounts[emoji]!['count'] as int) + 1;
          if (user == currentUser) {
            reactionCounts[emoji]!['hasCurrentUser'] = true;
          }
        }
        return Padding(
          padding: const EdgeInsets.only(left: 40.0, top: 4.0),
          child: Wrap(
            spacing: 4,
            children: reactionCounts.entries
                .map((entry) => ReactionChip(
                      emoji: entry.key,
                      count: entry.value['count'] as int,
                      isCurrentUser: entry.value['hasCurrentUser'] as bool,
                      onTap: () => _addReaction(context, docId, entry.key),
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Future<void> _addReaction(
      BuildContext context, String docId, String emoji) async {
    final user = FirebaseAuth.instance.currentUser!.displayName ??
        Provider.of<SquadState>(context, listen: false).displayName ??
        'User';
    final querySnapshot = await FirebaseFirestore.instance
        .collection('chat')
        .doc(docId)
        .collection('reactions')
        .where('user', isEqualTo: user)
        .get();
    await Future.wait(querySnapshot.docs.map((doc) => doc.reference.delete()));
    await FirebaseFirestore.instance
        .collection('chat')
        .doc(docId)
        .collection('reactions')
        .add({
      'emoji': emoji,
      'user': user,
      'timestamp': FieldValue.serverTimestamp()
    });
  }
}

class ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isCurrentUser;
  final VoidCallback onTap;

  const ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.isCurrentUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Semantics(
        label: '$emoji reaction, $count times',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(12),
            border: isCurrentUser
                ? Border.all(color: AppTheme.accentColor, width: 1.5)
                : null,
          ),
          child: Text(
            '$emoji $count',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        )
            .animate(
              onPlay: (controller) => controller.forward(),
            )
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.1, 1.1),
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
            )
            .then()
            .scale(
              begin: const Offset(1.1, 1.1),
              end: const Offset(1.0, 1.0),
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOut,
            ),
      ),
    );
  }
}
