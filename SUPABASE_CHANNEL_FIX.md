# Supabase Realtime Channel Rate Limit Fix

## Problem
Getting `RealtimeSubscribeException: ChannelRateLimitReached: Too many channels` error when initializing chat.

## Root Cause
The app was creating multiple Realtime channels without proper cleanup:
- **Messages channel** (`messages_$chatId`)
- **Typing channel** (`typing:$chatGroupId` or `typing_$chatId`)
- **Presence channel** (`presence:$chatGroupId`)
- **Voice room channels** (`voice_room:$roomId`)
- **Lobby channels** (`lobbies_$lobbyId`)

Channels were being created but not properly removed before creating new ones, leading to channel accumulation and hitting Supabase's rate limit (typically 100 channels per client).

## Solution Applied

### 1. **Proper Channel Cleanup Before Creation**
Added channel removal before creating new channels in all notifiers:

**ChatNotifier** ([chat_notifier.dart](lib/presentation/notifiers/chat_notifier.dart)):
```dart
Future<void> _initializePresenceChannel(String chatGroupId) async {
  // Remove existing channel first to avoid duplicates
  if (_presenceChannel != null) {
    await supabase.removeChannel(_presenceChannel!);
    _presenceChannel = null;
  }
  _presenceChannel = supabase.channel('presence:$chatGroupId');
  // ... rest of setup
}
```

**MessageNotifier** ([message_notifier.dart](lib/presentation/notifiers/message_notifier.dart)):
```dart
Future<void> _initializeTypingChannel(String chatGroupId) async {
  // Remove existing channel first to avoid duplicates
  if (_typingChannel != null) {
    await supabase.removeChannel(_typingChannel!);
    _typingChannel = null;
  }
  _typingChannel = supabase.channel('typing:$chatGroupId');
  // ... rest of setup
}
```

**MessageService** ([message_service.dart](lib/services/message_service.dart)):
```dart
// Cleanup existing channel first
if (_messageChannel != null) {
  _messageChannel!.unsubscribe();
  _messageChannel = null;
}
_messageChannel = _supabase.channel('messages_$chatId')
```

### 2. **Channel Monitoring & Diagnostics**
Added utilities to [supabase_service.dart](lib/services/supabase_service.dart):
```dart
/// Get active channel count
static int get activeChannelCount => client.getChannels().length;

/// Check if approaching channel limit (80+ channels)
static bool get isApproachingChannelLimit => activeChannelCount > 80;

/// Log channel usage for debugging
static void logChannelUsage() {
  final channels = client.getChannels();
  debugPrint('🔔 Active Supabase channels: ${channels.length}');
  if (channels.length > 50) {
    debugPrint('⚠️ High channel count detected. Consider cleanup.');
  }
}
```

### 3. **Proactive Monitoring in Chat Init**
Added channel count check in ChatNotifier initialization:
```dart
Future<void> initializeChat(String chatGroupId, ChatType chatType) async {
  // Monitor channel usage
  if (SupabaseService.isApproachingChannelLimit) {
    debugPrint('⚠️ WARNING: Approaching Supabase channel limit');
    SupabaseService.logChannelUsage();
  }
  // ... rest of initialization
}
```

### 4. **Error Handling for Channel Errors**
Added proper error handling for `channelError` status:

**ChatNotifier**:
```dart
.subscribe((status, error) async {
  if (status == RealtimeSubscribeStatus.subscribed) {
    await _presenceChannel!.track({...});
  } else if (status == RealtimeSubscribeStatus.channelError) {
    debugPrint('❌ ChatNotifier: Presence channel error: $error');
    await supabase.removeChannel(_presenceChannel!);
    _presenceChannel = null;
  }
});
```

**MessageNotifier**:
```dart
.subscribe((status, error) {
  if (status == RealtimeSubscribeStatus.subscribed) {
    debugPrint('MessageNotifier: Typing channel subscribed');
  } else if (status == RealtimeSubscribeStatus.channelError) {
    debugPrint('❌ MessageNotifier: Typing channel error: $error');
    supabase.removeChannel(_typingChannel!).then((_) {
      _typingChannel = null;
    });
  }
});
```

### 5. **Async/Await Consistency**
Changed void methods to `Future<void>` to properly await channel cleanup:
- `_initializePresenceChannel()` → `Future<void>`
- `_initializeTypingChannel()` → `Future<void>`
- `_startSupabaseMessagesStream()` → `Future<void>`

## Testing

### Manual Testing Checklist
- [ ] Navigate between different chat groups
- [ ] Open and close multiple chats in sequence
- [ ] Check console for channel count warnings
- [ ] Verify no "Too many channels" error appears
- [ ] Confirm typing indicators still work
- [ ] Verify presence tracking still functions
- [ ] Test voice room channel creation/cleanup

### Debug Commands
```dart
// Check active channel count
print('Active channels: ${SupabaseService.activeChannelCount}');

// Log all channels
SupabaseService.logChannelUsage();

// Check if approaching limit
print('Approaching limit: ${SupabaseService.isApproachingChannelLimit}');
```

## Best Practices Going Forward

1. **Always remove before recreating**: Any time you create a new channel, check if one exists and remove it first
2. **Monitor channel counts**: Use `SupabaseService.activeChannelCount` to track usage
3. **Cleanup on dispose**: Ensure all notifiers properly dispose channels in their cleanup methods
4. **Use consistent naming**: Stick to one channel naming pattern (e.g., `typing:$chatGroupId` vs `typing_$chatId`)
5. **Handle errors**: Always check for `RealtimeSubscribeStatus.channelError` and cleanup

## Files Modified
- [lib/presentation/notifiers/chat_notifier.dart](lib/presentation/notifiers/chat_notifier.dart)
- [lib/presentation/notifiers/message_notifier.dart](lib/presentation/notifiers/message_notifier.dart)
- [lib/services/message_service.dart](lib/services/message_service.dart)
- [lib/services/supabase_service.dart](lib/services/supabase_service.dart)

## Related Documentation
- [SUPABASE_FUNCTIONS_INVENTORY.md](lib/diagnostic/SUPABASE_FUNCTIONS_INVENTORY.md) - Real-time configuration reference
- [SUPABASE_2_12_UPGRADE.md](SUPABASE_2_12_UPGRADE.md) - Supabase upgrade notes
