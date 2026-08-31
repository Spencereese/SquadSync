import 'package:supabase_flutter/supabase_flutter.dart';

/// Same cap as [kMaxChatRateLimitRetries] — one recovery subscribe.
const kMaxRealtimeResubscribe = 1;

/// Only nuke-all when we are actually near the client channel cap.
/// Seven live sibling channels (lobby/typing/messages/presence/badges)
/// are normal — do not treat that as orphaned.
bool shouldNukeAllRealtimeChannels(int activeChannelCount) {
  return activeChannelCount > 80;
}

/// One recovery subscribe after a dead channel. Do not loop.
bool shouldResubscribeAfterChannelError(
  int attemptsAlready, {
  int maxAttempts = kMaxRealtimeResubscribe,
}) {
  return attemptsAlready < maxAttempts;
}

bool isDeadRealtimeStatus(RealtimeSubscribeStatus status) {
  return status == RealtimeSubscribeStatus.channelError ||
      status == RealtimeSubscribeStatus.timedOut;
}
