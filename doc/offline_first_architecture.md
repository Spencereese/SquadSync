# SquadSync Offline-First Architecture Guide

## Overview

SquadSync now implements a comprehensive offline-first architecture with SQLite caching, background sync, and connectivity-aware operations. This enables users to interact with the app seamlessly even without internet connectivity.

## Architecture Components

### 1. SQLite Database Layer (`lib/chat/sqlite_helper.dart`)

**Enhanced Schema:**
- `messages` - Chat messages with sync status
- `lobbies` - Lobby data with full state
- `clips` - Video clips with views/reactions
- `offline_queue` - Pending operations for sync
- `games_cache` - IGDB game data cache
- `groups_cache` - Chat group cache
- `voice_rooms_cache` - Voice room state cache

**Key Features:**
- Indexed queries for performance
- Automatic TTL-based cache expiration
- Sync status tracking
- Retry count for failed operations

### 2. Background Sync Service (`lib/services/background_sync_service.dart`)

**Functionality:**
- Periodic background sync (every 15 minutes)
- Immediate sync on connectivity changes
- Automatic retry with exponential backoff
- Failed item cleanup after max retries

**Workmanager Integration:**
```dart
// Automatically runs in background
- Syncs offline queue items
- Updates unsynced clips
- Syncs unsynced messages
- Cleans up old data
```

### 3. Local Data Sources

#### ChatLocalDataSource (`lib/data/datasources/chat_local_datasource_impl.dart`)
- Message caching with full entity support
- Offline queue for pending messages
- Media upload queue
- Analytics caching

#### LobbyLocalDataSource (`lib/data/datasources/lobby_local_datasource.dart`)
- Lobby state persistence
- Offline lobby updates
- Game-specific lobby queries
- Soft delete support

#### ClipLocalDataSource (`lib/data/datasources/clip_local_datasource.dart`)
- Clip caching with metadata
- View/reaction tracking
- Unsynced clip management
- Clip upload queue

### 4. Offline-First Mixin (`lib/presentation/notifiers/offline_first_mixin.dart`)

**Provides:**
- Connectivity checking
- Automatic offline fallback
- Operation queuing
- Sync triggering

## Implementation Patterns

### Pattern 1: Read with Offline Fallback

```dart
Future<List<Message>> loadMessages(String chatGroupId) async {
  return await executeWithOfflineFallback<List<Message>>(
    onlineOperation: () async {
      // Fetch from Supabase
      final messages = await fetchFromSupabase();
      // Cache for offline use
      await _localDataSource.cacheMessages(chatGroupId, messages);
      return messages;
    },
    offlineOperation: () async {
      // Load from local cache
      return await _localDataSource.getCachedMessages(chatGroupId);
    },
  );
}
```

### Pattern 2: Write with Queue on Offline

```dart
Future<void> sendMessage(Message message) async {
  await executeAndQueueIfOffline(
    id: message.id,
    type: 'message',
    data: message.toJson(),
    onlineOperation: () async {
      // Send to Supabase
      await supabase.from('messages').insert(message.toJson());
      // Cache locally
      await _localDataSource.cacheMessages(chatGroupId, [message]);
    },
    offlineOperation: () async {
      // Queue for sync when back online
      await _localDataSource.queueMessageForSync(message, chatGroupId);
    },
  );
}
```

### Pattern 3: Connectivity Check

```dart
// Async check (network call)
if (await isOnline()) {
  await sendToServer();
}

// Cached check (no network call)
if (isCurrentlyOnline) {
  showOnlineFeatures();
}
```

## Migration Guide for Existing Notifiers

### Step 1: Add OfflineFirstMixin

```dart
class ChatNotifier extends AutoDisposeAsyncNotifier<ChatState>
    with OfflineFirstMixin {
  
  @override
  Future<ChatState> build() async {
    // Initialize offline-first
    await initializeOfflineFirst();
    
    // Rest of initialization...
    return ChatState.initial();
  }
}
```

### Step 2: Update Read Operations

**Before:**
```dart
Future<List<Message>> loadMessages(String chatGroupId) async {
  final response = await supabase
      .from('messages')
      .select()
      .eq('chat_group_id', chatGroupId);
  return parseMessages(response);
}
```

**After:**
```dart
Future<List<Message>> loadMessages(String chatGroupId) async {
  return await executeWithOfflineFallback(
    onlineOperation: () async {
      final response = await supabase
          .from('messages')
          .select()
          .eq('chat_group_id', chatGroupId);
      final messages = parseMessages(response);
      await _localDataSource.cacheMessages(chatGroupId, messages);
      return messages;
    },
    offlineOperation: () async {
      return await _localDataSource.getCachedMessages(chatGroupId);
    },
  );
}
```

### Step 3: Update Write Operations

**Before:**
```dart
Future<void> sendMessage(Message message) async {
  await supabase.from('messages').insert(message.toJson());
}
```

**After:**
```dart
Future<void> sendMessage(Message message) async {
  await executeAndQueueIfOffline(
    id: message.id,
    type: 'message',
    data: message.toJson(),
    onlineOperation: () async {
      await supabase.from('messages').insert(message.toJson());
      await _localDataSource.cacheMessages(chatGroupId, [message]);
    },
    offlineOperation: () async {
      await _localDataSource.queueMessageForSync(message, chatGroupId);
    },
  );
}
```

### Step 4: Add Cleanup

```dart
@override
void dispose() {
  disposeOfflineFirst();
  super.dispose();
}
```

## Offline Queue Types

### Supported Operation Types:
1. **message** - Chat messages
2. **clip_upload** - Video clip uploads
3. **lobby_update** - Lobby state changes
4. **media_upload** - Photo/video uploads

### Queue Item Structure:
```dart
{
  'id': 'unique_id',
  'type': 'message|clip_upload|lobby_update|media_upload',
  'data': {...}, // Operation-specific data
  'created_at': timestamp,
  'retry_count': 0,
  'last_retry_at': null,
  'error': null,
}
```

## Background Sync Behavior

### Triggers:
1. **Periodic** - Every 15 minutes (Workmanager)
2. **Connectivity Change** - When device comes back online
3. **Manual** - Via `triggerSync()` call

### Process:
1. Check connectivity
2. Process offline queue (FIFO)
3. Sync unsynced clips (views, reactions)
4. Sync unsynced messages
5. Clean up failed items (>5 retries)
6. Purge old data (>30 days)

### Retry Logic:
- Max retries: 5
- Failed items auto-deleted after max retries
- Exponential backoff (handled by Workmanager)

## Performance Considerations

### SQLite Optimizations:
- Indexed columns for fast queries
- Batch inserts for bulk operations
- Prepared statements for repeated queries
- Connection pooling via singleton

### Cache Strategy:
- **TTL-based expiration** - Games cache (5 min), Groups cache (30 min)
- **Size limits** - Message pagination (50 per page)
- **Automatic cleanup** - Old data purged periodically

### Memory Management:
- Lazy initialization of services
- Proper disposal in notifiers
- Stream cleanup for connectivity listeners

## Testing Offline Mode

### Simulate Offline:
```dart
// In test or dev mode
final syncService = BackgroundSyncService();
await syncService.initialize();

// Force offline mode
await executeWithOfflineFallback(
  onlineOperation: () => throw Exception('Force offline'),
  offlineOperation: () async {
    // Test offline path
  },
  forceOffline: true,
);
```

### Verify Queue:
```dart
final helper = SQLiteHelper();
final queue = await helper.getOfflineQueue();
print('Pending items: ${queue.length}');
```

### Manual Sync:
```dart
final syncService = BackgroundSyncService();
await syncService.performSync();
```

## Debugging

### Enable Logging:
```dart
// In background_sync_service.dart
final _logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
  ),
);
```

### Check Queue Status:
```dart
final helper = SQLiteHelper();
final queue = await helper.getOfflineQueue();
for (final item in queue) {
  debugPrint('Queue item: ${item['type']} - Retries: ${item['retry_count']}');
}
```

### Monitor Sync:
```dart
// Watch connectivity state
final connectivityState = ref.watch(connectivityNotifierProvider);
debugPrint('Online: ${connectivityState.isOnline}');
debugPrint('Pending: ${connectivityState.pendingItemsCount}');
```

## Best Practices

### 1. Always Cache on Success
```dart
// After successful remote operation
await _localDataSource.cache(...);
```

### 2. Queue on Failure
```dart
try {
  await remoteOperation();
} catch (e) {
  await queueForSync(...);
}
```

### 3. Check Connectivity for User Feedback
```dart
if (!await isOnline()) {
  showSnackBar('Message queued for sending when back online');
}
```

### 4. Use Appropriate Patterns
- **Read operations** → `executeWithOfflineFallback`
- **Write operations** → `executeAndQueueIfOffline`
- **Critical operations** → Always check `isOnline()` first

### 5. Handle Edge Cases
```dart
// Handle partial sync failures
try {
  await syncOperation();
} catch (e) {
  await incrementRetryCount();
  if (retryCount > MAX_RETRIES) {
    await logFailure();
    await notifyUser();
  }
}
```

## Future Enhancements

### Phase 2:
- [ ] Conflict resolution strategies
- [ ] Differential sync for large datasets
- [ ] Compression for queued data
- [ ] Priority queue for critical operations
- [ ] Smart sync based on battery/wifi

### Phase 3:
- [ ] Peer-to-peer sync via WebRTC
- [ ] Multi-device sync coordination
- [ ] Offline file attachments
- [ ] Advanced cache management

## Troubleshooting

### Queue Not Processing:
1. Check Workmanager initialization
2. Verify network connectivity
3. Check queue for failed items
4. Review logs for errors

### Data Not Syncing:
1. Verify background sync is enabled
2. Check for failed queue items
3. Manually trigger sync
4. Clear and rebuild database

### High Memory Usage:
1. Reduce cache TTL
2. Lower message pagination limit
3. Purge old data more frequently
4. Check for memory leaks in listeners

## Related Files

- `lib/chat/sqlite_helper.dart` - Database layer
- `lib/services/background_sync_service.dart` - Background sync
- `lib/presentation/notifiers/offline_first_mixin.dart` - Notifier mixin
- `lib/data/datasources/chat_local_datasource_impl.dart` - Chat caching
- `lib/data/datasources/lobby_local_datasource.dart` - Lobby caching
- `lib/data/datasources/clip_local_datasource.dart` - Clip caching
- `lib/presentation/notifiers/connectivity_notifier.dart` - Connectivity state
- `lib/presentation/notifiers/examples/chat_notifier_offline_example.dart` - Usage examples
