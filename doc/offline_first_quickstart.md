# Quick Start: Offline-First Integration

## 5-Minute Setup

### 1. Update pubspec.yaml Dependencies
```yaml
dependencies:
  workmanager: ^0.5.2
  connectivity_plus: ^6.1.0  # Already included
  sqflite: ^2.3.0  # Already included
```

Run: `flutter pub get`

### 2. Initialize Background Sync in main.dart

```dart
import 'package:squad_sync/services/background_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background sync
  final syncService = BackgroundSyncService();
  await syncService.initialize();
  
  runApp(MyApp());
}
```

### 3. Add OfflineFirstMixin to Your Notifier

```dart
import 'package:squad_sync/presentation/notifiers/offline_first_mixin.dart';

class YourNotifier extends AutoDisposeAsyncNotifier<YourState>
    with OfflineFirstMixin {
  
  @override
  Future<YourState> build() async {
    await initializeOfflineFirst();
    // ... rest of init
  }
}
```

### 4. Update a Read Operation

```dart
// Before:
Future<List<Data>> fetchData() async {
  return await supabase.from('table').select();
}

// After:
Future<List<Data>> fetchData() async {
  return await executeWithOfflineFallback(
    onlineOperation: () async {
      final data = await supabase.from('table').select();
      await _localDataSource.cacheData(data);
      return data;
    },
    offlineOperation: () async {
      return await _localDataSource.getCachedData();
    },
  );
}
```

### 5. Update a Write Operation

```dart
// Before:
Future<void> saveData(Data item) async {
  await supabase.from('table').insert(item.toJson());
}

// After:
Future<void> saveData(Data item) async {
  await executeAndQueueIfOffline(
    id: item.id,
    type: 'data_save',
    data: item.toJson(),
    onlineOperation: () async {
      await supabase.from('table').insert(item.toJson());
      await _localDataSource.cacheItem(item);
    },
    offlineOperation: () async {
      await queueForSync(
        id: item.id,
        type: 'data_save',
        data: item.toJson(),
      );
    },
  );
}
```

## Common Use Cases

### Use Case 1: Chat Messages

```dart
// Send message with offline support
Future<void> sendMessage(String text) async {
  final message = Message(
    id: Uuid().v4(),
    text: text,
    timestamp: DateTime.now(),
  );

  await executeAndQueueIfOffline(
    id: message.id,
    type: 'message',
    data: message.toJson(),
    onlineOperation: () async {
      await supabase.from('messages').insert(message.toJson());
      await _localDataSource.cacheMessages([message]);
    },
    offlineOperation: () async {
      await _localDataSource.queueMessageForSync(message, chatGroupId);
    },
  );
}

// Load messages with offline fallback
Future<List<Message>> loadMessages() async {
  return await executeWithOfflineFallback(
    onlineOperation: () async {
      final messages = await supabase
          .from('messages')
          .select()
          .eq('chat_group_id', chatGroupId);
      await _localDataSource.cacheMessages(messages);
      return messages;
    },
    offlineOperation: () async {
      return await _localDataSource.getCachedMessages(chatGroupId);
    },
  );
}
```

### Use Case 2: Lobby Updates

```dart
Future<void> updateLobby(Lobby lobby) async {
  final localDataSource = LobbyLocalDataSourceImpl(prefs, sqliteHelper);
  
  await executeAndQueueIfOffline(
    id: 'lobby_${lobby.id}',
    type: 'lobby_update',
    data: lobby.toJson(),
    onlineOperation: () async {
      await supabase.from('lobbies').update(lobby.toJson()).eq('id', lobby.id);
      await localDataSource.saveLobby(lobby);
    },
    offlineOperation: () async {
      await localDataSource.queueLobbyUpdate(lobby);
    },
  );
}
```

### Use Case 3: Clip Upload

```dart
Future<void> uploadClip(String videoPath) async {
  final clipService = ClipService();
  final clipData = await clipService.processClip(videoPath);
  
  final clip = MessageData(
    id: clipData.clipId,
    type: MessageType.clip,
    clipData: ClipMessageData.fromClipData(clipData),
  );

  await executeAndQueueIfOffline(
    id: clip.id,
    type: 'clip_upload',
    data: {
      'clip_id': clip.id,
      'video_url': clipData.videoUrl,
      'thumbnail_url': clipData.thumbUrl,
    },
    onlineOperation: () async {
      await supabase.from('clips').insert(clip.toJson());
      await _clipLocalDataSource.cacheClip(clip, squadId: squadId);
    },
    offlineOperation: () async {
      await _clipLocalDataSource.queueClipUpload(clip, squadId: squadId);
    },
  );
}
```

## UI Indicators

### Show Connectivity Status

```dart
// In your widget
final syncService = BackgroundSyncService();
final isOnline = syncService.isCurrentlyOnline;

// Show indicator
if (!isOnline) {
  SnackBar(
    content: Text('You\'re offline. Changes will sync when back online.'),
    backgroundColor: Colors.orange,
  );
}
```

### Show Pending Items

```dart
final helper = SQLiteHelper();
final queue = await helper.getOfflineQueue();

// Show badge
Badge(
  label: Text('${queue.length}'),
  child: Icon(Icons.sync),
);
```

### Manual Sync Button

```dart
ElevatedButton.icon(
  onPressed: () async {
    final syncService = BackgroundSyncService();
    if (await syncService.isOnline()) {
      await syncService.performSync();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync complete!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No internet connection')),
      );
    }
  },
  icon: Icon(Icons.sync),
  label: Text('Sync Now'),
);
```

## Testing

### Simulate Offline Mode

```dart
// Force offline for testing
await executeWithOfflineFallback(
  onlineOperation: () => throw Exception('Simulated offline'),
  offlineOperation: () async {
    // Your offline code
  },
  forceOffline: true, // <-- Force offline mode
);
```

### Check Queue

```dart
void debugOfflineQueue() async {
  final helper = SQLiteHelper();
  final queue = await helper.getOfflineQueue();
  
  print('=== OFFLINE QUEUE ===');
  for (final item in queue) {
    print('Type: ${item['type']}');
    print('Retries: ${item['retry_count']}');
    print('Created: ${item['created_at']}');
    print('Error: ${item['error']}');
    print('---');
  }
}
```

### Verify Sync

```dart
void testSync() async {
  final syncService = BackgroundSyncService();
  await syncService.initialize();
  
  print('Is online: ${await syncService.isOnline()}');
  
  // Trigger sync
  await syncService.performSync();
  
  // Check remaining items
  final helper = SQLiteHelper();
  final queue = await helper.getOfflineQueue();
  print('Remaining in queue: ${queue.length}');
}
```

## Troubleshooting

### Problem: Items not syncing
**Solution:** Check if Workmanager is initialized in main.dart

### Problem: Database errors
**Solution:** Increment database version in sqlite_helper.dart

### Problem: Queue growing too large
**Solution:** Reduce retry limit or implement priority queue

### Problem: App crashes on startup
**Solution:** Ensure async initialization is properly awaited

## Next Steps

1. ✅ Read full documentation: `doc/offline_first_architecture.md`
2. ✅ Review example: `lib/presentation/notifiers/examples/chat_notifier_offline_example.dart`
3. ✅ Implement in your notifiers
4. ✅ Add UI indicators for offline state
5. ✅ Test thoroughly in offline mode

## Need Help?

- Check full docs: `doc/offline_first_architecture.md`
- Review working example: `chat_notifier_offline_example.dart`
- Debug with SQLite browser to inspect database
- Use logger to trace sync operations
