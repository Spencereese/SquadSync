# DualDatabaseService - Quick Reference

## Import
```dart
import '../services/dual_database_service.dart';
```

## Provider
```dart
final db = ref.read(dualDatabaseServiceProvider);
```

## Common Operations

### Users
```dart
// Get
final user = await db.getUser(uid);

// Update
await db.updateUser(uid, {'displayName': 'New Name'});

// Stream
db.streamUser(uid).listen((user) { });
```

### Squads
```dart
// Get
final squad = await db.getSquad(squadId);

// Update
await db.updateSquad(squadId, {'members': ['uid1', 'uid2']});

// Stream
db.streamSquad(squadId).listen((squad) { });
```

### Messages
```dart
// Stream
db.streamMessages(
  chatGroupId: 'id',
  chatType: ChatType.squad,
).listen((messages) { });

// Send
await db.sendMessage(
  senderUid: uid,
  text: 'Hello',
  chatGroupId: 'id',
  chatType: ChatType.squad,
);

// Edit
await db.editMessage(
  messageId: 'msg_id',
  newText: 'Updated',
  chatGroupId: 'id',
  chatType: ChatType.squad,
);

// Delete
await db.deleteMessage(
  messageId: 'msg_id',
  chatGroupId: 'id',
  chatType: ChatType.squad,
);

// React
await db.addReaction(
  messageId: 'msg_id',
  reaction: '😂',
  userId: uid,
  chatGroupId: 'id',
  chatType: ChatType.squad,
);
```

### Typing Status
```dart
// Update
await db.updateTypingStatus(
  userId: uid,
  isTyping: true,
  chatGroupId: 'id',
  chatType: ChatType.squad,
);

// Stream
db.streamTypingStatus(
  currentUserDisplayName: 'Name',
  chatGroupId: 'id',
  chatType: ChatType.squad,
).listen((typingUser) { });
```

### Chat Groups
```dart
// Get
final group = await db.getChatGroup(groupId);

// Update
await db.updateChatGroup(groupId, {'name': 'New Name'});

// Stream
db.streamChatGroup(groupId).listen((group) { });
```

### Backgrounds
```dart
// Get
final bg = await db.getChatBackground(chatGroupId);

// Update
await db.updateChatBackground(chatGroupId, {'url': 'https://...'});

// Stream
db.streamChatBackground(chatGroupId).listen((bg) { });
```

### Ratings
```dart
// Get
final ratings = await db.getUserRatings(uid);

// Update
await db.updateUserRatings(uid, {'averageScore': 4.5});
```

### Bans
```dart
// Add
await db.addBan(uid, {
  'bannedBy': 'admin_uid',
  'reason': 'Toxic',
  'duration': 86400000,
});
```

## ChatType Enum
- `ChatType.squad` - Squad chat
- `ChatType.userGroup` - User-created groups  
- `ChatType.dm` - Direct messages

## Strategy
- **Writes**: BOTH Supabase AND Firestore
- **Reads**: Supabase first → Firestore fallback
- **Streams**: Supabase real-time → Firestore fallback

## Full Guide
See `DUAL_DATABASE_GUIDE.md` for complete documentation.
