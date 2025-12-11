import 'package:riverpod/riverpod.dart';
import '../../domain/entities/system_state.dart';
import '../../domain/repositories/system_repository.dart';
import '../../core/injection.dart';
import '../../notification_service.dart';

class SystemNotifier extends AutoDisposeAsyncNotifier<SystemState> {
  late final SystemRepository _repository;

  @override
  Future<SystemState> build() async {
    // Get repository from provider
    _repository = ref.read(systemRepositoryProvider);
    return await _repository.loadSystemState();
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    await _repository.updateThemeMode(themeMode);
    state = await AsyncValue.guard(() => _repository.loadSystemState());
  }

  Future<void> trackAnalyticsEvent(
      String event, Map<String, dynamic> data) async {
    await _repository.trackAnalyticsEvent(event, data);
    // No state refresh needed for analytics
  }

  Future<void> sendLocalNotification(String title, String body,
      {String? payload}) async {
    await _repository.sendLocalNotification(title, body,
        data: payload != null ? {'payload': payload} : null);
    // No state refresh needed for notifications
  }

  Future<void> updateNotificationSettings(Map<String, bool> settings) async {
    await _repository.updateNotificationSettings(settings);
    state = await AsyncValue.guard(() => _repository.loadSystemState());
  }

  Future<bool> checkAvailability() async {
    return await _repository.checkAvailability();
  }

  Future<void> banUser(String userId, String reason) async {
    await _repository.banUser(userId, reason);
    state = await AsyncValue.guard(() => _repository.loadSystemState());
  }

  Future<void> unbanUser(String userId) async {
    await _repository.unbanUser(userId);
    state = await AsyncValue.guard(() => _repository.loadSystemState());
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
