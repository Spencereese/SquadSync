# 🚀 Supabase Migration - Next Steps

## ✅ Completed
- [x] Phase 1: Database schema designed (6 tables)
- [x] Phase 2: Service layer created (ChatPersistenceService + SupabasePersistence)
- [x] Phase 3: Schema deployed to Supabase
  - 6 tables created with RLS policies
  - 15 performance indexes
  - 8 foreign key constraints
  - Real-time enabled

## 📋 Ready to Execute - Phase 4: Integration

### Step 1: Enable Dual-Write Mode (5 minutes)

**File**: `lib/core/app_config.dart`

```dart
// Change this line:
static const bool dualWriteEnabled = false;

// To:
static const bool dualWriteEnabled = true;  // ✅ START MIGRATION
```

This will:
- ✅ Write all new messages to BOTH Firestore AND Supabase
- ✅ Keep reading from Firestore (safe, no user impact)
- ✅ Log dual-write success/failure rates
- ⚠️ Slightly increased latency (worth it for safety)

### Step 2: Deploy & Monitor (7 days)

```bash
# Build and deploy
flutter build apk --release          # Android
flutter build ios --release          # iOS
flutter build web --release          # Web

# OR just test locally first
flutter run
```

**What to monitor:**
- Send test messages and verify they appear in BOTH databases
- Check Supabase dashboard for new messages
- Monitor logs for dual-write errors
- **Target**: >99.9% dual-write success rate

**Verification queries in Supabase SQL Editor:**
```sql
-- Check message count (should increase as users send messages)
SELECT COUNT(*) FROM chat_messages;

-- View recent messages
SELECT 
  sender_id,
  text,
  timestamp,
  chat_id
FROM chat_messages
ORDER BY timestamp DESC
LIMIT 10;

-- Check dual-write coverage (messages per hour)
SELECT 
  DATE_TRUNC('hour', timestamp) as hour,
  COUNT(*) as message_count
FROM chat_messages
WHERE timestamp > NOW() - INTERVAL '24 hours'
GROUP BY hour
ORDER BY hour DESC;
```

### Step 3: Switch to Supabase Reads (After 7 days)

**Only proceed if:**
- ✅ Dual-write success rate >99.9%
- ✅ No data inconsistencies reported
- ✅ All message types working (text, images, videos, polls)

**File**: `lib/core/app_config.dart`

```dart
static const bool dualWriteEnabled = true;      // Keep dual-write
static const bool supabaseReadsEnabled = true;  // ✅ SWITCH READS TO SUPABASE
```

This will:
- ✅ Read all messages from Supabase (faster, cheaper)
- ✅ Still dual-write for safety
- ✅ Real-time subscriptions via Supabase
- ⚠️ Monitor closely for 7 more days

### Step 4: Deprecate Firestore (After another 7 days)

**Only proceed if:**
- ✅ Supabase reads working perfectly
- ✅ No performance issues
- ✅ Real-time subscriptions stable
- ✅ Users happy (no complaints)

**File**: `lib/core/app_config.dart`

```dart
static const bool dualWriteEnabled = true;      // Will be ignored
static const bool supabaseReadsEnabled = true;  // Will be ignored
static const bool firestoreDeprecated = true;   // ✅ SUPABASE ONLY MODE
```

This will:
- ✅ All operations use Supabase only
- ✅ 60% cost reduction for chat
- ✅ Better query performance
- ⚠️ Keep Firestore data for 30 days as backup

### Step 5: Cleanup (After 30 days)

**Only if everything is stable:**

1. **Archive Firestore data**
   ```bash
   # Use Firebase console to export data
   # Store in Google Cloud Storage as backup
   ```

2. **Delete old Firestore collections**
   ```javascript
   // In Firebase console or Cloud Functions
   // Delete: squads/*/messages, users/*/chat_groups/*/messages
   ```

3. **Remove Firestore code** (optional)
   - Keep for rollback capability
   - OR remove to reduce bundle size

## 🧪 Testing Checklist

Before enabling each phase, test:

### Dual-Write Phase
- [ ] Send text message → appears in both databases
- [ ] Send image → stored in Supabase
- [ ] Send video → stored in Supabase  
- [ ] Create poll → stored in Supabase
- [ ] Reply to message → foreign key works
- [ ] React to message → JSONB updated
- [ ] Edit message → both databases updated
- [ ] Delete message → soft delete works

### Supabase Reads Phase
- [ ] Messages load on app open
- [ ] Real-time updates work (see new messages instantly)
- [ ] Typing indicators work
- [ ] Read receipts work
- [ ] Message history pagination
- [ ] Search works
- [ ] DM chats work
- [ ] Squad chats work
- [ ] User group chats work

### Firestore Deprecated Phase
- [ ] All above tests pass
- [ ] Check error rates (should be ~0%)
- [ ] Monitor for 7 days
- [ ] Get user feedback

## 📊 Success Metrics

Track these in your analytics:

```dart
// lib/services/analytics_service.dart

// Dual-write metrics
analytics.logEvent('dual_write_success', {
  'database': 'both',
  'latency_ms': elapsed,
});

analytics.logEvent('dual_write_failure', {
  'database': 'supabase',  // or 'firestore'
  'error': errorMessage,
});

// Read metrics
analytics.logEvent('message_load', {
  'source': 'supabase',  // or 'firestore'
  'count': messageCount,
  'latency_ms': elapsed,
});
```

## 🚨 Rollback Plan

If anything goes wrong:

### During Dual-Write
```dart
// lib/core/app_config.dart
static const bool dualWriteEnabled = false;  // ❌ ROLLBACK
```
**Impact**: None. Back to Firestore-only.

### During Supabase Reads
```dart
static const bool supabaseReadsEnabled = false;  // ❌ ROLLBACK
```
**Impact**: Read from Firestore again. Still dual-writing.

### During Firestore Deprecated
```dart
static const bool firestoreDeprecated = false;  // ❌ ROLLBACK
```
**Impact**: Back to dual-mode.

## 🎯 Expected Timeline

- **Week 1-2**: Dual-write mode (Firestore reads)
- **Week 3-4**: Supabase reads (dual-write still active)
- **Week 5-8**: Supabase-only mode (monitoring)
- **Week 9+**: Cleanup Firestore data

**Total migration time: 2-3 months** (safe, gradual)

## 📞 Need Help?

Check these files:
- `SUPABASE_SETUP_GUIDE.md` - Detailed migration guide
- `lib/services/dual_database_service.dart` - Dual-write logic (1181 lines)
- `lib/services/supabase_persistence.dart` - Supabase implementation (470 lines)
- `supabase_schema.sql` - Database schema (405 lines)

**Next action**: Set `dualWriteEnabled = true` in `lib/core/app_config.dart` and test!
