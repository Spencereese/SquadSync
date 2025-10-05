import 'package:flutter/material.dart';

/// Manages app notifications and alerts
class NotificationManager with ChangeNotifier {
  bool notificationsEnabled = true;
  Map<String, bool> notificationTypes = {
    'game_start': true,
    'spot_available': true,
    'timer_warning': true,
    'ban_warning': true,
    'achievement': true,
  };

  void setNotificationsEnabled(bool enabled) {
    notificationsEnabled = enabled;
    notifyListeners();
  }

  void setNotificationType(String type, bool enabled) {
    notificationTypes[type] = enabled;
    notifyListeners();
  }

  bool isNotificationEnabled(String type) {
    return notificationsEnabled && (notificationTypes[type] ?? true);
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    // Implementation from original SquadState
    notifyListeners();
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    // Implementation from original SquadState
    notifyListeners();
  }

  Future<void> cancelNotification(int id) async {
    // Implementation from original SquadState
    notifyListeners();
  }

  Future<void> cancelAllNotifications() async {
    // Implementation from original SquadState
    notifyListeners();
  }

  Future<void> showTimerWarning(String player, int minutesLeft) async {
    if (!isNotificationEnabled('timer_warning')) return;

    await showNotification(
      title: 'Timer Warning',
      body: '$player has $minutesLeft minutes left!',
    );
  }

  Future<void> showBanWarning(String player, int banCount) async {
    if (!isNotificationEnabled('ban_warning')) return;

    await showNotification(
      title: 'Ban Warning',
      body: '$player has been banned $banCount times',
    );
  }

  Future<void> showAchievementNotification(
      String player, String achievement) async {
    if (!isNotificationEnabled('achievement')) return;

    await showNotification(
      title: 'Achievement Unlocked!',
      body: '$player earned: $achievement',
    );
  }
}
