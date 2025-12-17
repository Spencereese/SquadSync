# Peacock Notification Service - Integration Guide

## Overview
The Peacock Notification Service listens to Realtime database updates when users are auto-assigned spots from the peacock queue and sends push notifications.

## Architecture
1. **Database Table**: `peacock_notifications` - stores notification events
2. **Timer Function**: `process_expired_timers()` creates notifications when auto-assigning spots
3. **Realtime Listener**: Flutter service subscribes to notification inserts
4. **FCM Push**: Sends push notification when event detected

## Integration Steps

### 1. Run Database Migrations
```sql
-- Run these migrations in Supabase SQL Editor
-- File: supabase/migrations/20251216_peacock_notifications.sql
```

### 2. Initialize Service on App Startup
Add to `lib/main.dart` after user authentication:

```dart
import 'services/peacock_notification_service.dart';

// In initState() or after successful login
@override
void initState() {
  super.initState();
  
  // Listen for auth state changes
  SupabaseService.client.auth.onAuthStateChange.listen((data) {
    final session = data.session;
    if (session != null) {
      // User logged in - initialize peacock notifications
      PeacockNotificationService.initialize();
      PeacockNotificationService.checkPendingNotifications();
    } else {
      // User logged out - dispose listener
      PeacockNotificationService.dispose();
    }
  });
}
```

### 3. Alternative: Manual Initialization
In your login/auth screen after successful login:

```dart
// After successful login
final response = await authService.signInWithEmailPassword(
  email: email,
  password: password,
);

if (response.user != null) {
  // Initialize peacock notifications
  await PeacockNotificationService.initialize();
  await PeacockNotificationService.checkPendingNotifications();
}
```

### 4. Cleanup on Logout
```dart
// Before signing out
await PeacockNotificationService.dispose();
await authService.signOut();
```

## How It Works

1. **User joins peacock queue** → Entry added to `peacock_queue` table
2. **Spot becomes available** → pg_cron runs `process_expired_timers()` every 30s
3. **Auto-assignment** → User auto-assigned, timer created (5 min lock-in)
4. **Notification created** → INSERT into `peacock_notifications` table
5. **Realtime triggers** → Flutter service receives notification event
6. **FCM push sent** → User gets push notification: "🎮 Your spot is ready! Lock in within 5 minutes"

## Testing

### Test Notification Creation
```sql
-- Manually create a test notification
INSERT INTO peacock_notifications (
  user_uid,
  lobby_id,
  game_name,
  spot_index,
  title,
  body,
  data
) VALUES (
  'YOUR_USER_UID',
  'test-lobby-123',
  'Call of Duty',
  0,
  '🎮 Your spot is ready!',
  'Lock in within 5 minutes for Call of Duty',
  '{"type": "peacock_assigned", "lobby_id": "test-lobby-123"}'::jsonb
);
```

### Verify Realtime Subscription
Check logs for:
```
🦚 Initializing peacock notification listener for user [uid]
✅ Peacock notification listener active
📣 Showing notification: [title] - [body]
```

## Troubleshooting

### No notifications received
1. Check Realtime subscription is active (look for log messages)
2. Verify user is authenticated (`AuthServiceSupabase().currentUser != null`)
3. Check `peacock_notifications` table has pending notifications
4. Verify RLS policies allow user to read their notifications

### Duplicate notifications
- Notifications are marked as `sent` after delivery
- Check `checkPendingNotifications()` only runs once on startup

### Service not initializing
- Ensure `PeacockNotificationService.initialize()` is called after authentication
- Check for any errors in console logs
- Verify Supabase client is properly initialized

## Files Modified
- `lib/services/peacock_notification_service.dart` - New service
- `supabase/migrations/20251216_peacock_notifications.sql` - Database schema
- `supabase/migrations/20251216_update_peacock_5min_timer.sql` - Updated timer function
- `lib/lobbies_tab/widgets/peacock_queue_section.dart` - UI component
- `lib/lobbies_tab/lobbies_tab.dart` - Integrated queue display

## Next Steps
1. Add initialization code to main.dart (see Integration Steps above)
2. Run database migrations in Supabase
3. Test with manual notification insertion
4. Verify push notifications arrive on device
