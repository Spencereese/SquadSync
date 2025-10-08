import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notification_service.dart';

/// Manages availability scheduling and notifications
class AvailabilityManager with ChangeNotifier {
  List<Map<String, dynamic>> scheduledTimes = [];
  bool _hasNewAvailability = false;
  DateTime _lastUpdate = DateTime.now();

  bool get hasNewAvailability => _hasNewAvailability;

  void setNewAvailability(bool value) {
    _hasNewAvailability = value;
    notifyListeners();
  }

  void syncWithFirestore() {
    FirebaseFirestore.instance
        .collection('schedules')
        .snapshots()
        .listen((snapshot) {
      scheduledTimes = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      // Check for new availability
      bool newAvailability = scheduledTimes.any((time) =>
          time['timestamp'] != null &&
          DateTime.tryParse(time['timestamp'] ?? '') != null &&
          DateTime.parse(time['timestamp']).isAfter(_lastUpdate));
      if (newAvailability) {
        _hasNewAvailability = true;
        NotificationService.sendNotification(
            'New Availability', 'A new schedule has been added!');
      }
      _lastUpdate = DateTime.now();
      debugPrint('Synced scheduledTimes from schedules: $scheduledTimes');
      notifyListeners();
    });
  }
}
