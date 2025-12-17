# SquadSync Notification System - Complete Guide

## Overview
Comprehensive notification and alerting system with smart prioritization, cooldown management, and iOS Live Activities support for Dynamic Island.

## Features

### 1. **Mixed Alert System**
- **High Priority (Push)**: Direct invites, momentum notifications
- **Medium Priority (In-app + Sound)**: Spot available, timer expiring
- **Low Priority (Badge Only)**: Chat updates, lobby changes

### 2. **Smart Prioritization**
- Query `match_history` for mutual games
- Prioritize users with **3+ shared sessions**
- Affinity scoring: 0-100 (sessions + recency)
- Only send momentum alerts to high-affinity users

### 3. **Cooldown System**
- **Default**: 45 minutes per lobby/person
- **Momentum**: 30 minutes (overridable)
- Persistent tracking in `notification_cooldowns` table
- Per-user preferences in `users.notification_preferences`

### 4. **Momentum Detection**
- Real-time Supabase subscriptions on `lobby_spots`
- Chain alerts on player increase (1→2, 2→3, etc.)
- Shows spots preview: "2/4 spots filled"
- Lists participant tags (up to 3 names)
- **Cap**: One notification per player jump per minute

### 5. **iOS Enhancement**
- Dynamic Island integration (iOS 16.1+)
- Live Activities for lobby momentum
- Persistent spot timer widgets
- Favorite groups preference for priority widgets

---

## Architecture

### Core Components

```
lib/domain/entities/notification_priority.dart
├── NotificationPriority enum (high/medium/low)
├── NotificationCooldown (freezed entity)
├── MatchAffinity (affinity scoring)
├── BadgeState (in-app badge counts)
└── NotificationPayload (sealed union types)

lib/data/services/notification_service.dart
├── FlutterLocalNotificationsPlugin (Android/iOS)
├── FirebaseMessaging (FCM integration)
├── Cooldown tracking (in-memory + persistent)
├── Badge management
├── Match affinity queries
└── Priority-based channels

lib/presentation/notifiers/notification_notifier.dart
├── Riverpod AsyncNotifier<BadgeState>
├── Real-time Supabase subscriptions
├── Momentum detection logic
├── Notification orchestration
└── Badge state management

lib/data/services/live_activity_manager.dart
└── iOS Live Activities bridge (MethodChannel)

ios/Runner/LiveActivityManager.swift
└── Native Swift implementation (ActivityKit)

lib/presentation/widgets/notification_badge.dart
├── NotificationBadge (badge counter widget)
├── MomentumBadge (pulsing indicator)
└── BadgeClearButton (tap to clear)
```

---

## Database Schema

### New Tables

#### `notification_cooldowns`
```sql
CREATE TABLE notification_cooldowns (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  lobby_id UUID REFERENCES lobbies(id),
  notification_type TEXT CHECK (...),
  last_sent_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  UNIQUE (user_id, lobby_id, notification_type)
);
```

#### `match_affinity` (Materialized View)
```sql
CREATE MATERIALIZED VIEW match_affinity AS
SELECT 
  user_id,
  other_user_id,
  game_id,
  COUNT(*) AS shared_session_count,
  MAX(created_at) AS last_played_together,
  (session_score + recency_score) AS affinity_score
FROM match_history
GROUP BY user_id, other_user_id, game_id
HAVING COUNT(*) >= 3;
```

### Updated Tables

#### `users` (New Columns)
```sql
ALTER TABLE users
ADD COLUMN favorite_groups TEXT[] DEFAULT '{}',
ADD COLUMN notification_preferences JSONB DEFAULT '{
  "momentum_enabled": true,
  "direct_invites_enabled": true,
  "spot_available_enabled": true,
  "timer_expiring_enabled": true,
  "cooldown_minutes": 45
}';
```

---

## Usage Examples

### 1. Initialize Notification System

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/notification_notifier.dart';
import 'package:squad_sync/data/services/notification_service.dart';

// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 2. Display In-App Badges

```dart
import 'package:flutter/material.dart';
import 'package:squad_sync/presentation/widgets/notification_badge.dart';

// Chat tab with badge
NotificationBadge(
  badgeType: 'chat',
  child: Icon(Icons.chat),
)

// Lobby tab with badge
NotificationBadge(
  badgeType: 'lobby',
  child: Icon(Icons.groups),
)

// Invites badge with momentum indicator
MomentumBadge(
  child: NotificationBadge(
    badgeType: 'invites',
    child: Icon(Icons.notifications),
  ),
)
```

### 3. Send Direct Invite

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/notification_notifier.dart';

// In your invite function
Future<void> sendInvite({
  required String recipientId,
  required String lobbyId,
  required String gameName,
}) async {
  final notifier = ref.read(notificationNotifierProvider.notifier);
  
  await notifier.sendDirectInvite(
    recipientId: recipientId,
    inviterName: currentUser.displayName,
    lobbyId: lobbyId,
    gameName: gameName,
    gameImageUrl: game.coverUrl,
  );
}
```

### 4. Handle Momentum Automatically

```dart
// Momentum detection is automatic via Supabase subscriptions
// When a user joins a lobby, NotificationNotifier detects the change
// and sends momentum notifications to high-affinity users

// No manual calls needed - just ensure NotificationNotifier is initialized
final notificationState = ref.watch(notificationNotifierProvider);
```

### 5. Clear Badges on Screen Open

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  void initState() {
    super.initState();
    // Clear chat badge when entering chat screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationNotifierProvider.notifier).clearBadge('chat');
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: ChatMessageList(),
    );
  }
}
```

### 6. iOS Live Activities (Lobby Momentum)

```dart
import 'package:squad_sync/data/services/live_activity_manager.dart';

final liveActivityManager = LiveActivityManager();

// Check support
final isSupported = await liveActivityManager.isSupported();

if (isSupported) {
  // Start Live Activity when lobby gains momentum
  final activityId = await liveActivityManager.startLobbyActivity(
    lobbyId: lobbyId,
    gameName: 'Call of Duty',
    currentPlayers: 2,
    maxPlayers: 4,
    participantNames: ['Alice', 'Bob'],
    gameImageUrl: coverUrl,
  );
  
  // Update when players join
  await liveActivityManager.updateLobbyActivity(
    activityId: activityId!,
    currentPlayers: 3,
    participantNames: ['Alice', 'Bob', 'Charlie'],
  );
  
  // End when lobby starts or closes
  await liveActivityManager.endActivity(activityId);
}
```

### 7. User Notification Preferences

```dart
// Update user preferences
await supabase
  .from('users')
  .update({
    'notification_preferences': {
      'momentum_enabled': true,
      'direct_invites_enabled': true,
      'spot_available_enabled': false,  // Disable spot alerts
      'timer_expiring_enabled': true,
      'cooldown_minutes': 30,  // Custom cooldown
    },
  })
  .eq('id', userId);

// Add favorite groups for Live Activities
await supabase
  .from('users')
  .update({
    'favorite_groups': [groupId1, groupId2, groupId3],
  })
  .eq('id', userId);
```

---

## Configuration

### Android Notification Channels

Defined in `notification_service.dart`:

```dart
// High Priority Channel
AndroidNotificationChannel(
  'squadsync_high_priority',
  'High Priority Alerts',
  description: 'Direct invites and momentum notifications',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);
```

### iOS Info.plist Requirements

```xml
<!-- Background modes for notifications -->
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>remote-notification</string>
  <string>processing</string>
</array>

<!-- Notification permissions -->
<key>NSUserNotificationsUsageDescription</key>
<string>Get notified when friends join lobbies or invite you to play</string>
```

### iOS Live Activities Setup

1. Add `NSSupportsLiveActivities` to Info.plist:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

2. Enable Live Activities capability in Xcode:
   - Target → Signing & Capabilities → + Capability → Push Notifications
   - Add App Group (e.g., `group.com.squadsync.app`)

3. Register plugin in AppDelegate:
```swift
import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    
    if #available(iOS 16.1, *) {
      LiveActivityManager.register(with: registrar(forPlugin: "LiveActivityManager")!)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## Database Functions

### Check if Notification Should Send

```sql
SELECT should_send_notification(
  '123e4567-e89b-12d3-a456-426614174000'::UUID,  -- user_id
  '123e4567-e89b-12d3-a456-426614174001'::UUID,  -- lobby_id
  'momentum'  -- notification_type
);
-- Returns: true/false
```

### Set Notification Cooldown

```sql
SELECT set_notification_cooldown(
  '123e4567-e89b-12d3-a456-426614174000'::UUID,  -- user_id
  '123e4567-e89b-12d3-a456-426614174001'::UUID,  -- lobby_id
  'momentum',  -- notification_type
  30  -- cooldown_minutes
);
```

### Query Match Affinity

```sql
-- Get high-affinity users for a game
SELECT user_id, affinity_score, shared_session_count
FROM match_affinity
WHERE other_user_id = '123e4567-e89b-12d3-a456-426614174000'
  AND game_id = 'call-of-duty-modern-warfare-ii'
  AND shared_session_count >= 3
ORDER BY affinity_score DESC
LIMIT 10;
```

---

## Maintenance

### pg_cron Jobs (Already Configured)

```sql
-- Clean up expired cooldowns (hourly)
SELECT cron.schedule(
  'cleanup-notification-cooldowns',
  '0 * * * *',
  'SELECT cleanup_expired_cooldowns();'
);

-- Refresh match affinity view (daily at 2 AM)
SELECT cron.schedule(
  'refresh-match-affinity',
  '0 2 * * *',
  'SELECT refresh_match_affinity();'
);
```

### Manual Maintenance

```sql
-- Refresh match affinity immediately
SELECT refresh_match_affinity();

-- Clean up old cooldowns
SELECT cleanup_expired_cooldowns();

-- Check cooldown stats
SELECT 
  notification_type,
  COUNT(*) AS active_cooldowns,
  AVG(EXTRACT(EPOCH FROM (expires_at - NOW())) / 60) AS avg_minutes_remaining
FROM notification_cooldowns
WHERE expires_at > NOW()
GROUP BY notification_type;
```

---

## Testing

### Test Momentum Notification

```dart
// Simulate lobby join for testing
await ref.read(notificationNotifierProvider.notifier).sendMomentumNotification(
  lobbyId: 'test-lobby-123',
  gameName: 'Call of Duty',
  currentPlayers: 2,
  maxPlayers: 4,
  joinerName: 'TestUser',
  participantNames: ['Alice', 'Bob'],
);
```

### Test Direct Invite

```dart
await ref.read(notificationNotifierProvider.notifier).sendDirectInvite(
  recipientId: 'test-user-456',
  inviterName: 'Alice',
  lobbyId: 'test-lobby-123',
  gameName: 'Call of Duty',
);
```

### Test Cooldown

```dart
final service = NotificationService();

// First notification should send
await service.sendMomentumNotification(...);

// Second notification within 30 mins should be blocked
await service.sendMomentumNotification(...);  // Blocked by cooldown
```

---

## Troubleshooting

### Notifications Not Appearing

1. **Check permissions**:
```dart
final settings = await FirebaseMessaging.instance.requestPermission();
print('Authorization status: ${settings.authorizationStatus}');
```

2. **Verify channels** (Android):
```bash
adb shell dumpsys notification_listener
```

3. **Check cooldown table**:
```sql
SELECT * FROM notification_cooldowns
WHERE user_id = 'your-user-id'
ORDER BY last_sent_at DESC;
```

### Live Activities Not Starting (iOS)

1. Check iOS version: `await liveActivityManager.isSupported()`
2. Verify Info.plist has `NSSupportsLiveActivities`
3. Check Xcode console for ActivityKit errors
4. Ensure device is unlocked (Live Activities require unlocked device)

### Badge Count Not Updating

1. Check provider state:
```dart
ref.listen(notificationNotifierProvider, (previous, next) {
  print('Badge state changed: $next');
});
```

2. Verify Supabase subscription:
```dart
// In NotificationNotifier
print('Lobby channel status: ${_lobbyChannel?.status}');
```

---

## Performance Considerations

- **Match affinity view**: Refreshed daily (expensive query)
- **Cooldown cleanup**: Hourly (lightweight)
- **Real-time subscriptions**: 2 channels per user (lobby + chat)
- **Badge updates**: In-memory with debouncing
- **Notification throttling**: 30-60 min cooldowns prevent spam

---

## Future Enhancements

1. **Push notification badges**: Native iOS app badge count
2. **Android 13+ permissions**: Runtime notification permissions
3. **Rich notifications**: Action buttons (Join, Decline, Snooze)
4. **Sound customization**: Per-notification-type sounds
5. **Do Not Disturb**: Respect system DND settings
6. **Notification history**: Track sent notifications in database
7. **A/B testing**: Experiment with cooldown durations
8. **Smart send times**: Avoid late-night notifications

---

## References

- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [firebase_messaging](https://pub.dev/packages/firebase_messaging)
- [iOS ActivityKit](https://developer.apple.com/documentation/activitykit)
- [Android Notification Channels](https://developer.android.com/develop/ui/views/notifications/channels)
- [Supabase Realtime](https://supabase.com/docs/guides/realtime)
