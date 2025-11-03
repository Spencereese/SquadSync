import '../notification_service.dart';
import 'notification_manager.dart';
import 'squad_ui_manager.dart';
import 'availability_manager.dart';

/// Service responsible for coordinating notifications across the app.
///
/// This service handles the business logic for different types of notifications,
/// coordinating between local notifications, push notifications, and UI state
/// management. It provides a unified interface for triggering notifications
/// based on squad events, game outcomes, and user interactions.
///
/// Key responsibilities:
/// - Coordinate squad spot notifications with UI state
/// - Handle game outcome notifications (wins/losses)
/// - Manage notification clearing across different tabs
/// - Integrate local and push notification systems
class NotificationCoordinator {
  final NotificationManager _notificationManager;
  final SquadUIManager _uiManager;
  final AvailabilityManager _availabilityManager;

  NotificationCoordinator({
    required NotificationManager notificationManager,
    required SquadUIManager uiManager,
    required AvailabilityManager availabilityManager,
  })  : _notificationManager = notificationManager,
        _uiManager = uiManager,
        _availabilityManager = availabilityManager;

  /// Trigger a squad spot notification with UI state management
  ///
  /// Shows a local notification and updates UI state if the game is not muted/hidden
  void notifyNewSquadSpot(
      {String? gameName,
      required bool isGameMuted,
      required bool isGameHidden}) {
    if (gameName != null) {
      _uiManager.setNewSquadSpot(true, gameName);
    }

    if (gameName == null || (!isGameMuted && !isGameHidden)) {
      NotificationService.sendNotification(
          'New Squad Spot', 'A spot has been claimed or opened!');
    }
  }

  /// Clear notifications for a specific tab
  ///
  /// Handles clearing different types of notifications based on the tab index
  void clearNotificationsForTab(int tabIndex) {
    switch (tabIndex) {
      case 1: // Availability tab
        _availabilityManager.setNewAvailability(false);
        break;
      case 2: // Squad tab
        _uiManager.hasNewSquadSpot = false;
        break;
      case 3: // Chat tab
        _uiManager.setHasUnreadMessages(false);
        break;
    }
  }

  /// Notify about a squad win with detailed player information
  ///
  /// Sends a broadcast notification listing all walking players who won
  void notifySquadWin(List<String?> squadSpots, Map<String, String> statuses) {
    final walkingPlayers = squadSpots
        .where((spot) => spot != null && statuses[spot] == 'Walking')
        .cast<String>()
        .toList();

    if (walkingPlayers.isNotEmpty) {
      NotificationService.sendNotification(
          'Squad Win!', '${walkingPlayers.join(', ')} won a game!');
    }
  }

  /// Check if notifications are enabled for a specific type
  bool isNotificationEnabled(String type) {
    return _notificationManager.isNotificationEnabled(type);
  }

  /// Show a timer warning notification
  Future<void> showTimerWarning(String player, int minutesLeft) async {
    await _notificationManager.showTimerWarning(player, minutesLeft);
  }

  /// Show a ban warning notification
  Future<void> showBanWarning(String player, int banCount) async {
    await _notificationManager.showBanWarning(player, banCount);
  }

  /// Show an achievement notification
  Future<void> showAchievementNotification(
      String player, String achievement) async {
    await _notificationManager.showAchievementNotification(player, achievement);
  }
}
