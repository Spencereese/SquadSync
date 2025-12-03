import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/current_squad_notifier.dart';

/// Service for automatically selecting a squad on app launch
Future<String?> autoSelectSquad(WidgetRef ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

  final data = userDoc.data() ?? {};
  final squadIds =
      (data['squadIds'] as List<dynamic>?)?.cast<String>() ?? <String>[];

  String? chosenId;

  // 1. Pinned squad first
  final pinned = data['pinnedSquadId'] as String?;
  if (pinned != null && squadIds.contains(pinned)) {
    chosenId = pinned;
  }
  // 2. Most recent by lastActivity
  else if (squadIds.isNotEmpty) {
    final query = await FirebaseFirestore.instance
        .collection('squads')
        .where('memberUids', arrayContains: user.uid)
        .orderBy('lastActivity', descending: true)
        .limit(1)
        .get();
    chosenId = query.docs.firstOrNull?.id;
  }

  if (chosenId != null) {
    ref.read(currentSquadIdProvider.notifier).state = chosenId;
  }

  return chosenId;
}
