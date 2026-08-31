import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/realtime_subscribe.dart';
import 'package:squad_sync/core/session_guard.dart';
import 'package:squad_sync/core/workmanager_skip.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('seven sibling channels are not a nuke-all', () {
    expect(shouldNukeAllRealtimeChannels(7), isFalse);
    expect(shouldNukeAllRealtimeChannels(81), isTrue);
  });

  test('channelError recovers once then stops', () {
    expect(shouldResubscribeAfterChannelError(0), isTrue);
    expect(shouldResubscribeAfterChannelError(1), isFalse);
    expect(isDeadRealtimeStatus(RealtimeSubscribeStatus.channelError), isTrue);
    expect(isDeadRealtimeStatus(RealtimeSubscribeStatus.subscribed), isFalse);
  });

  test('expired JWT is not a usable signed-in session', () {
    expect(
      isUsableAuthSession(hasUser: true, expiresAtSeconds: 1),
      isFalse,
    );
    expect(
      isAuthenticatedFromExpiry(
        hasUser: true,
        expiresAtSeconds: 1,
      ),
      isFalse,
    );
  });

  test('Workmanager simulator errors are expected skips', () {
    expect(
      isExpectedWorkmanagerSkip('MissingPluginException(No implementation found)'),
      isTrue,
    );
    expect(isExpectedWorkmanagerSkip('disk full'), isFalse);
  });
}

bool isAuthenticatedFromExpiry({
  required bool hasUser,
  required int? expiresAtSeconds,
}) {
  return isUsableAuthSession(
    hasUser: hasUser,
    expiresAtSeconds: expiresAtSeconds,
  );
}
