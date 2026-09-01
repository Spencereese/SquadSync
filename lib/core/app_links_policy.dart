import 'dart:io';

import 'package:flutter/foundation.dart';

/// iOS Simulator should not consume a leftover universal / app link at
/// launch. That leftover is what shows "Open in Cod Squad?" over ChatScreen.
/// Physical devices (debug or release) keep full universal-link handling.
bool shouldConsumeLaunchAppLink({bool? isIosSimulator}) {
  return !(isIosSimulator ?? detectIosSimulator());
}

/// Runtime iOS Simulator detection. Physical devices return false.
bool detectIosSimulator() {
  if (kIsWeb) return false;
  try {
    if (!Platform.isIOS) return false;
  } catch (_) {
    return false;
  }
  final env = Platform.environment;
  return env.containsKey('SIMULATOR_DEVICE_NAME') ||
      env.containsKey('SIMULATOR_UDID') ||
      env.containsKey('SIMULATOR_ROOT');
}
