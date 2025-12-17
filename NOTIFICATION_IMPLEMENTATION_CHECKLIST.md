# Notification System - Implementation Checklist

## Phase 1: Database Setup ⚙️

- [ ] **Apply Migration**
  ```bash
  cd /Users/spencereese/Documents/cod_squad_app
  supabase db push supabase/migrations/20251216_notification_system.sql
  ```

- [ ] **Verify Tables Created**
  ```sql
  -- Check in Supabase dashboard SQL editor
  SELECT * FROM notification_cooldowns LIMIT 1;
  SELECT * FROM match_affinity LIMIT 10;
  ```

- [ ] **Test Functions**
  ```sql
  -- Test should_send_notification
  SELECT should_send_notification(
    'your-user-id'::UUID,
    'test-lobby-id'::UUID,
    'momentum'
  );
  ```

## Phase 2: Flutter Integration 📱

- [ ] **Initialize in main.dart**
  ```dart
  // Add to main() before runApp()
  await NotificationService().initialize();
  ```

- [ ] **Add Provider to App**
  ```dart
  // Ensure ProviderScope wraps your app
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
  ```

- [ ] **Add Badges to Navigation**
  - [ ] Chat tab badge
  - [ ] Lobby tab badge
  - [ ] Invites badge in app bar

- [ ] **Clear Badges on Screen Open**
  - [ ] ChatScreen → `clearBadge('chat')`
  - [ ] LobbyScreen → `clearBadge('lobby')`
  - [ ] NotificationsScreen → `clearBadge('invites')`

## Phase 3: Lobby Integration 🎮

- [ ] **Enhance claimSpot method**
  - [ ] Add momentum notification call
  - [ ] Add Live Activity start (iOS)
  - [ ] Test with 2+ players joining

- [ ] **Enhance releaseSpot method**
  - [ ] Add spot available notification
  - [ ] End Live Activity (iOS)

- [ ] **Add Invite Notifications**
  - [ ] Call `sendDirectInvite()` in invite function
  - [ ] Test invite delivery

## Phase 4: iOS Configuration 🍎 (Optional)

- [ ] **Update Info.plist**
  - [ ] Add `NSSupportsLiveActivities`
  - [ ] Add notification usage description

- [ ] **Enable Xcode Capabilities**
  - [ ] Push Notifications capability
  - [ ] App Groups capability
  - [ ] Set group ID: `group.com.squadsync.app`

- [ ] **Register Plugin in AppDelegate**
  - [ ] Import LiveActivityManager
  - [ ] Register in `didFinishLaunchingWithOptions`

- [ ] **Test Live Activities** (iOS 16.1+ only)
  - [ ] Add favorite group
  - [ ] Join lobby in favorite group
  - [ ] Check Dynamic Island widget

## Phase 5: Testing & Verification ✅

### Momentum Notifications
- [ ] User joins empty lobby → No notification
- [ ] Second user joins → Momentum notification sent
- [ ] Third user joins → Another momentum notification
- [ ] Duplicate within 30 min → Blocked by cooldown
- [ ] Check affinity scoring (3+ shared sessions)

### Direct Invites
- [ ] Send invite to friend → Push notification received
- [ ] Tap notification → Opens lobby
- [ ] Check cooldown (45 min default)

### In-App Badges
- [ ] Chat message → Badge count increases
- [ ] Open chat → Badge cleared
- [ ] Lobby update → Badge appears
- [ ] Open lobby → Badge cleared

### Cooldown System
- [ ] First notification → Sent immediately
- [ ] Duplicate within cooldown → Blocked
- [ ] After cooldown expires → Sent again
- [ ] Check database cooldowns table

### iOS Live Activities (iOS Only)
- [ ] Add group to favorites
- [ ] Join lobby → Live Activity starts
- [ ] Check Dynamic Island
- [ ] Check Lock Screen widget
- [ ] Leave lobby → Live Activity ends

## Phase 6: User Preferences 🎛️

- [ ] **Create Settings UI**
  - [ ] Toggle for momentum notifications
  - [ ] Toggle for direct invites
  - [ ] Toggle for spot available
  - [ ] Toggle for timer expiring
  - [ ] Slider for cooldown duration (30-60 min)

- [ ] **Implement Favorite Groups**
  - [ ] UI to star/unstar groups
  - [ ] Display favorite indicator
  - [ ] Sync with Live Activities

- [ ] **Test Preference Changes**
  - [ ] Disable momentum → No momentum alerts
  - [ ] Change cooldown → New duration applied

## Phase 7: Performance & Monitoring 📊

- [ ] **Database Optimization**
  - [ ] Verify indexes created
  - [ ] Check materialized view size
  - [ ] Monitor cooldown table growth

- [ ] **pg_cron Jobs**
  - [ ] Verify hourly cooldown cleanup runs
  - [ ] Verify daily affinity refresh runs
  - [ ] Check cron logs in Supabase

- [ ] **Analytics Tracking** (Optional)
  - [ ] Track notification send rate
  - [ ] Track user engagement (taps)
  - [ ] Track cooldown hit rate

## Phase 8: Production Readiness 🚀

- [ ] **Permission Handling**
  - [ ] Android runtime permissions (Android 13+)
  - [ ] iOS notification permissions
  - [ ] Handle permission denied gracefully

- [ ] **Error Handling**
  - [ ] Supabase connection failures
  - [ ] FCM token registration failures
  - [ ] Graceful degradation (no notifications)

- [ ] **Logging & Debugging**
  - [ ] Add debug prints for notification events
  - [ ] Log cooldown blocks
  - [ ] Log affinity calculations

- [ ] **Documentation**
  - [ ] Update README with notification setup
  - [ ] Document user-facing features
  - [ ] Create troubleshooting guide

## Optional Enhancements 🌟

- [ ] **Rich Notifications**
  - [ ] Action buttons (Join, Decline, Snooze)
  - [ ] Custom sounds per notification type
  - [ ] Notification images/avatars

- [ ] **Advanced Features**
  - [ ] Do Not Disturb mode
  - [ ] Quiet hours (e.g., 10 PM - 8 AM)
  - [ ] Notification history screen
  - [ ] Per-game notification settings

- [ ] **A/B Testing**
  - [ ] Experiment with cooldown durations
  - [ ] Test notification copy variations
  - [ ] Measure engagement impact

---

## Quick Reference

### Key Files
- Service: `lib/data/services/notification_service.dart`
- Notifier: `lib/presentation/notifiers/notification_notifier.dart`
- Widgets: `lib/presentation/widgets/notification_badge.dart`
- Migration: `supabase/migrations/20251216_notification_system.sql`
- Guide: `NOTIFICATION_SYSTEM_GUIDE.md`

### Key Commands
```bash
# Apply migration
supabase db push supabase/migrations/20251216_notification_system.sql

# Generate freezed files
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run
```

### Key Providers
```dart
// Notification state
ref.watch(notificationNotifierProvider)

// Notification actions
ref.read(notificationNotifierProvider.notifier)
```

---

## Support

For issues or questions:
1. Check `NOTIFICATION_SYSTEM_GUIDE.md` for detailed documentation
2. Review examples in `lib/presentation/examples/`
3. Check Supabase logs for database errors
4. Verify Supabase real-time subscription status

---

**Status**: ⚠️ Implementation complete, awaiting deployment

**Next Action**: Apply database migration and initialize in main.dart
