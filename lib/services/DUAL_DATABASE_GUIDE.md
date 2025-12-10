# Dual Database Service - Complete Guide

## Overview

`DualDatabaseService` provides **complete dual-mode** database operations, mirroring all ChatService/FirestoreService functionality with Supabase integration.

### Strategy
- **Writes**: Atomic dual-write to BOTH Firestore AND Supabase
- **Reads**: Supabase-first → Firestore fallback  
- **Streams**: Supabase real-time → Firestore fallback
- **Full Riverpod integration** for notifiers

---

## Quick Start

### 1. Provider Setup

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dual_database_service.dart';

// Service is auto-provided via dualDatabaseServiceProvider
final chatNotifier = AsyncNotifierProvider<ChatNotifier, ChatState>(() {
  return ChatNotifier();
});

class ChatNotifier extends AsyncNotifier<ChatState> {
  DualDatabaseService get _db => ref.read(dualDatabaseServiceProvider);

  @override
  Future<ChatState> build() async {
    // Initialize state
    return ChatState.initial();
  }
}
```

### 2. Basic Usage in Notifiers

```dart
// In your notifier's build or methods:
Future<void> loadMessages(String chatGroupId) async {
  state = const AsyncValue.loading();
  
  try {
    // Stream messages with Supabase-first, Firestore fallback
    final stream = _db.streamMessages(
      chatGroupId: chatGroupId,
      chatType: ChatType.userGroup,
      limit: 100,
    );
    
    stream.listen((messages) {
      state = AsyncValue.data(state.value!.copyWith(messages: messages));
    });
  } catch (e) {
    state = AsyncValue.error(e, StackTrace.current);
  }
}
```

---

## Complete API Reference

### User Operations

#### Get User
```dart
final user = await _db.getUser('uid_12345');
// Tries: Supabase first → Firestore fallback
// Returns: Map<String, dynamic>? with user profile data
```

#### Update User  
```dart
await _db.updateUser('uid_12345', {
  'displayName': 'NewName',
  'pinnedGames': ['game1', 'game2'],
  'bio': 'Updated bio',
});
// Writes to: BOTH Supabase AND Firestore atomically
```

#### Stream User Changes
```dart
_db.streamUser('uid_12345').listen((user) {
  print('User updated: ${user?['displayName']}');
});
// Uses: Supabase real-time stream → Firestore fallback
```

---

### Squad Operations

#### Get Squad
```dart
final squad = await _db.getSquad('squad_abc');
// Returns: Map with squad data (members, settings, game, etc.)
```

#### Update Squad
```dart
await _db.updateSquad('squad_abc', {
  'members': ['uid1', 'uid2', 'uid3'],
  'currentGame': 'Call of Duty',
  'squadSpots': [null, 'uid1_calling', null, 'uid2'],
});
// Dual-write to both databases
```

#### Stream Squad
```dart
_db.streamSquad('squad_abc').listen((squad) {
  print('Squad members: ${squad?['members']}');
});
```

---

### Message Operations

#### Stream Messages
```dart
// Squad chat
_db.streamMessages(
  chatGroupId: 'squad_abc',
  chatType: ChatType.squad,
  limit: 50,
).listen((messages) {
  print('${messages.length} messages loaded');
});

// User group chat
_db.streamMessages(
  chatGroupId: 'group_xyz',
  chatType: ChatType.userGroup,
).listen((messages) {
  // Handle messages
});

// DM chat
_db.streamMessages(
  chatGroupId: 'dm_123',
  chatType: ChatType.dm,
).listen((messages) {
  // Handle DM messages
});
```

#### Send Message
```dart
final msgId = await _db.sendMessage(
  senderUid: 'uid_12345',
  text: 'Hello squad!',
  chatGroupId: 'squad_abc',
  chatType: ChatType.squad,
  // Optional media
  imageUrl: 'https://...',
  videoUrl: 'https://...',
  audioUrl: 'https://...',
  replyTo: 'original_msg_id',
);
// Returns: Message ID
// Writes to: BOTH databases atomically
```

#### Delete Message
```dart
await _db.deleteMessage(
  messageId: 'msg_123',
  chatGroupId: 'squad_abc',
  chatType: ChatType.squad,
);
// Deletes from: BOTH databases
```

#### Edit Message
```dart
await _db.editMessage(
  messageId: 'msg_123',
  newText: 'Updated message text',
  chatGroupId: 'squad_abc',
  chatType: ChatType.squad,
);
// Updates: BOTH databases with edit timestamp
```

#### Add Reaction
```dart
await _db.addReaction(
  messageId: 'msg_123',
  reaction: '😂',
  userId: 'uid_12345',
  chatGroupId: 'squad_abc',
  chatType: ChatType.squad,
);
// Appends reaction to BOTH databases
```

---

### Typing Status

#### Update Typing Status
```dart
// User starts typing
await _db.updateTypingStatus(
  userId: 'uid_12345',
  isTyping: true,
  chatGroupId: 'squad_abc',
  chatType: ChatType.squad,
);

// User stops typing (3 seconds later)
await _db.updateTypingStatus(
  userId: 'uid_12345',
  isTyping: false,
  chatGroupId: 'squad_abc',
  chatType: ChatType.squad,
);
```

#### Stream Typing Status
```dart
_db.streamTypingStatus(
  currentUserDisplayName: 'MyName',
  chatGroupId: 'squad_abc',
  chatType: ChatType.squad,
).listen((typingUser) {
  if (typingUser != null) {
    print('$typingUser is typing...');
  }
});
```

---

### Chat Groups (DMs & User Groups)

#### Get Chat Group
```dart
final group = await _db.getChatGroup('group_123');
// Returns: Group metadata (members, name, created_at, etc.)
```

#### Update Chat Group
```dart
await _db.updateChatGroup('group_123', {
  'name': 'New Group Name',
  'members': ['uid1', 'uid2', 'uid3'],
  'lastMessage': 'Hey everyone!',
  'lastMessageTime': DateTime.now().millisecondsSinceEpoch,
});
```

#### Stream Chat Group
```dart
_db.streamChatGroup('group_123').listen((group) {
  print('Group updated: ${group?['name']}');
});
```

---

### Chat Backgrounds

#### Get Background
```dart
final bg = await _db.getChatBackground('squad_abc');
// Returns: { 'url': '...', 'type': 'image', 'opacity': 0.3 }
```

#### Update Background
```dart
await _db.updateChatBackground('squad_abc', {
  'url': 'https://storage.supabase.co/...',
  'type': 'image',
  'opacity': 0.5,
});
```

#### Stream Background Changes
```dart
_db.streamChatBackground('squad_abc').listen((bg) {
  print('Background: ${bg?['url']}');
});
```

---

### User Ratings & Reputation

#### Get Ratings
```dart
final ratings = await _db.getUserRatings('uid_12345');
// Returns: { 'totalRatings': 42, 'averageScore': 4.5, ... }
```

#### Update Ratings
```dart
await _db.updateUserRatings('uid_12345', {
  'totalRatings': 43,
  'averageScore': 4.6,
  'lastRatedBy': 'uid_67890',
  'lastRatedAt': DateTime.now().millisecondsSinceEpoch,
});
```

---

### Bans

#### Add Ban
```dart
await _db.addBan('uid_12345', {
  'bannedBy': 'uid_admin',
  'reason': 'Toxic behavior',
  'duration': 86400000, // 24 hours in ms
  'createdAt': DateTime.now().millisecondsSinceEpoch,
});
// Appends to bans array in BOTH databases
```

---

## Advanced Usage

### Batch Operations

```dart
await _db.batchWrite([
  {
    'table': 'users',
    'collection': 'users',
    'docId': 'uid_123',
    'data': {'displayName': 'User1'},
    'operation': 'upsert', // For Supabase
  },
  {
    'table': 'squads',
    'collection': 'squads',
    'docId': 'squad_abc',
    'data': {'members': ['uid_123']},
    'operation': 'set', // For Firestore
  },
]);
```

---

## Riverpod Integration Examples

### ChatNotifier with Dual DB

```dart
@riverpod
class ChatNotifier extends _$ChatNotifier {
  DualDatabaseService get _db => ref.read(dualDatabaseServiceProvider);

  @override
  Future<ChatState> build(String chatGroupId, ChatType chatType) async {
    // Set up message stream
    _db.streamMessages(
      chatGroupId: chatGroupId,
      chatType: chatType,
    ).listen((messages) {
      state = AsyncValue.data(state.value!.copyWith(
        messages: messages.map((m) => Message.fromMap(m)).toList(),
      ));
    });

    return ChatState.initial();
  }

  Future<void> sendMessage(String text) async {
    final user = ref.read(userNotifierProvider).value;
    if (user == null) return;

    await _db.sendMessage(
      senderUid: user.uid,
      text: text,
      chatGroupId: chatGroupId,
      chatType: chatType,
    );
  }

  Future<void> editMessage(String msgId, String newText) async {
    await _db.editMessage(
      messageId: msgId,
      newText: newText,
      chatGroupId: chatGroupId,
      chatType: chatType,
    );
  }
}
```

### SquadNotifier with Dual DB

```dart
@riverpod
class SquadNotifier extends _$SquadNotifier {
  DualDatabaseService get _db => ref.read(dualDatabaseServiceProvider);

  @override
  Future<SquadState> build() async {
    return SquadState.initial();
  }

  Future<void> selectSquad(String squadId) async {
    state = const AsyncValue.loading();
    
    try {
      // Stream squad changes
      _db.streamSquad(squadId).listen((squad) {
        if (squad != null) {
          state = AsyncValue.data(SquadState(
            selectedSquadId: squadId,
            currentSquad: Squad.fromMap(squad),
          ));
        }
      });
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateSquadSpots(List<String?> spots) async {
    final squadId = state.value?.selectedSquadId;
    if (squadId == null) return;

    await _db.updateSquad(squadId, {
      'squadSpots': spots,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
```

### UserNotifier with Dual DB

```dart
@riverpod
class UserNotifier extends _$UserNotifier {
  DualDatabaseService get _db => ref.read(dualDatabaseServiceProvider);

  @override
  Future<AppUser?> build() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return null;

    // Stream user profile
    _db.streamUser(firebaseUser.uid).listen((userData) {
      if (userData != null) {
        state = AsyncValue.data(AppUser.fromMap(userData));
      }
    });

    return null;
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = state.value;
    if (user == null) return;

    await _db.updateUser(user.uid, updates);
  }
}
```

---

## Data Structure Reference

### Supabase Tables

#### `users`
```sql
uid TEXT PRIMARY KEY
displayName TEXT
email TEXT
pinnedGames TEXT[]
bio TEXT
created_at TIMESTAMPTZ
```

#### `squads`
```sql
id TEXT PRIMARY KEY
members TEXT[]
currentGame TEXT
squadSpots TEXT[]
created_at TIMESTAMPTZ
```

#### `messages`
```sql
id TEXT PRIMARY KEY
senderUid TEXT
text TEXT
timestamp_ms BIGINT
imageUrl TEXT
videoUrl TEXT
audioUrl TEXT
squad_id TEXT  -- For squad messages
chat_group_id TEXT  -- For user group messages
chat_id TEXT  -- For DM messages
user_id TEXT  -- For user-scoped messages
reactions JSONB[]
```

#### `chat_groups`
```sql
id TEXT PRIMARY KEY
name TEXT
members TEXT[]
created_at TIMESTAMPTZ
lastMessage TEXT
```

#### `chat_backgrounds`
```sql
chat_group_id TEXT PRIMARY KEY
url TEXT
type TEXT
opacity REAL
```

#### `typing_status`
```sql
user_id TEXT PRIMARY KEY
is_typing BOOLEAN
chat_id TEXT
updated_at TIMESTAMPTZ
```

#### `user_ratings`
```sql
uid TEXT PRIMARY KEY
totalRatings INT
averageScore REAL
lastRatedBy TEXT
```

#### `bans`
```sql
uid TEXT PRIMARY KEY
bans JSONB[]
```

---

## Migration from ChatService

### Before (ChatService)
```dart
// Old code using ChatService
final chatService = ChatService();
final stream = chatService.getChatMessages(ref, 
  chatGroupId: 'abc',
  chatType: ChatType.userGroup,
);

await chatService.sendMessage(ref,
  senderUid: uid,
  text: 'Hello',
  chatGroupId: 'abc',
  chatType: ChatType.userGroup,
);
```

### After (DualDatabaseService)
```dart
// New code using DualDatabaseService
final db = ref.read(dualDatabaseServiceProvider);
final stream = db.streamMessages(
  chatGroupId: 'abc',
  chatType: ChatType.userGroup,
);

await db.sendMessage(
  senderUid: uid,
  text: 'Hello',
  chatGroupId: 'abc',
  chatType: ChatType.userGroup,
);
```

**Key Differences:**
- ✅ No `WidgetRef` needed in most methods
- ✅ Automatic dual-write to Supabase + Firestore
- ✅ Supabase-first reads with Firestore fallback
- ✅ Real-time Supabase streams
- ✅ Full Riverpod provider support

---

## Error Handling

All methods handle errors gracefully:

```dart
try {
  await _db.sendMessage(
    senderUid: uid,
    text: 'Hello',
    chatGroupId: 'abc',
    chatType: ChatType.squad,
  );
} catch (e) {
  // Firestore failed (critical error)
  _logger.e('Failed to send message: $e');
  // Note: Supabase failure is logged but non-blocking
}
```

**Behavior:**
- ❌ **Supabase failure**: Logged as warning, continues with Firestore
- ❌ **Firestore failure**: Throws error (critical)
- ✅ **Both succeed**: Message sent to both databases

---

## Logging

Service uses emoji-prefixed logging:
- ✅ `✅` - Supabase success
- 📦 `📦` - Firestore success
- 🔄 `🔄` - Real-time stream event
- ⚠️ `⚠️` - Non-blocking warning
- ❌ `❌` - Critical error

Enable in debug mode:
```dart
final _logger = Logger(
  printer: PrettyPrinter(),
  level: kDebugMode ? Level.debug : Level.error,
);
```

---

## Performance Tips

1. **Stream Reuse**: Streams automatically cache, no need to manually manage
2. **Batch Writes**: Use `batchWrite()` for multiple operations
3. **Limit Messages**: Always specify `limit` parameter in `streamMessages()`
4. **Offline Support**: Firestore handles offline automatically, Supabase requires connectivity

---

## Testing

```dart
// Mock the service in tests
final mockDb = MockDualDatabaseService();
container = ProviderContainer(
  overrides: [
    dualDatabaseServiceProvider.overrideWithValue(mockDb),
  ],
);

when(mockDb.getUser('uid_123')).thenAnswer((_) async => {
  'uid': 'uid_123',
  'displayName': 'Test User',
});
```

---

## Summary

✅ **Complete** ChatService replacement  
✅ **Dual-mode** writes (Supabase + Firestore)  
✅ **Supabase-first** reads with Firestore fallback  
✅ **Real-time** streams from Supabase  
✅ **Full Riverpod** integration  
✅ **Comprehensive** logging  
✅ **Error resilient** with graceful fallbacks  

**Ready for production use with gradual Supabase migration!**
