import 'dart:io';
import 'package:flutter/services.dart';

/// iOS Live Activities integration for Dynamic Island and Lock Screen widgets
/// Requires native Swift implementation in ios/Runner/LiveActivityManager.swift
class LiveActivityManager {
  static const MethodChannel _channel =
      MethodChannel('com.squadsync/live_activities');

  static final LiveActivityManager _instance = LiveActivityManager._internal();
  factory LiveActivityManager() => _instance;
  LiveActivityManager._internal();

  bool _isSupported = false;

  /// Check if Live Activities are supported (iOS 16.1+)
  Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _channel.invokeMethod<bool>('isSupported');
      _isSupported = result ?? false;
      return _isSupported;
    } catch (e) {
      print('⚠️ Live Activities not supported: $e');
      return false;
    }
  }

  /// Start Live Activity for lobby momentum
  Future<String?> startLobbyActivity({
    required String lobbyId,
    required String gameName,
    required int currentPlayers,
    required int maxPlayers,
    required List<String> participantNames,
    String? gameImageUrl,
  }) async {
    if (!_isSupported) return null;

    try {
      final activityId = await _channel.invokeMethod<String>(
        'startLobbyActivity',
        {
          'lobbyId': lobbyId,
          'gameName': gameName,
          'currentPlayers': currentPlayers,
          'maxPlayers': maxPlayers,
          'participants': participantNames,
          'gameImageUrl': gameImageUrl,
        },
      );

      print('🎭 Started Live Activity: $activityId');
      return activityId;
    } catch (e) {
      print('❌ Failed to start Live Activity: $e');
      return null;
    }
  }

  /// Update existing Live Activity with new data
  Future<bool> updateLobbyActivity({
    required String activityId,
    required int currentPlayers,
    required List<String> participantNames,
  }) async {
    if (!_isSupported) return false;

    try {
      await _channel.invokeMethod('updateLobbyActivity', {
        'activityId': activityId,
        'currentPlayers': currentPlayers,
        'participants': participantNames,
      });

      return true;
    } catch (e) {
      print('❌ Failed to update Live Activity: $e');
      return false;
    }
  }

  /// Start Live Activity for spot timer
  Future<String?> startTimerActivity({
    required String lobbyId,
    required String gameName,
    required int spotIndex,
    required DateTime expiresAt,
  }) async {
    if (!_isSupported) return null;

    try {
      final activityId = await _channel.invokeMethod<String>(
        'startTimerActivity',
        {
          'lobbyId': lobbyId,
          'gameName': gameName,
          'spotIndex': spotIndex,
          'expiresAt': expiresAt.toIso8601String(),
        },
      );

      print('⏱️ Started Timer Activity: $activityId');
      return activityId;
    } catch (e) {
      print('❌ Failed to start Timer Activity: $e');
      return null;
    }
  }

  /// End Live Activity
  Future<void> endActivity(String activityId) async {
    if (!_isSupported) return;

    try {
      await _channel.invokeMethod('endActivity', {'activityId': activityId});
      print('✅ Ended Live Activity: $activityId');
    } catch (e) {
      print('❌ Failed to end Live Activity: $e');
    }
  }

  /// End all active Live Activities
  Future<void> endAllActivities() async {
    if (!_isSupported) return;

    try {
      await _channel.invokeMethod('endAllActivities');
      print('✅ Ended all Live Activities');
    } catch (e) {
      print('❌ Failed to end all Live Activities: $e');
    }
  }
}
