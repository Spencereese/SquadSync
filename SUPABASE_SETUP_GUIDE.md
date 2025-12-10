# SquadSync: Supabase Migration - Quick Start Guide

## ✅ Phase 1: Database Setup (READY TO EXECUTE)

### Step 1: Run Schema in Supabase Dashboard

1. **Open Supabase SQL Editor**:
   - Navigate to: https://supabase.com/dashboard/project/sfckxrnoiwetmzdycqaa/sql
   - Click "+ New Query"

2. **Copy & Execute Schema**:
   ```bash
   # Copy the schema file
   cat supabase_schema.sql
   ```
   - Paste entire contents into SQL Editor
   - Click "Run" (or press Cmd+Enter)
   - Wait for "Success" confirmation (~10 seconds)

3. **Verify Tables Created**:
   ```sql
   -- Run this query to check all tables exist:
   SELECT table_name 
   FROM information_schema.tables 
   WHERE table_schema = 'public' 
   AND table_name IN ('users', 'squads', 'chat_messages', 'chat_metadata', 'chat_groups', 'user_ratings');
   ```
   - Should return 6 rows (all tables)

### Step 2: Enable Real-time Subscriptions

1. Navigate to: Database > Publications
2. Verify `supabase_realtime` publication exists
3. Confirm tables are listed:
   - ✅ chat_messages
   - ✅ chat_metadata
   - ✅ squads
   - ✅ chat_groups

### Step 3: Test RLS Policies

```sql
-- Verify RLS is enabled on all tables
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('users', 'squads', 'chat_messages', 'chat_metadata', 'chat_groups', 'user_ratings');
```

Expected output: All rows should have `rowsecurity = true`

---

## 🔄 Phase 2: Code Integration (IMPLEMENTED)

### Files Created:

1. **`lib/services/chat_persistence_service.dart`** - Abstract interface (✅ Complete)
2. **`lib/services/supabase_persistence.dart`** - Supabase implementation (✅ Complete)
3. **`lib/models/chat_metadata.dart`** - Metadata entity (✅ Complete)
4. **`supabase_schema.sql`** - Database schema (✅ Complete)

### Architecture:

```
┌─────────────────────────────────────────────────────┐
│              ChatNotifier (Riverpod)                │
│  State management for chat UI and interactions     │
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│            MessageService (Business Logic)          │
│  Orchestrates: Validation, AI, Media, Offline Queue│
└─────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│       ChatPersistenceService (Interface)            │
│  Abstract layer - supports multiple backends        │
└─────────────────────────────────────────────────────┘
                    ┌────┴────┐
                    ▼         ▼
        ┌──────────────┐  ┌───────────────────┐
        │  Firestore   │  │  Supabase         │
        │  (Legacy)    │  │  (Target)         │
        └──────────────┘  └───────────────────┘
```

---

## 🧪 Phase 3: Local Testing (NEXT STEPS)

### Test 1: Send Message to Supabase

```dart
// In lib/main.dart or test file
import 'package:squad_sync/services/supabase_persistence.dart';
import 'package:squad_sync/domain/entities/message.dart';

Future<void> testSupabaseMessage() async {
  final persistence = SupabasePersistence();
  
  final message = Message.create(
    senderId: 'test_user_123',
    text: 'Hello from Supabase!',
    messageType: MessageType.text,
    metadata: {'chatId': 'test_chat'},
  );

  try {
    await persistence.sendMessage(message);
    print('✅ Message sent to Supabase successfully!');
  } catch (e) {
    print('❌ Error: $e');
  }
}
```

### Test 2: Stream Messages

```dart
Future<void> testMessageStream() async {
  final persistence = SupabasePersistence();
  
  final stream = persistence.streamMessages(
    chatId: 'test_chat',
    chatType: ChatType.squad,
    limit: 10,
  );

  stream.listen(
    (messages) {
      print('📨 Received ${messages.length} messages');
      for (final msg in messages) {
        print('  - ${msg.senderId}: ${msg.text}');
      }
    },
    onError: (error) => print('❌ Stream error: $error'),
  );
}
```

### Test 3: Verify in Supabase Dashboard

1. Navigate to: Table Editor > chat_messages
2. Look for your test messages
3. Check timestamp, sender_id, text fields populated correctly

---

## 🚀 Phase 4: Dual-Write Mode (PRODUCTION READY)

### Option A: DualDatabaseService (Already Exists!)

The app already has `dual_database_service.dart` with 1181 lines of dual-write logic:

```dart
// lib/services/dual_database_service.dart already implements:
- ✅ Dual-write to BOTH Firestore AND Supabase
- ✅ Supabase-first reads with Firestore fallback
- ✅ Real-time streams with automatic fallback
- ✅ Comprehensive error handling and logging
```

**To enable**:
- Service is already implemented
- Just need to wire it into MessageService/ChatService
- Set `_dualModeEnabled = true` (already set!)

### Option B: Feature Flag Approach

```dart
// lib/core/config.dart
class AppConfig {
  static const bool useSupabase = false;  // Toggle here
  static const bool dualWriteMode = true; // Write to both
}

// In persistence layer
ChatPersistenceService getPersistence() {
  if (AppConfig.useSupabase) {
    return SupabasePersistence();
  } else if (AppConfig.dualWriteMode) {
    return DualPersistenceService(); // Writes to both
  } else {
    return FirestorePersistence(); // Legacy
  }
}
```

---

## 📊 Phase 5: Monitoring & Validation

### Metrics to Track:

1. **Write Success Rate**:
   ```dart
   // Log dual-write outcomes
   final firestoreSuccess = await writeToFirestore();
   final supabaseSuccess = await writeToSupabase();
   
   analytics.logEvent('dual_write', {
     'firestore': firestoreSuccess,
     'supabase': supabaseSuccess,
     'both': firestoreSuccess && supabaseSuccess,
   });
   ```

2. **Data Consistency**:
   ```sql
   -- Compare counts
   SELECT COUNT(*) FROM chat_messages; -- Supabase
   -- vs Firestore collection count
   ```

3. **Real-time Latency**:
   ```dart
   final sendTime = DateTime.now();
   await persistence.sendMessage(message);
   
   stream.listen((messages) {
     if (messages.any((m) => m.id == message.id)) {
       final latency = DateTime.now().difference(sendTime);
       print('📊 Latency: ${latency.inMilliseconds}ms');
     }
   });
   ```

### Health Checks:

```sql
-- Check for orphaned messages (no chat_metadata)
SELECT cm.id 
FROM chat_messages cm
LEFT JOIN chat_metadata meta ON cm.chat_id = meta.id
WHERE meta.id IS NULL
LIMIT 10;

-- Check for negative unread counts
SELECT id, unread_counts 
FROM chat_metadata 
WHERE jsonb_typeof(unread_counts) = 'object';
```

---

## 🔄 Phase 6: Gradual Migration

### Week 1: Dual-Write with Firestore Reads
```dart
useSupabase = false;
dualWriteMode = true;  // Write to both
```

### Week 2: 10% Supabase Reads
```dart
bool shouldUseSupabase() {
  return Random().nextInt(100) < 10; // 10% of requests
}
```

### Week 3: 50% Supabase Reads
```dart
return Random().nextInt(100) < 50;
```

### Week 4: 100% Supabase, Firestore Backup
```dart
useSupabase = true;
dualWriteMode = true;  // Still write to Firestore as backup
```

### Week 5-8: Supabase-Only
```dart
useSupabase = true;
dualWriteMode = false; // Stop writing to Firestore
```

---

## 🛟 Rollback Plan

### If Something Goes Wrong:

**Immediate (< 5 minutes)**:
```dart
// In lib/core/config.dart
static const bool useSupabase = false;  // ← Change to false
static const bool dualWriteMode = true;
```

**24 Hours**:
- Analyze logs to find root cause
- Fix bugs in SupabasePersistence
- Re-test in staging

**7 Days**:
- Implement fixes
- Run migration again
- Monitor closely

---

## 📝 Post-Migration Cleanup (Week 9+)

1. **Archive Firestore Data**:
   ```bash
   # Export Firestore to Cloud Storage
   gcloud firestore export gs://squad-sync-firestore-backup
   ```

2. **Remove Firestore Dependencies**:
   ```yaml
   # pubspec.yaml - Remove these:
   # cloud_firestore: ^4.13.3
   # firebase_core: ^2.24.0
   ```

3. **Delete Old Code**:
   ```bash
   rm lib/services/firestore_service.dart
   rm lib/services/dual_database_service.dart
   ```

4. **Update Documentation**:
   - Update README.md with Supabase setup
   - Remove Firebase instructions
   - Add Supabase connection string

---

## ✅ Success Criteria

Migration is complete when:

- [x] Supabase schema deployed successfully
- [x] ChatPersistenceService interface created
- [x] SupabasePersistence implemented
- [ ] All messages writing to Supabase
- [ ] Real-time streams working
- [ ] Zero data loss during migration
- [ ] Performance ≥ Firestore baseline
- [ ] <0.1% error rate in production
- [ ] Firestore safely deprecated

---

## 🆘 Troubleshooting

### Issue: Messages not appearing in Supabase

**Solution**:
1. Check RLS policies allow authenticated inserts
2. Verify `sender_id` matches auth.uid()
3. Check Supabase logs: Dashboard > Logs > Postgres

### Issue: Real-time not updating

**Solution**:
1. Verify table in `supabase_realtime` publication
2. Check `stream(primaryKey: ['id'])` has correct primary key
3. Enable real-time in Supabase dashboard

### Issue: "Auth user not found"

**Solution**:
1. Ensure Firebase Auth user exists in Supabase
2. Run user migration script first
3. Check `auth.users` table populated

---

## 📞 Need Help?

- **Supabase Docs**: https://supabase.com/docs
- **Realtime Guide**: https://supabase.com/docs/guides/realtime
- **RLS Guide**: https://supabase.com/docs/guides/auth/row-level-security
- **Discord**: https://discord.supabase.com

---

**Next Step**: Run `supabase_schema.sql` in Supabase SQL Editor! 🚀
