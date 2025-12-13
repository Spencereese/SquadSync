import 'dart:ui' as ui;
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:riverpod/riverpod.dart';
import '../../domain/entities/system_state.dart';
import '../../domain/repositories/system_repository.dart';
import '../../core/injection.dart';
import '../../notification_service.dart';
import '../controllers/game_theme_controller.dart';

class SystemNotifier extends AsyncNotifier<SystemState> {
  late final SystemRepository _repository;

  @override
  Future<SystemState> build() async {
    // Get repository from provider
    _repository = ref.read(systemRepositoryProvider);

    // Load system state first
    final systemState = await _repository.loadSystemState();

    // AFTER initialization, schedule brightness listener setup
    Future.microtask(() => _setupBrightnessListener());

    return systemState;
  }

  /// Setup listener for system brightness changes
  void _setupBrightnessListener() {
    // Get initial brightness
    final platformDispatcher = ui.PlatformDispatcher.instance;
    final initialBrightness = platformDispatcher.platformBrightness;

    // Update game theme controller with current brightness
    _updateGameThemeBrightness(initialBrightness);

    // Listen for brightness changes
    platformDispatcher.onPlatformBrightnessChanged = () {
      final newBrightness = platformDispatcher.platformBrightness;
      _updateGameThemeBrightness(newBrightness);
    };
  }

  /// Update game theme controller with system brightness
  void _updateGameThemeBrightness(Brightness brightness) {
    try {
      // Use read instead of modifying during build
      final gameThemeController =
          ref.read(gameThemeControllerProvider.notifier);
      gameThemeController.updateSystemBrightness(brightness);
    } catch (e) {
      // Silently handle if game theme controller not available
    }
  }

  /// Get current system brightness
  Brightness getSystemBrightness() {
    return ui.PlatformDispatcher.instance.platformBrightness;
  }

  Future<void> updateThemeMode(ThemeMode themeMode) async {
    await _repository.updateThemeMode(themeMode);
    state = await AsyncValue.guard(() => _repository.loadSystemState());

    // Update game theme brightness based on theme mode
    final brightness = _getBrightnessForThemeMode(themeMode);
    _updateGameThemeBrightness(brightness);
  }

  /// Convert ThemeMode to Brightness
  Brightness _getBrightnessForThemeMode(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.system:
        return getSystemBrightness();
    }
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

// Backward compatibility alias
final systemNotifierProvider =
    AsyncNotifierProvider<SystemNotifier, SystemState>(
  SystemNotifier.new,
);
