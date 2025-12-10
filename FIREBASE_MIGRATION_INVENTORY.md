# Firebase Migration Inventory

**Generated**: December 7, 2025  
**Purpose**: Complete audit of Firebase dependencies for Supabase migration  
**Status**: Phase 1 - Inventory Complete

---

## Executive Summary

**Total Firebase Imports**: 9 packages  
**Firestore Imports**: 47 files  
**FirebaseFirestore.instance Direct Calls**: 90+ locations across 36 files  
**Firebase Auth**: No active usage (already migrated to Supabase)  
**Firebase Storage**: 2 files (commented out - already migrated)  
**Legacy State Management**: 2 files (ChangeNotifier pattern)

---

## Current Firebase Dependencies (pubspec.yaml)

```yaml
dependencies:
  firebase_core: ^4.1.1
  cloud_firestore: ^6.1.0  # Comment says "Still needed for chat until migrated to Supabase"
  firebase_messaging: ^16.0.2
  firebase_analytics: ^12.0.2
  google_sign_in: ^7.2.0
  sign_in_with_apple: ^7.0.1
```

**Action**: Remove `firebase_core`, `cloud_firestore`, `firebase_analytics` in Phase 7  
**Keep**: `firebase_messaging` (push notifications - check if needed)  
**Note**: `google_sign_in` and `sign_in_with_apple` are not Firebase-specific

---

## Category A: High Priority (Core Features - 12 files)

### 1. Squad Management Notifiers (Direct DB Calls)
**Priority**: 🔴 CRITICAL

| File | Firestore Calls | Migration Complexity | Notes |
|------|----------------|---------------------|-------|
| `lib/presentation/notifiers/current_squad_notifier.dart` | 14 direct calls | High | Update squad spots, timers, peacock queue |
| `lib/presentation/notifiers/user_notifier.dart` | 1 direct call | Low | User profile updates |
| `lib/presentation/notifiers/user_squads_notifier.dart` | 1 stream | Low | Watch user's squad memberships |

**Migration Strategy**: 
- Create SquadRepository methods for all operations
- Replace `FirebaseFirestore.instance` with repository calls
- Use Supabase Realtime for squad streams

**Sample Migration**:
```dart
// BEFORE
await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({
  'spots': updatedSpots,
  'updatedAt': FieldValue.serverTimestamp(),
});

// AFTER
await ref.read(squadRepositoryProvider).updateSquadSpots(
  squad.id, 
  updatedSpots,
);

// Repository implementation (Supabase)
@override
Future<void> updateSquadSpots(String squadId, Map<String, dynamic> spots) async {
  await _supabase.from('squads').update({
    'spots': spots,
    'updated_at': DateTime.now().toIso8601String(),
  }).eq('id', squadId);
}
```

---

### 2. Chat Screen & Services (Mixed Usage)
**Priority**: 🔴 CRITICAL

| File | Firestore Usage | Migration Complexity | Notes |
|------|----------------|---------------------|-------|
| `lib/chat/chat_screen.dart` | 5 direct calls | Medium | Read receipts, message stats, user lookup |
| `lib/chat/chat_service.dart` | Wrapped usage | Low | Already has Supabase primary, Firestore fallback |
| `lib/services/message_service.dart` | Already Supabase | None | ✅ No migration needed |

**Migration Strategy**:
- `chat_screen.dart`: Move read receipt logic to ChatRepository
- `chat_service.dart`: Remove Firestore fallback streams
- Test real-time message delivery thoroughly

**Read Receipt Migration**:
```dart
// BEFORE (chat_screen.dart)
await FirebaseFirestore.instance
  .collection('chat_metadata')
  .doc(chatId)
  .update({'lastRead': timestamp});

// AFTER
await ref.read(chatRepositoryProvider).updateReadReceipt(
  chatId: chatId,
  userId: userId,
  timestamp: timestamp,
);

// Repository (Supabase)
@override
Future<void> updateReadReceipt({
  required String chatId,
  required String userId,
  required DateTime timestamp,
}) async {
  await _supabase.from('chat_metadata').upsert({
    'chat_id': chatId,
    'user_id': userId,
    'last_read': timestamp.toIso8601String(),
  });
}
```

---

### 3. Discovery & Clips (Firestore Heavy)
**Priority**: 🟡 MEDIUM

| File | Firestore Usage | Migration Complexity | Notes |
|------|----------------|---------------------|-------|
| `lib/presentation/notifiers/discovery_notifier.dart` | 2 queries | Medium | Squad discovery search |
| `lib/presentation/notifiers/clip_notifier.dart` | 8 calls | High | Clip feeds, uploads, squad clips |
| `lib/screens/discovery_screen.dart` | 2 batch writes | Medium | Join squad operations |

**Migration Strategy**:
- Discovery: Supabase full-text search or Postgres `LIKE` queries
- Clips: Already using Supabase Storage, just migrate metadata queries
- Use Supabase RLS for access control

**Clip Query Migration**:
```dart
// BEFORE
final query = FirebaseFirestore.instance
  .collection('clips')
  .where('squadId', isEqualTo: squadId)
  .orderBy('createdAt', descending: true)
  .limit(50);

// AFTER
final clips = await _supabase
  .from('clips')
  .select()
  .eq('squad_id', squadId)
  .order('created_at', ascending: false)
  .limit(50);
```

---

## Category B: Medium Priority (Supporting Features - 15 files)

### 4. Chat Dialogs & Widgets
**Priority**: 🟡 MEDIUM

| File | Firestore Usage | Migration Complexity |
|------|----------------|---------------------|
| `lib/chat/dialogs/group_actions_dialog.dart` | 1 firestore instance | Low |
| `lib/chat/dialogs/invite_members_dialog.dart` | 1 update call | Low |
| `lib/chat/screens/chat_info_screen.dart` | 8 queries/updates | Medium |
| `lib/chat/widgets/direct_messages_tab.dart` | 2 instances | Low |
| `lib/chat/widgets/user_groups_tab.dart` | 1 instance | Low |
| `lib/chat/widgets/clip_player_screen.dart` | 2 calls | Low |
| `lib/chat/peacock_modal.dart` | 3 add/set calls | Low |
| `lib/chat/media_history_screen.dart` | 1 stream | Low |
| `lib/chat/chat_groups_screen.dart` | Instance usage | Low |

**Migration Strategy**: 
- Replace `FirebaseFirestore.instance` with `Supabase.instance.client`
- Use Supabase from/select/insert/update pattern
- Test group creation/management flows

---

### 5. Chat Services (Specialized)
**Priority**: 🟡 MEDIUM

| File | Firestore Usage | Migration Complexity |
|------|----------------|---------------------|
| `lib/chat/services/reaction_service.dart` | 3 update calls | Low |
| `lib/chat/services/chat_online_status_manager.dart` | Instance usage | Low |
| `lib/chat/services/chat_media_handler.dart` | 1 imageRef call | Low |
| `lib/chat/services/chat_message_search_delegate.dart` | 1 query | Low |
| `lib/chat/services/chat_initialization_service.dart` | 1 get call | Low |

**Migration Strategy**:
- Move to Supabase Realtime for presence/online status
- Reactions already have Supabase schema (from migration plan)
- Media metadata in Supabase Storage metadata

---

### 6. General Services
**Priority**: 🟡 MEDIUM

| File | Firestore Usage | Migration Complexity | Notes |
|------|----------------|---------------------|-------|
| `lib/services/poll_service.dart` | Full Firestore | Medium | Needs Supabase schema creation |
| `lib/services/reaction_service.dart` | Full Firestore | Low | Duplicate (also in chat/services) |
| `lib/services/background_service.dart` | Mixed usage | Medium | Uses both Firestore + Supabase Storage |
| `lib/services/auth_service.dart` | 4 Firestore calls | Medium | User profile creation/updates |
| `lib/services/ai_service.dart` | 1 instance | Low | Context fetching |
| `lib/services/squad_auto_selector.dart` | 2 queries | Low | Squad selection logic |

**Migration Strategy**:
- Poll service: Create Supabase polls table (schema in migration plan)
- Auth service: Move user profile logic to UserRepository
- Background service: Remove Firestore, keep Supabase Storage

---

## Category C: Low Priority (Utils/Legacy - 8 files)

### 7. Data Layer (Repository Implementations)
**Priority**: 🟢 LOW (Easy refactor)

| File | Firestore Usage | Migration Complexity |
|------|----------------|---------------------|
| `lib/data/repositories/game_repository_impl.dart` | Injected instance | Low |
| `lib/data/repositories/user_repository_impl.dart` | Injected instance | Low |
| `lib/data/datasources/squad_remote_datasource.dart` | Import only | Low |
| `lib/data/datasources/system_remote_datasource.dart` | Import only | Low |
| `lib/data/datasources/user_remote_datasource.dart` | Import only | Low |
| `lib/data/datasources/chat_remote_datasource_impl.dart` | Import only | Low |

**Migration Strategy**:
- Remove FirebaseFirestore injection from constructors
- Update to use Supabase client instead
- Already following repository pattern (easy swap)

---

### 8. Misc UI & Legacy Files
**Priority**: 🟢 LOW

| File | Firestore Usage | Migration Complexity |
|------|----------------|---------------------|
| `lib/squad_tab/squad_tab.dart` | 3 streams/queries | Medium |
| `lib/setup_screen.dart` | 1 instance | Low |
| `lib/notification_service.dart` | 1 instance | Low |
| `lib/managers/notification_manager.dart` | 1 instance | Low |
| `lib/models/poll.dart` | Import (legacy model) | None (delete) |
| `lib/models/squad.dart` | Import (legacy model) | None (delete) |
| `lib/domain/entities/message.dart` | Import only | None (remove import) |
| `lib/chat/models/message_data.dart` | Import only | None (remove import) |

**Migration Strategy**:
- squad_tab.dart: Replace streams with Supabase Realtime
- Delete lib/models/ folder (superseded by domain/entities/)
- Remove unused imports from domain/entities/

---

### 9. Infrastructure (Dependency Injection)
**Priority**: 🔴 CRITICAL (Foundational)

| File | Firestore Usage | Action Required |
|------|----------------|-----------------|
| `lib/core/injection.dart` | Registers FirebaseFirestore singleton | Remove registration |

**Migration**:
```dart
// BEFORE
getIt.registerSingleton<FirebaseFirestore>(FirebaseFirestore.instance);

// AFTER
getIt.registerSingleton<SupabaseClient>(Supabase.instance.client);
```

---

### 10. Migration Tools (One-Time Use)
**Priority**: ⚪ DELETE AFTER USE

| File | Purpose | Action |
|------|---------|--------|
| `lib/services/firestore_to_supabase_migrator.dart` | Data migration script | Run in Phase 3, delete in Phase 5 |
| `lib/services/firestore_service.dart` | Firestore wrapper | Delete in Phase 5 |

---

## Category D: No Migration Needed (Already Supabase) ✅

### 11. Pure Supabase Files (No Changes)

| File | Status | Notes |
|------|--------|-------|
| `lib/services/auth_service_supabase.dart` | ✅ Pure Supabase | Primary auth service |
| `lib/services/friends_service.dart` | ✅ Pure Supabase | Friends system |
| `lib/services/clip_service.dart` | ✅ Pure Supabase | Clip uploads to Supabase Storage |
| `lib/services/message_service.dart` | ✅ Pure Supabase | Message creation/sending |
| `lib/chat/chat_service.dart` | 🟡 Supabase + Firestore fallback | Remove fallback in Phase 3 |

---

## Legacy State Management (Delete in Phase 2)

### Files to DELETE:

1. **`lib/squad_state_notifier.dart`** (92 lines)
   - Status: ❌ Legacy stub for ChangeNotifier pattern
   - Current Usage: 3 imports found
     - `lib/chat/services/chat_ui_manager.dart`
     - `lib/chat/services/chat_online_status_manager.dart`
     - `lib/chat/services/chat_typing_manager.dart`
   - Action: Remove imports from 3 files, then delete

2. **`lib/chat/chat_state.dart`** (194 lines - ChangeNotifier)
   - Status: 🟡 Needs usage verification
   - Competing with: `lib/chat/chat_state_notifier.dart` (StateNotifier)
   - Action: Search for `ChatState(` usage (excluding the definition files)
   - If unused → Delete
   - If used → Migrate to StateNotifier version → Delete

**Expected Savings**: ~286 lines deleted

---

## Firebase Configuration Files (Delete in Phase 7)

### Android
- ❌ `android/app/google-services.json`

### iOS
- ❌ `ios/Runner/GoogleService-Info.plist`

### Flutter
- ❌ Check for `lib/firebase_options.dart` (if exists)
- ❌ `firebase.json` (root directory)
- ❌ `firestore.rules` (root directory)
- ❌ `storage.rules` (root directory)

---

## Migration Effort Estimation

### By Priority

| Priority | Files | Estimated Effort | Depends On |
|----------|-------|------------------|------------|
| 🔴 Critical | 6 files | 4 days | None |
| 🟡 Medium | 23 files | 5 days | Critical files done |
| 🟢 Low | 14 files | 2 days | Medium files done |
| ⚪ Delete | 4 files | 1 day | Migration complete |
| **TOTAL** | **47 files** | **12 days** | Sequential |

### By Feature Area

| Feature | Files | Firestore Calls | Complexity |
|---------|-------|----------------|-----------|
| Squad Management | 4 | 16 | High |
| Chat System | 18 | 35 | High |
| Discovery & Clips | 3 | 12 | Medium |
| Services | 8 | 15 | Medium |
| Data Layer | 6 | N/A (injected) | Low |
| UI Components | 8 | 12 | Low |

---

## Migration Blockers & Dependencies

### Critical Path

```
Phase 1 (Audit) ✅ COMPLETE
    ↓
Phase 2 (Legacy Cleanup) → Must verify ChatState usage
    ↓
Phase 3 (Migration) → Requires Supabase schemas created
    ↓  ↓  ↓
    Auth Migration (Day 4)
    Database Migration (Days 5-7)
    Storage Migration (Day 8)
    ↓
Phase 4 (Repositories) → Depends on Phase 3 complete
    ↓
Phase 5 (Service Reorg) → Depends on Phase 4
    ↓
Phase 6 (Documentation) → Depends on Phase 5
    ↓
Phase 7 (Firebase Removal) → Depends on all above + testing
```

### Known Issues to Address

1. **UID Format Change**
   - Firebase: 28-char alphanumeric
   - Supabase: 36-char UUID
   - Solution: Create uid_migration_map table OR regenerate user data

2. **Server Timestamp Handling**
   - Firestore: `FieldValue.serverTimestamp()`
   - Supabase: `DateTime.now().toIso8601String()` OR use PostgreSQL `now()`
   - Solution: Use PostgreSQL default `DEFAULT NOW()` in schema

3. **Real-time Subscription Differences**
   - Firestore: `.snapshots()` streams
   - Supabase: `.stream(primaryKey: ['id'])`
   - Solution: Update all stream listeners

4. **Batch Operations**
   - Firestore: `batch.update()`, `batch.commit()`
   - Supabase: Use PostgreSQL transactions via RPC or multiple upserts
   - Solution: Create RPC functions for complex batch operations

---

## Supabase Schema Requirements

### Tables to Verify/Create

Based on Firestore collection usage, ensure these Supabase tables exist:

- ✅ `users` (should exist)
- ✅ `squads` (should exist)
- ✅ `chat_messages` (should exist)
- ✅ `chat_metadata` (for read receipts)
- ✅ `clips` (should exist)
- ❓ `polls` (create in Phase 3)
- ❓ `reactions` (create in Phase 3)
- ❓ `peacocks` (peacock queue - create in Phase 3)
- ❓ `user_squads` (junction table - verify exists)

### RLS Policies to Create

- ✅ `chat_messages` - Already defined in `supabase_chat_rls_fix.sql`
- ❓ `polls` - Create in Phase 3
- ❓ `reactions` - Create in Phase 3
- ❓ `squads` - Verify existing or create

---

## Testing Requirements Per File Category

### Critical Files (Must Test Thoroughly)
- [ ] Squad spot claiming/releasing (current_squad_notifier.dart)
- [ ] Timer expiration (current_squad_notifier.dart)
- [ ] Real-time chat messages (chat_screen.dart, chat_service.dart)
- [ ] Read receipts (chat_screen.dart)
- [ ] User profile updates (user_notifier.dart)
- [ ] Squad discovery search (discovery_notifier.dart)
- [ ] Clip uploads and feeds (clip_notifier.dart)

### Medium Priority (Spot Check)
- [ ] Group creation/management (dialogs)
- [ ] Reactions on messages
- [ ] Polls in chat
- [ ] Online status indicators
- [ ] Message search

### Low Priority (Smoke Test)
- [ ] Notification triggers
- [ ] Background sync
- [ ] Auto squad selection

---

## Phase 2 Pre-Flight Checklist

Before proceeding to delete legacy files:

- [x] Audit complete (this document)
- [ ] Verify `ChatState` usage with grep
- [ ] Remove 3 imports of `squad_state_notifier.dart`
- [ ] Confirm no breaking changes from deletions
- [ ] Run `flutter analyze` before and after

---

## Phase 3 Prerequisites

Before starting Firebase → Supabase migration:

- [ ] Supabase project credentials verified
- [ ] All required tables exist in Supabase
- [ ] RLS policies tested with multiple users
- [ ] Backup Firebase data (export Firestore collections)
- [ ] Migration script dry-run successful
- [ ] Rollback plan documented

---

## Success Metrics

### Code Reduction
- Target: ~1,100+ lines deleted
  - Phase 2: 286 lines (legacy state)
  - Phase 5: 800 lines (Firebase services)

### Architecture Improvement
- ✅ Zero direct database calls in presentation layer
- ✅ 100% Supabase for all new writes
- ✅ Clean repository pattern enforced
- ✅ Single source of truth (Supabase only)

### Performance
- Real-time message latency ≤ 500ms
- Squad data updates ≤ 1 second
- Clip feed load time ≤ 2 seconds

---

**Inventory Complete** ✅  
**Next Step**: Phase 2 - Legacy State Management Cleanup  
**Owner**: Development Team  
**Review Date**: Before Phase 3 execution
