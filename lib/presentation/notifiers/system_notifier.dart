import 'package:riverpod/riverpod.dart';
import '../../domain/entities/system_state.dart';
import '../../domain/usecases/load_system_state.dart';
import '../../domain/usecases/update_theme_mode.dart';
import '../../domain/usecases/track_analytics_event.dart';
import '../../domain/usecases/send_local_notification.dart';
import '../../domain/usecases/update_last_sync.dart';
import '../../domain/usecases/purge_old_data.dart';
import '../../domain/usecases/update_notification_settings.dart';
import '../../domain/usecases/check_availability.dart';
import '../../domain/usecases/ban_user.dart';
import '../../domain/usecases/unban_user.dart';
import '../../core/injection.dart' as di;
import '../../notification_service.dart';

class SystemNotifier extends AutoDisposeAsyncNotifier<SystemState> {
  late final LoadSystemState _loadSystemState;
  late final UpdateThemeMode _updateThemeMode;
  late final TrackAnalyticsEvent _trackAnalyticsEvent;
  late final SendLocalNotification _sendLocalNotification;
  late final UpdateLastSync _updateLastSync;
  late final PurgeOldData _purgeOldData;
  late final UpdateNotificationSettings _updateNotificationSettings;
  late final CheckAvailability _checkAvailability;
  late final BanUser _banUser;
  late final UnbanUser _unbanUser;

  @override
  Future<SystemState> build() async {
    // Get dependencies from get_it
    _loadSystemState = di.getIt<LoadSystemState>();
    _updateThemeMode = di.getIt<UpdateThemeMode>();
    _trackAnalyticsEvent = di.getIt<TrackAnalyticsEvent>();
    _sendLocalNotification = di.getIt<SendLocalNotification>();
    _updateLastSync = di.getIt<UpdateLastSync>();
    _purgeOldData = di.getIt<PurgeOldData>();
    _updateNotificationSettings = di.getIt<UpdateNotificationSettings>();
    _checkAvailability = di.getIt<CheckAvailability>();
    _banUser = di.getIt<BanUser>();
    _unbanUser = di.getIt<UnbanUser>();

    return await _loadSystemState();
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    await _updateThemeMode(themeMode);
    state = await AsyncValue.guard(() => _loadSystemState());
  }

  Future<void> trackAnalyticsEvent(
      String event, Map<String, dynamic> data) async {
    await _trackAnalyticsEvent(event, data);
    // No state refresh needed for analytics
  }

  Future<void> sendLocalNotification(String title, String body,
      {String? payload}) async {
    await _sendLocalNotification(title, body,
        data: payload != null ? {'payload': payload} : null);
    // No state refresh needed for notifications
  }

  Future<void> updateLastSync(DateTime timestamp) async {
    await _updateLastSync(timestamp);
    state = await AsyncValue.guard(() => _loadSystemState());
  }

  Future<void> purgeOldData() async {
    await _purgeOldData();
    state = await AsyncValue.guard(() => _loadSystemState());
  }

  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    await _updateNotificationSettings(settings);
    state = await AsyncValue.guard(() => _loadSystemState());
  }

  Future<bool> checkAvailability() async {
    return await _checkAvailability();
  }

  Future<void> banUser(String userId, String reason) async {
    await _banUser(userId, reason);
    state = await AsyncValue.guard(() => _loadSystemState());
  }

  Future<void> unbanUser(String userId) async {
    await _unbanUser(userId);
    state = await AsyncValue.guard(() => _loadSystemState());
  }

  /// Send push notification to multiple users
  ///
  /// [title] - Notification title
  /// [body] - Notification body
  /// [recipientUids] - List of user UIDs
  /// [data] - Optional data payload
  Future<void> sendPushNotification({
    required String title,
    required String body,
    required List<String> recipientUids,
    Map<String, dynamic>? data,
  }) async {
    await NotificationService.sendNotificationToUsers(
      title: title,
      body: body,
      recipientUids: recipientUids,
      data: data,
    );
  }
}

final systemNotifierProvider =
    AutoDisposeAsyncNotifierProvider<SystemNotifier, SystemState>(
  () => SystemNotifier(),
);
