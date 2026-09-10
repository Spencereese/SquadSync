/// iOS Simulator / desktop Workmanager failures are expected.
bool isExpectedWorkmanagerSkip(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('simulator') ||
      text.contains('not implemented') ||
      text.contains('unhandledmethod') ||
      text.contains('missingpluginexception') ||
      text.contains('unregistered') ||
      text.contains('channel-error') ||
      text.contains('unable to establish') ||
      text.contains('no implementation found');
}
