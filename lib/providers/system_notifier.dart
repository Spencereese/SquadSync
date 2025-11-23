import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'system_notifier.freezed.dart';
part 'system_notifier.g.dart';

@freezed
class SystemState with _$SystemState {
  const factory SystemState({
    required List<Map<String, dynamic>> notifications,
    required List<Map<String, dynamic>> availabilitySlots,
    required Map<String, Map<String, bool>> dailyBanVotes,
    required List<Map<String, dynamic>> bans,
    required bool hasNewNotifications,
    required bool hasNewAvailability,
    required bool isInitialized,
    String? errorMessage,
  }) = _SystemState;

  factory SystemState.initial() => const SystemState(
        notifications: [],
        availabilitySlots: [],
        dailyBanVotes: {},
        bans: [],
        hasNewNotifications: false,
        hasNewAvailability: false,
        isInitialized: false,
        errorMessage: null,
      );
}

@riverpod
class SystemNotifier extends _$SystemNotifier {
  late final FirebaseAuth _auth;
  late final FirebaseFirestore _firestore;

  @override
  Future<SystemState> build({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) async {
    _auth = auth ?? FirebaseAuth.instance;
    _firestore = firestore ?? FirebaseFirestore.instance;

    // Initialize system services
    final initialState = await _initializeSystem();

    return initialState;
  }

  Future<SystemState> _initializeSystem() async {
    try {
      // Load notifications from Firestore
      final user = _auth.currentUser;
      if (user != null) {
        final notificationsSnapshot = await _firestore
            .collection('notifications')
            .where('userId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .limit(50)
            .get();

        final notifications =
            notificationsSnapshot.docs.map((doc) => doc.data()).toList();

        // Load availability slots
        final availabilitySnapshot = await _firestore
            .collection('availability')
            .where('userId', isEqualTo: user.uid)
            .get();

        final availabilitySlots =
            availabilitySnapshot.docs.map((doc) => doc.data()).toList();

        // Load ban votes
        final banVotesSnapshot = await _firestore
            .collection('ban_votes')
            .where('date',
                isEqualTo: DateTime.now().toIso8601String().split('T')[0])
            .get();

        final dailyBanVotes = <String, Map<String, bool>>{};
        for (var doc in banVotesSnapshot.docs) {
          final data = doc.data();
          final voterId = data['voterId'] as String;
          final targetId = data['targetId'] as String;
          final vote = data['vote'] as bool;

          if (!dailyBanVotes.containsKey(voterId)) {
            dailyBanVotes[voterId] = {};
          }
          dailyBanVotes[voterId]![targetId] = vote;
        }

        return SystemState.initial().copyWith(
          notifications: notifications,
          availabilitySlots: availabilitySlots,
          dailyBanVotes: dailyBanVotes,
          isInitialized: true,
        );
      } else {
        return SystemState.initial().copyWith(isInitialized: true);
      }
    } catch (e) {
      return SystemState.initial().copyWith(
        errorMessage: e.toString(),
        isInitialized: true,
      );
    }
  }

  // Notification management
  Future<void> addNotification(Map<String, dynamic> notification) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Add to Firestore
      await _firestore.collection('notifications').add({
        ...notification,
        'userId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      final currentNotifications =
          List<Map<String, dynamic>>.from(state.value!.notifications);
      currentNotifications.insert(0, notification); // Add to beginning

      final newState = state.value!.copyWith(
        notifications: currentNotifications,
        hasNewNotifications: true,
      );
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> markNotificationsAsRead() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Update all unread notifications in Firestore
      final batch = _firestore.batch();
      final unreadNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      final newState = state.value!.copyWith(hasNewNotifications: false);
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('notifications').doc(notificationId).delete();

      final currentNotifications =
          List<Map<String, dynamic>>.from(state.value!.notifications);
      currentNotifications.removeWhere((n) => n['id'] == notificationId);

      final newState =
          state.value!.copyWith(notifications: currentNotifications);
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Availability management
  Future<void> addAvailabilitySlot(Map<String, dynamic> slot) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Add to Firestore
      await _firestore.collection('availability').add({
        ...slot,
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final currentSlots =
          List<Map<String, dynamic>>.from(state.value!.availabilitySlots);
      currentSlots.add(slot);

      final newState = state.value!.copyWith(
        availabilitySlots: currentSlots,
        hasNewAvailability: true,
      );
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> removeAvailabilitySlot(String slotId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('availability').doc(slotId).delete();

      final currentSlots =
          List<Map<String, dynamic>>.from(state.value!.availabilitySlots);
      currentSlots.removeWhere((s) => s['id'] == slotId);

      final newState = state.value!.copyWith(availabilitySlots: currentSlots);
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateAvailabilitySlot(
      String slotId, Map<String, dynamic> updates) async {
    try {
      // Update in Firestore
      await _firestore.collection('availability').doc(slotId).update(updates);

      final currentSlots =
          List<Map<String, dynamic>>.from(state.value!.availabilitySlots);
      final index = currentSlots.indexWhere((s) => s['id'] == slotId);

      if (index != -1) {
        currentSlots[index] = {...currentSlots[index], ...updates};

        final newState = state.value!.copyWith(availabilitySlots: currentSlots);
        state = AsyncValue.data(newState);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Ban voting system
  Future<void> submitBanVote(String targetUserId, bool vote) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Submit vote to Firestore
      await _firestore.collection('ban_votes').add({
        'voterId': user.uid,
        'targetId': targetUserId,
        'vote': vote,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'timestamp': FieldValue.serverTimestamp(),
      });

      final currentVotes =
          Map<String, Map<String, bool>>.from(state.value!.dailyBanVotes);
      currentVotes[targetUserId] ??= {};
      currentVotes[targetUserId]![user.uid] = vote;

      final newState = state.value!.copyWith(dailyBanVotes: currentVotes);
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> processBanVotes() async {
    try {
      // Simplified - just reset daily votes for now
      // TODO: Implement proper ban vote processing logic
      final newState = state.value!.copyWith(
        dailyBanVotes: {}, // Reset daily votes
      );
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Notification coordination
  Future<void> sendNotificationToUser(String userId, String title, String body,
      {Map<String, dynamic>? data}) async {
    try {
      // Add notification to Firestore for the user
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> sendNotificationToSquad(
      String squadId, String title, String body,
      {Map<String, dynamic>? data}) async {
    try {
      // Get squad members and send notification to each
      final squadDoc = await _firestore.collection('squads').doc(squadId).get();

      if (squadDoc.exists) {
        final squadData = squadDoc.data();
        final memberUids = squadData?['memberUids'] as List<dynamic>? ?? [];

        for (var uid in memberUids) {
          await _firestore.collection('notifications').add({
            'userId': uid,
            'title': title,
            'body': body,
            'data': data,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });
        }
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> scheduleNotification(
      DateTime scheduledTime, String title, String body,
      {Map<String, dynamic>? data}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Add scheduled notification to Firestore
      await _firestore.collection('scheduled_notifications').add({
        'userId': user.uid,
        'title': title,
        'body': body,
        'data': data,
        'scheduledTime': scheduledTime,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // System alerts
  void showSystemAlert(String message) {
    final alert = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'system',
      'title': 'System Alert',
      'message': message,
      'timestamp': DateTime.now(),
      'read': false,
    };

    addNotification(alert);
  }

  void showMaintenanceAlert(String message) {
    final alert = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'maintenance',
      'title': 'Maintenance Notice',
      'message': message,
      'timestamp': DateTime.now(),
      'read': false,
    };

    addNotification(alert);
  }

  // Cleanup methods
  Future<void> clearOldNotifications({Duration? olderThan}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final cutoff = olderThan ?? const Duration(days: 30);
      final cutoffDate = DateTime.now().subtract(cutoff);

      // Delete old notifications from Firestore
      final batch = _firestore.batch();
      final oldNotifications = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('timestamp', isLessThan: cutoffDate)
          .get();

      for (var doc in oldNotifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      final currentNotifications =
          List<Map<String, dynamic>>.from(state.value!.notifications);
      currentNotifications.removeWhere((n) {
        final timestamp = n['timestamp'] as DateTime?;
        return timestamp != null && timestamp.isBefore(cutoffDate);
      });

      final newState =
          state.value!.copyWith(notifications: currentNotifications);
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> resetDailyVotes() async {
    try {
      // Delete all ban votes for today from Firestore
      final today = DateTime.now().toIso8601String().split('T')[0];
      final batch = _firestore.batch();
      final todaysVotes = await _firestore
          .collection('ban_votes')
          .where('date', isEqualTo: today)
          .get();

      for (var doc in todaysVotes.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      final newState = state.value!.copyWith(dailyBanVotes: {});
      state = AsyncValue.data(newState);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
