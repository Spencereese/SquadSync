import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:squadsync/features/push/data/push_notifications.dart';
import 'package:squadsync/features/push/domain/squad_push.dart';

/// Opens Firebase only when the native config files are present.
/// A missing plist or json stays on "Notifications off: not set up yet".
Future<PushNotifications> openPushNotifications() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } on Object {
    return const UnconfiguredPushNotifications(setupMissing: true);
  }
  try {
    final messaging = FirebaseMessaging.instance;
    final initial = await messaging.getInitialMessage();
    return FirebasePushNotifications(
      messaging,
      launch: initial == null ? null : parseSquadPush(initial.data),
    );
  } on Object {
    return const UnconfiguredPushNotifications(setupMissing: true);
  }
}

class FirebasePushNotifications implements PushNotifications {
  FirebasePushNotifications(this._messaging, {this._launch});

  final FirebaseMessaging _messaging;
  SquadPush? _launch;

  @override
  Future<PushAvailability> availability() async {
    try {
      final settings = await _messaging.requestPermission();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return const PushAvailability.off();
      final token = await _registrationId();
      final platform = _platform;
      if (token == null || token.isEmpty || platform == null) {
        return const PushAvailability.off();
      }
      return PushAvailability.on(token: token, platform: platform);
    } on Object {
      return const PushAvailability.off();
    }
  }

  /// The id FCM HTTP v1 uses as the direct-send target. [onRegistered]
  /// emits it after [FirebaseMessaging.register].
  Future<String?> _registrationId() async {
    final done = Completer<String?>();
    final subscription = _messaging.onRegistered.listen((id) {
      if (!done.isCompleted) done.complete(id);
    });
    try {
      await _messaging.register();
      return await done.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => null,
      );
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Stream<SquadPush> get taps {
    return Stream.multi((controller) {
      final opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final push = parseSquadPush(message.data);
        if (push != null) controller.add(push);
      });
      controller.onCancel = opened.cancel;
    });
  }

  @override
  Stream<PushAvailability> get tokenChanges {
    return _messaging.onRegistered.map((id) {
      final platform = _platform;
      if (id.isEmpty || platform == null) return const PushAvailability.off();
      return PushAvailability.on(token: id, platform: platform);
    });
  }

  @override
  SquadPush? consumeLaunch() {
    final pending = _launch;
    _launch = null;
    return pending;
  }

  @override
  Future<void> deleteLocalToken() async {
    try {
      await _messaging.unregister();
    } on Object {
      // The row is still removed by the repository. A local miss stays honest.
    }
  }
}

String? get _platform {
  if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
  if (defaultTargetPlatform == TargetPlatform.android) return 'android';
  return null;
}
