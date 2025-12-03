import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/squad.dart';

final currentSquadIdProvider = StateProvider<String?>((ref) => null);

final currentSquadProvider =
    AsyncNotifierProvider<CurrentSquadNotifier, Squad?>(
        () => CurrentSquadNotifier());

class CurrentSquadNotifier extends AsyncNotifier<Squad?> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  /// Safely parse timestamp from Firestore data (handles both Timestamp and String)
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        // If parsing fails, return null
        return null;
      }
    }
    return null;
  }

  @override
  FutureOr<Squad?> build() {
    final squadId = ref.watch(currentSquadIdProvider);
    _subscription?.cancel();
    _subscription = null;

    if (squadId == null) {
      return null;
    }

    ref.onDispose(() {
      _subscription?.cancel();
    });

    final docRef = FirebaseFirestore.instance.collection('squads').doc(squadId);

    // Set loading state
    state = const AsyncLoading();

    return docRef.get().then((doc) {
      if (!doc.exists) {
        state = const AsyncData(null);
        return null;
      }

      final squad = SquadFirestore.fromFirestore(doc);
      state = AsyncData(squad);

      // Listen to changes
      _subscription = docRef.snapshots().listen(
        (snapshot) {
          if (!snapshot.exists) {
            state = const AsyncData(null);
            return;
          }
          final updatedSquad = SquadFirestore.fromFirestore(snapshot);
          state = AsyncData(updatedSquad);
        },
        onError: (error, stackTrace) {
          state = AsyncError(error, stackTrace);
        },
      );

      return squad;
    }).catchError((error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    });
  }

  Future<void> claimSpot(String spotNumber) async {
    final squad = state.value;
    if (squad == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final currentClaim = squad.spotClaims[spotNumber];

    // Can only claim if spot is null or already claimed by this user
    if (currentClaim != null && currentClaim != uid) return;

    // Check if within maxSpots
    if (squad.maxSpots != null && int.tryParse(spotNumber) == null ||
        int.parse(spotNumber) > squad.maxSpots!) {
      return;
    }

    await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({
      'spotClaims.$spotNumber': uid,
      'lastActivity': FieldValue.serverTimestamp(),
    });

    // Bump squad if it's public
    await _bumpSquadIfPublic();
  }

  Future<void> unclaimSpot(String spotNumber) async {
    final squad = state.value;
    if (squad == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final currentClaim = squad.spotClaims[spotNumber];

    // Can only unclaim own spot
    if (currentClaim != uid) return;

    await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({
      'spotClaims.$spotNumber': null,
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startPeacockTimer(String uid, Duration duration) async {
    final squad = state.value;
    if (squad == null) return;

    final endTime = Timestamp.fromDate(DateTime.now().add(duration));
    final peacockTimer = PeacockTimer(endTime: endTime, isActive: true);

    await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({
      'peacockTimers.$uid': peacockTimer.toJson(),
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelPeacockTimer(String uid) async {
    final squad = state.value;
    if (squad == null) return;

    await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({
      'peacockTimers.$uid': FieldValue.delete(),
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setStatus(String uid, String status) async {
    final squad = state.value;
    if (squad == null) return;

    await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({
      'userStatuses.$uid': status,
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLastActivity() async {
    final squad = state.value;
    if (squad == null) return;

    await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({
      'lastActivity': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updatePrimaryGame({
    required String? gameId,
    required String? gameName,
    required int? maxSpots,
  }) async {
    final squadId = ref.read(currentSquadIdProvider);
    if (squadId == null) return;

    await FirebaseFirestore.instance.collection('squads').doc(squadId).update({
      'primaryGameId': gameId,
      'primaryGameName': gameName,
      'maxSpots': maxSpots,
    });
  }

  Future<void> bumpSquad() async {
    final squadId = state.valueOrNull?.id;
    if (squadId == null) return;

    final squadDoc = await FirebaseFirestore.instance
        .collection('squads')
        .doc(squadId)
        .get();
    final lastBump = _parseTimestamp(squadDoc['bumpTimestamp']);

    if (lastBump != null &&
        DateTime.now().difference(lastBump) < Duration(hours: 1)) {
      throw Exception("Can only bump once per hour");
    }

    await FirebaseFirestore.instance.collection('squads').doc(squadId).update({
      'bumpTimestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _bumpSquadIfPublic() async {
    final squad = state.value;
    if (squad == null || !squad.isPublic) return;

    try {
      final squadDoc = await FirebaseFirestore.instance
          .collection('squads')
          .doc(squad.id)
          .get();
      final lastBump = _parseTimestamp(squadDoc['bumpTimestamp']);

      // 5-minute cooldown for activity-based bumping
      if (lastBump != null &&
          DateTime.now().difference(lastBump) < Duration(minutes: 5)) {
        return; // Too soon, skip bump
      }

      await FirebaseFirestore.instance
          .collection('squads')
          .doc(squad.id)
          .update({
        'bumpTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Ignore bump errors to not interrupt main flow
    }
  }

  Future<void> leaveSquad() async {
    final squad = state.value;
    if (squad == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final batch = FirebaseFirestore.instance.batch();
    final docRef =
        FirebaseFirestore.instance.collection('squads').doc(squad.id);

    // Remove from memberUids
    batch.update(docRef, {
      'memberUids': FieldValue.arrayRemove([uid]),
      'lastActivity': FieldValue.serverTimestamp(),
    });

    // Clear spots claimed by this user
    final spotUpdates = <String, dynamic>{};
    squad.spotClaims.forEach((spot, claimUid) {
      if (claimUid == uid) {
        spotUpdates['spotClaims.$spot'] = null;
      }
    });

    // Clear peacock timer
    if (squad.peacockTimers.containsKey(uid)) {
      spotUpdates['peacockTimers.$uid'] = FieldValue.delete();
    }

    // Clear status
    spotUpdates['userStatuses.$uid'] = FieldValue.delete();

    if (spotUpdates.isNotEmpty) {
      batch.update(docRef, spotUpdates);
    }

    await batch.commit();

    // Clear current squad
    ref.read(currentSquadIdProvider.notifier).state = null;
  }
}
