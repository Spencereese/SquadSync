import 'package:supabase_flutter/supabase_flutter.dart';

/// Same cap as [kMaxChatRateLimitRetries] — one recovery subscribe.
const kMaxRealtimeResubscribe = 1;

/// Never nuke sibling typing/lobby/messages/presence/badges channels.
/// Cap is enforced by single-subscribe + one recovery, not a wipe.
bool shouldNukeAllRealtimeChannels(int activeChannelCount) {
  return false;
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
