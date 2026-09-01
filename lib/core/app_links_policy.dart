import 'dart:io';

import 'package:flutter/foundation.dart';

/// Whether to consume `getInitialLink()` at launch.
/// iOS Simulator skips the leftover launch URL that shows
/// "Open in Cod Squad?" over ChatScreen. Physical devices keep it.
bool shouldConsumeLaunchAppLink({bool? isIosSimulator}) {
  return !(isIosSimulator ?? detectIosSimulator());
}

/// Cold/warm AppLinks after launch. Always subscribe — do not black out Dart.
bool shouldSubscribeUriLinkStream() => true;

/// Simulator skips only the initial launch link; [uriLinkStream] stays on.
({bool consumeInitialLink, bool subscribeUriLinkStream}) planAppLinkListen({
  bool? isIosSimulator,
}) {
  return (
    consumeInitialLink:
        shouldConsumeLaunchAppLink(isIosSimulator: isIosSimulator),
    subscribeUriLinkStream: shouldSubscribeUriLinkStream(),
  );
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
