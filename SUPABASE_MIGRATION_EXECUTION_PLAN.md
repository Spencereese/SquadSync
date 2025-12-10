# SquadSync: Full Supabase Migration - Execution Plan

**Decision Date**: December 7, 2025  
**Target**: Complete migration from Firebase to Supabase as primary database  
**Timeline**: 3-4 weeks  
**Status**: Planning Phase

---

## Executive Summary

This plan guides the complete migration from Firebase (Firestore + Firebase Auth + Firebase Storage) to Supabase (PostgreSQL + Supabase Auth + Supabase Storage) with zero data loss and minimal downtime.

**Current State**:
- 50+ direct Firebase calls across notifiers/services/repositories
- 30+ direct Supabase calls across services
- No centralized database abstraction layer
- Dual-write chaos (inconsistent implementation)

**Target State**:
- 100% Supabase for all new operations
- Firebase read-only mode for 30-day legacy data access
- Clean repository pattern with Supabase-backed implementations
- Firebase dependencies removed from pubspec.yaml

---

## Phase 1: Firebase Dependency Audit & Inventory (Days 1-2)

### Objective
Create complete inventory of Firebase usage across the codebase to plan migration systematically.

### Tasks

#### 1.1 Automated Firebase Detection
```bash
# Find all Firebase imports
grep -r "import 'package:firebase" lib/ --include="*.dart" | wc -l
grep -r "import 'package:cloud_firestore" lib/ --include="*.dart"
grep -r "import 'package:firebase_auth" lib/ --include="*.dart"
grep -r "import 'package:firebase_storage" lib/ --include="*.dart"

# Find all FirebaseFirestore.instance calls
grep -r "FirebaseFirestore.instance" lib/ --include="*.dart"
grep -r "FirebaseAuth.instance" lib/ --include="*.dart"
grep -r "FirebaseStorage.instance" lib/ --include="*.dart"
```

#### 1.2 Manual File Categorization
Create `FIREBASE_MIGRATION_INVENTORY.md` with:

**Category A: High Priority (Core Features)**
- [ ] `lib/presentation/notifiers/current_squad_notifier.dart` - 6 Firestore calls (squad updates)
- [ ] `lib/presentation/notifiers/user_notifier.dart` - 2 Firestore calls (user profile)
- [ ] `lib/chat/chat_screen.dart` - 5 Firestore calls (read receipts, stats)
- [ ] `lib/chat/chat_service.dart` - Firestore fallback streams
- [ ] `lib/services/auth_service.dart` - FirebaseAuth (legacy)

**Category B: Medium Priority (Features)**
- [ ] `lib/services/poll_service.dart` - Firestore only
- [ ] `lib/services/reaction_service.dart` - Firestore only
- [ ] `lib/services/background_service.dart` - Mixed (Firestore + Supabase Storage)
- [ ] `lib/services/firestore_service.dart` - Firestore wrapper
- [ ] All `lib/data/repositories/*_impl.dart` files - FirebaseFirestore injected

**Category C: Low Priority (Utils/Helpers)**
- [ ] `lib/services/firestore_to_supabase_migrator.dart` - Migration tool (delete after use)
- [ ] Any Firebase Analytics calls (if present)

**Category D: No Migration Needed (Already Supabase)**
- ✅ `lib/services/friends_service.dart` - Pure Supabase
- ✅ `lib/services/clip_service.dart` - Pure Supabase
- ✅ `lib/services/auth_service_supabase.dart` - Pure Supabase

#### 1.3 Data Volume Assessment
```sql
-- Run in Supabase SQL Editor
SELECT 
  'users' as table_name, COUNT(*) as rows FROM users
UNION ALL
SELECT 'squads', COUNT(*) FROM squads
UNION ALL
SELECT 'chat_messages', COUNT(*) FROM chat_messages
UNION ALL
SELECT 'clips', COUNT(*) FROM clips
UNION ALL
SELECT 'friends', COUNT(*) FROM friends;
```

**Deliverables**:
- ✅ `FIREBASE_MIGRATION_INVENTORY.md` with categorized file list
- ✅ Migration priority matrix (High/Medium/Low)
- ✅ Data volume report from Supabase
- ✅ Estimated migration effort per category

---

## Phase 2: Quick Wins - Delete Legacy State Management (Day 3)

### Objective
Remove confirmed-unused legacy code to reduce surface area before migration.

### Tasks

#### 2.1 Delete Legacy SquadState
**File**: `lib/squad_state_notifier.dart` (92 lines)

**Verification**:
```bash
grep -r "LegacySquadState" lib/ --include="*.dart"
grep -r "squad_state_notifier" lib/ --include="*.dart"
```

**Action**: If no active imports found, delete file immediately.

#### 2.2 Audit ChatState Duplication
**Files**:
- `lib/chat/chat_state.dart` (194 lines - ChangeNotifier)
- `lib/chat/chat_state_notifier.dart` (210 lines - StateNotifier)

**Verification**:
```bash
grep -r "extends ChangeNotifier" lib/chat/chat_state.dart
grep -r "ChatState(" lib/ --include="*.dart" | grep -v chat_state
```

**Action**: 
- If `chat_state.dart` (ChangeNotifier) has zero imports → delete
- If still used → migrate usages to `chat_state_notifier.dart` → delete

#### 2.3 Fix Incorrect Linter Ignores
**Files**: 
- `lib/services/voice_service.dart` (3 fields)
- `lib/services/video_service.dart` (3 fields)

**Issue**: Fields marked `// ignore: unused_field` but ARE actually used

**Action**: Remove incorrect ignore comments

#### 2.4 Delete Legacy Models (If Unused)
**Files**:
- `lib/models/poll.dart`
- `lib/models/squad.dart`

**Verification**: Check if superseded by `lib/domain/entities/`

**Expected Savings**: ~300-400 lines deleted

---

## Phase 3: Firebase → Supabase Migration Implementation (Days 4-10)

### Objective
Systematically replace all Firebase calls with Supabase equivalents.

### 3.1 Authentication Migration (Day 4)

#### Current State
- `lib/services/auth_service.dart` - Firebase Auth
- `lib/services/auth_service_supabase.dart` - Supabase Auth (exists but not primary)

#### Migration Steps

1. **Make Supabase Auth Primary**:
   ```dart
   // lib/core/providers.dart
   final authServiceProvider = Provider<AuthService>((ref) {
     return AuthServiceSupabase(); // Changed from AuthService()
   });
   ```

2. **Update All Auth Calls**:
   - Replace `FirebaseAuth.instance.currentUser?.uid` 
   - With `Supabase.instance.client.auth.currentUser?.id`

3. **UID Format Handling**:
   - Firebase UIDs: 28-char alphanumeric
   - Supabase UIDs: 36-char UUID
   - Add migration mapping table if needed:
   ```sql
   CREATE TABLE uid_migration_map (
     firebase_uid TEXT PRIMARY KEY,
     supabase_uid UUID NOT NULL
   );
   ```

4. **Test Authentication Flows**:
   - [ ] Apple Sign-In
   - [ ] Email/Password login
   - [ ] Password reset
   - [ ] Session persistence

#### 3.2 Firestore → Supabase Database Migration (Days 5-7)

##### 3.2.1 Squad Management Migration

**Files to Update**:
- `lib/presentation/notifiers/current_squad_notifier.dart`
- `lib/presentation/notifiers/squad_notifier.dart`
- `lib/data/repositories/squad_repository_impl.dart`

**Current Firestore Calls** (from `current_squad_notifier.dart`):
```dart
await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({...})
await FirebaseFirestore.instance.collection('squads').doc(squadId).get()
```

**Replace With Supabase**:
```dart
await supabase.from('squads').update({...}).eq('id', squad.id)
await supabase.from('squads').select().eq('id', squadId).single()
```

**Database Schema Check**:
```sql
-- Verify squads table exists in Supabase
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'squads';
```

##### 3.2.2 User Profile Migration

**Files to Update**:
- `lib/presentation/notifiers/user_notifier.dart`
- `lib/data/repositories/user_repository_impl.dart`

**Current Firestore Calls**:
```dart
await firestore.collection('users').doc(uid).set({...})
await firestore.collection('users').doc(uid).get()
```

**Replace With Supabase**:
```dart
await supabase.from('users').upsert({...})
await supabase.from('users').select().eq('id', uid).single()
```

##### 3.2.3 Chat Messages Migration

**Files to Update**:
- `lib/chat/chat_service.dart` (remove Firestore fallback)
- `lib/services/message_service.dart` (already uses Supabase)
- `lib/chat/chat_screen.dart` (update read receipts, stats)

**Current**: Dual-mode (Supabase primary + Firestore fallback)  
**Target**: Pure Supabase

**Read Receipt Migration**:
```dart
// OLD (Firestore)
await FirebaseFirestore.instance
  .collection('chat_metadata')
  .doc(chatId)
  .update({'lastRead': timestamp});

// NEW (Supabase)
await supabase
  .from('chat_metadata')
  .update({'last_read': timestamp})
  .eq('chat_id', chatId)
  .eq('user_id', userId);
```

##### 3.2.4 Polls & Reactions Migration

**Files to Update**:
- `lib/services/poll_service.dart` - Currently Firestore-only
- `lib/services/reaction_service.dart` - Currently Firestore-only

**Supabase Schema Creation**:
```sql
-- Create polls table
CREATE TABLE IF NOT EXISTS polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID REFERENCES chat_messages(id) ON DELETE CASCADE,
  question TEXT NOT NULL,
  options JSONB NOT NULL, -- Array of {text, votes: [user_ids]}
  created_by TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ
);

-- Create reactions table
CREATE TABLE IF NOT EXISTS reactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID REFERENCES chat_messages(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL,
  emoji TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(message_id, user_id, emoji)
);
```

**Migrate Service Code**:
```dart
// lib/services/poll_service.dart
class PollService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  Future<void> createPoll({...}) async {
    await _supabase.from('polls').insert({...});
  }
  
  Stream<List<Poll>> pollsStream(String messageId) {
    return _supabase
      .from('polls')
      .stream(primaryKey: ['id'])
      .eq('message_id', messageId)
      .map((data) => data.map((json) => Poll.fromJson(json)).toList());
  }
}
```

#### 3.3 Firebase Storage → Supabase Storage Migration (Day 8)

**Files to Update**:
- `lib/services/media_service.dart` (currently dual-upload)
- `lib/services/background_service.dart` (mixed usage)
- `lib/services/clip_service.dart` (already Supabase - verify)

**Current Dual-Upload Pattern**:
```dart
// Upload to both Firebase + Supabase
final firebaseUrl = await _uploadToFirebase(file);
final supabaseUrl = await _uploadToSupabase(file);
```

**Target Pattern**:
```dart
// Supabase only
final supabaseUrl = await _uploadToSupabase(file);
```

**Storage Bucket Setup**:
```sql
-- Verify buckets exist
SELECT * FROM storage.buckets;

-- Create if missing
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('clips', 'clips', true),
  ('avatars', 'avatars', true),
  ('media', 'media', false);
```

**RLS Policies for Storage**:
```sql
-- Allow authenticated users to upload their own files
CREATE POLICY "Users can upload media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'media' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Allow public read for clips
CREATE POLICY "Public can view clips"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'clips');
```

#### 3.4 Data Migration Script Execution (Day 9)

**Use Existing Migrator**:
- File: `lib/services/firestore_to_supabase_migrator.dart`

**Migration Sequence**:
1. **Users** → Migrate all user profiles first
2. **Squads** → Migrate squad data with member references
3. **Chat Messages** → Bulk migrate with batching (1000 per batch)
4. **Media URLs** → Update storage references
5. **Polls & Reactions** → Migrate if data exists

**Run Migration**:
```dart
// In Flutter app or standalone script
final migrator = FirestoreToSupabaseMigrator();

// Migrate users
await migrator.migrateUsers();

// Migrate squads
await migrator.migrateSquads();

// Migrate messages (with progress tracking)
await migrator.migrateMessages(batchSize: 1000);

// Verify migration
final report = await migrator.generateMigrationReport();
print(report);
```

**Verification Queries**:
```sql
-- Compare counts
SELECT 'Firestore Users' as source, COUNT(*) FROM users; -- Check manually
SELECT 'Supabase Users' as source, COUNT(*) FROM users;

-- Check for missing data
SELECT id FROM users WHERE display_name IS NULL OR display_name = '';
```

#### 3.5 Repository Layer Update (Day 10)

**Update All Repository Implementations**:

Files to update:
- `lib/data/repositories/chat_repository_impl.dart`
- `lib/data/repositories/game_repository_impl.dart`
- `lib/data/repositories/squad_repository_impl.dart`
- `lib/data/repositories/system_repository_impl.dart`
- `lib/data/repositories/user_repository_impl.dart`

**Pattern - Remove Firebase Injection**:
```dart
// OLD
class ChatRepositoryImpl implements ChatRepository {
  final FirebaseFirestore _firestore;
  final SupabaseClient _supabase;
  
  ChatRepositoryImpl(this._firestore, this._supabase);
  ...
}

// NEW
class ChatRepositoryImpl implements ChatRepository {
  final SupabaseClient _supabase;
  
  ChatRepositoryImpl(this._supabase);
  ...
}
```

**Update Provider Definitions**:
```dart
// lib/core/providers.dart

// OLD
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    FirebaseFirestore.instance,
    Supabase.instance.client,
  );
});

// NEW
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    Supabase.instance.client,
  );
});
```

---

## Phase 4: Repository Layer Consolidation (Days 11-13)

### Objective
Move all direct database calls from notifiers into repository layer for clean architecture.

### 4.1 Notifier Refactoring

#### Current Issue
Notifiers bypass repository layer with direct database calls:
```dart
// lib/presentation/notifiers/current_squad_notifier.dart (BAD)
await FirebaseFirestore.instance.collection('squads').doc(squad.id).update({...})
```

#### Target Pattern
```dart
// Use repository instead (GOOD)
final squadRepo = ref.read(squadRepositoryProvider);
await squadRepo.updateSquad(squad.id, updates);
```

#### Files to Refactor

**High Priority**:
- [ ] `lib/presentation/notifiers/current_squad_notifier.dart` - 6 direct calls
- [ ] `lib/presentation/notifiers/user_notifier.dart` - 2 direct calls
- [ ] `lib/chat/chat_screen.dart` - 5 direct calls (read receipts)

**Process per File**:
1. Identify all direct Supabase/Firebase calls
2. Create corresponding repository methods if missing
3. Replace direct calls with `ref.read(repositoryProvider).method()`
4. Test thoroughly

### 4.2 Create Missing Repository Methods

**Example - SquadRepository Enhancement**:
```dart
// lib/domain/repositories/squad_repository.dart
abstract class SquadRepository {
  // Existing methods...
  
  // ADD these for notifier support:
  Future<void> updateSquadSpots(String squadId, Map<String, dynamic> spots);
  Future<void> updateSquadTimer(String squadId, TimerData timer);
  Future<void> clearSquadSpot(String squadId, int spotIndex);
  Stream<Squad> watchSquad(String squadId); // Real-time updates
}

// lib/data/repositories/squad_repository_impl.dart
class SquadRepositoryImpl implements SquadRepository {
  final SupabaseClient _supabase;
  
  @override
  Future<void> updateSquadSpots(String squadId, Map<String, dynamic> spots) async {
    await _supabase.from('squads').update({'spots': spots}).eq('id', squadId);
  }
  
  @override
  Stream<Squad> watchSquad(String squadId) {
    return _supabase
      .from('squads')
      .stream(primaryKey: ['id'])
      .eq('id', squadId)
      .map((data) => Squad.fromJson(data.first));
  }
}
```

### 4.3 SQLite Cache Integration

**Current**: `lib/chat/sqlite_helper.dart` used directly by services  
**Target**: Wrap SQLite in repository layer for offline-first architecture

**Create LocalDataSource**:
```dart
// lib/data/datasources/local/chat_local_datasource.dart
class ChatLocalDataSource {
  final SqliteHelper _sqlite;
  
  Future<void> cacheMessage(Message message) async {
    await _sqlite.insertMessage(message.toMap());
  }
  
  Future<List<Message>> getCachedMessages(String chatId, {int limit = 100}) async {
    final maps = await _sqlite.getMessages(chatId, limit: limit);
    return maps.map((m) => Message.fromMap(m)).toList();
  }
}
```

**Update Repository to Use Cache**:
```dart
// lib/data/repositories/chat_repository_impl.dart
class ChatRepositoryImpl implements ChatRepository {
  final SupabaseClient _supabase;
  final ChatLocalDataSource _localDataSource;
  
  @override
  Stream<List<Message>> watchMessages(String chatId) async* {
    // 1. Emit cached data immediately (offline-first)
    final cached = await _localDataSource.getCachedMessages(chatId);
    if (cached.isNotEmpty) yield cached;
    
    // 2. Stream from Supabase (real-time)
    yield* _supabase
      .from('chat_messages')
      .stream(primaryKey: ['id'])
      .eq('chat_id', chatId)
      .order('timestamp', ascending: false)
      .limit(100)
      .map((data) {
        final messages = data.map((json) => Message.fromJson(json)).toList();
        // 3. Update cache in background
        _localDataSource.cacheMessages(messages);
        return messages;
      });
  }
}
```

---

## Phase 5: Service Reorganization & Cleanup (Days 14-16)

### Objective
Restructure 33 service files into logical infrastructure/application layers.

### 5.1 New Folder Structure

**Target Organization**:
```
lib/
├── infrastructure/          # External API integrations (NEW)
│   ├── auth/
│   │   ├── supabase_auth_service.dart
│   │   └── auth_provider.dart (if needed for Apple/Google)
│   ├── database/
│   │   ├── supabase_client.dart (singleton wrapper)
│   │   └── sqlite_helper.dart (offline cache)
│   ├── storage/
│   │   └── supabase_storage_service.dart
│   ├── external_apis/
│   │   ├── igdb_service.dart
│   │   ├── grok_service.dart
│   │   └── agora_service.dart
│   └── media/
│       ├── video_service.dart
│       ├── audio_service.dart
│       └── clip_service.dart
│
└── application/             # App-level services (NEW)
    ├── cache_service.dart
    ├── timer_service.dart
    ├── poll_service.dart
    ├── reaction_service.dart
    ├── friends_service.dart
    ├── onboarding_service.dart
    └── app_flow_manager.dart
```

### 5.2 Service Migration Mapping

**From `lib/services/` to `lib/infrastructure/`**:
- `auth_service_supabase.dart` → `infrastructure/auth/supabase_auth_service.dart`
- `supabase_service.dart` → `infrastructure/database/supabase_client.dart`
- `igdb_service.dart` → `infrastructure/external_apis/igdb_service.dart`
- `grok_service.dart` → `infrastructure/external_apis/grok_service.dart`
- `video_service.dart` → `infrastructure/media/video_service.dart`
- `audio_service.dart` → `infrastructure/media/audio_service.dart`
- `clip_service.dart` → `infrastructure/media/clip_service.dart`

**From `lib/services/` to `lib/application/`**:
- `cache_service.dart` → `application/cache_service.dart`
- `timer_service.dart` → `application/timer_service.dart`
- `poll_service.dart` → `application/poll_service.dart`
- `reaction_service.dart` → `application/reaction_service.dart`
- `friends_service.dart` → `application/friends_service.dart`
- `onboarding_service.dart` → `application/onboarding_service.dart`

### 5.3 Delete Obsolete Services

**Files to DELETE**:
- ❌ `lib/services/auth_service.dart` (Firebase Auth - replaced by Supabase)
- ❌ `lib/services/firestore_service.dart` (Firestore wrapper - no longer needed)
- ❌ `lib/services/firestore_to_supabase_migrator.dart` (one-time migration tool)
- ❌ `lib/chat/sqlite_helper.dart` → Move to `infrastructure/database/`

**Expected Cleanup**: ~500-800 lines deleted

### 5.4 Update All Imports

**Automated Script** (run after file moves):
```bash
#!/bin/bash
# update_imports.sh

# Update auth imports
find lib/ -name "*.dart" -exec sed -i '' \
  's|services/auth_service_supabase|infrastructure/auth/supabase_auth_service|g' {} \;

# Update database imports  
find lib/ -name "*.dart" -exec sed -i '' \
  's|services/supabase_service|infrastructure/database/supabase_client|g' {} \;

# Update external API imports
find lib/ -name "*.dart" -exec sed -i '' \
  's|services/igdb_service|infrastructure/external_apis/igdb_service|g' {} \;

# Run flutter format
flutter format lib/
```

**Manual Verification**:
```bash
# Check for broken imports
flutter analyze lib/ 2>&1 | grep "import"
```

---

## Phase 6: Documentation Update (Days 17-18)

### Objective
Update `squadsync.md` and `CODE_REDUNDANCY_ANALYSIS.md` to reflect Supabase-first architecture.

### 6.1 squadsync.md Updates

**Section 1: Overview (Lines 1-10)**
```markdown
# SquadSync — App Intelligence Summary

## Overview
SquadSync is a Flutter-based squad gaming app for real-time coordination. 
**Supabase-powered architecture** with PostgreSQL, Realtime subscriptions, and 
Row Level Security. Riverpod-based state management with xAI Grok AI integration 
for smart replies.
```

**Section 2: Data Layer (Lines 35-45)**
```markdown
### Data Layer
- **Database**: Supabase PostgreSQL with real-time subscriptions and Row Level Security
- **Real-time Features**: Supabase Realtime for chat streams (messages, typing, presence)
- **Offline Caching**: SQLite via sqflite for message history
- **Media Handling**: Supabase Storage for all uploads (clips, avatars, media)
- **External APIs**: IGDB for game data, xAI Grok API for AI assistance
```

**Section 3: Backend (Lines 47-55)**
```markdown
### Backend
- **Database**: Supabase PostgreSQL (hosted)
- **Timer Processing**: Supabase pg_cron (server-side timer processing every 30 seconds)
- **Authentication**: Supabase Auth with Apple Sign-In and Email/Password
- **AI Integration**: xAI Grok API (grok-4.1-fast-latest) for smart replies
```

**Remove All Firebase References**:
- Delete mentions of "dual-database"
- Delete "Firebase (Backup)" references
- Delete "Firebase Cloud Functions"
- Delete "dual-write mode"

### 6.2 CODE_REDUNDANCY_ANALYSIS.md Updates

**Add New Section 9: Supabase Migration Results**
```markdown
## 9. Supabase Migration Completion ✅ **COMPLETED**

### Status: **RESOLVED** (December 2025)

**Migration Summary**:
- ✅ All Firebase dependencies removed from codebase
- ✅ 50+ Firestore calls migrated to Supabase PostgreSQL
- ✅ Firebase Auth replaced with Supabase Auth
- ✅ Firebase Storage replaced with Supabase Storage
- ✅ Data migrated with zero loss (verified via migration report)

**Deleted Files** (Firebase-specific):
- ❌ `lib/services/auth_service.dart` (Firebase Auth)
- ❌ `lib/services/firestore_service.dart` (Firestore wrapper)
- ❌ `lib/services/firestore_to_supabase_migrator.dart` (one-time migration)
- ❌ `functions/` folder (Firebase Cloud Functions)

**Architecture Improvements**:
- ✅ Clean repository pattern with Supabase-backed implementations
- ✅ Offline-first architecture with SQLite caching
- ✅ Real-time subscriptions via Supabase Realtime
- ✅ Row Level Security enforced at database level

**Impact**: 
- Reduced complexity (single database instead of dual)
- Improved performance (PostgreSQL > Firestore for relational data)
- Better security (RLS policies)
- Lower costs (Supabase pricing < Firebase for this use case)
```

**Update Section Summary Table**:
```markdown
| Issue | Status | Lines Saved | Date Resolved |
|-------|--------|-------------|---------------|
| Duplicate Group Dialogs | ✅ Resolved | 1,214 | Dec 6, 2025 |
| Legacy State Management | ✅ Resolved | 286 | Dec 7, 2025 |
| Firebase Dependencies | ✅ Resolved | 800+ | Dec 2025 |
| Service Organization | ✅ Resolved | - | Dec 2025 |
```

### 6.3 Update .github/copilot-instructions.md

**Section: Architecture Overview**
```markdown
## Architecture Overview
SquadSync is a Flutter-based squad gaming app with **Supabase-powered backend**:
- **Frontend**: Flutter app using Riverpod for state management
- **Data Layer**: Supabase PostgreSQL for all data + SQLite for offline caching
- **Backend**: Supabase (PostgreSQL, Realtime, Auth, Storage) + Node.js/Express for analytics
- **State Management**: Riverpod notifiers with freezed entities and repository pattern
```

**Section: Database Integration**
```markdown
### Supabase Integration
- **Auth**: Supabase Auth with Apple Sign-In, Email/Password
- **Database**: PostgreSQL with Row Level Security (RLS)
- **Realtime**: Supabase Realtime for chat streams, typing indicators, presence
- **Storage**: Supabase Storage with signed URLs for media
- **Timers**: pg_cron for server-side timer processing (every 30 seconds)
- **Offline support**: SQLite caching with offline-first data access
```

**Remove**: All Firebase-specific sections

---

## Phase 7: Firebase Dependency Removal & Testing (Days 19-21)

### Objective
Remove Firebase packages from `pubspec.yaml` and verify app functionality.

### 7.1 Update pubspec.yaml

**Remove Firebase Dependencies**:
```yaml
# DELETE these lines
dependencies:
  firebase_core: ^x.x.x
  firebase_auth: ^x.x.x
  cloud_firestore: ^x.x.x
  firebase_storage: ^x.x.x
  firebase_analytics: ^x.x.x  # if present
```

**Keep Supabase Dependencies**:
```yaml
dependencies:
  supabase_flutter: ^2.x.x
  sqflite: ^2.x.x
  # ... other dependencies
```

**Run Dependency Update**:
```bash
flutter pub get
flutter pub outdated  # Check for updates
flutter pub upgrade   # Upgrade all packages
```

### 7.2 Remove Firebase Configuration Files

**Android** (`android/app/`):
- ❌ Delete `google-services.json`

**iOS** (`ios/Runner/`):
- ❌ Delete `GoogleService-Info.plist`

**Firebase Config** (if present):
```dart
// lib/firebase_options.dart - DELETE entire file
```

**Update main.dart**:
```dart
// OLD
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(...);
  runApp(MyApp());
}

// NEW
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  runApp(MyApp());
}
```

### 7.3 Comprehensive Testing Plan

#### 7.3.1 Authentication Tests
- [ ] Apple Sign-In flow
- [ ] Email/Password registration
- [ ] Email/Password login
- [ ] Password reset
- [ ] Session persistence (app restart)
- [ ] Logout flow

#### 7.3.2 Core Feature Tests
- [ ] Create new squad
- [ ] Join existing squad
- [ ] Update squad spots
- [ ] Claim spot with timer
- [ ] Timer expiration (wait 30+ seconds)
- [ ] Clear squad spot

#### 7.3.3 Chat Tests
- [ ] Send text message
- [ ] Send media (image/video)
- [ ] Real-time message updates
- [ ] Typing indicators
- [ ] Read receipts
- [ ] Offline message queue
- [ ] Message reactions
- [ ] Message polls

#### 7.3.4 Social Features Tests
- [ ] Send friend request
- [ ] Accept/decline friend request
- [ ] View friends list
- [ ] Unfriend user
- [ ] Block user
- [ ] Search for users

#### 7.3.5 Media Tests
- [ ] Upload clip
- [ ] View clips feed
- [ ] Delete clip
- [ ] Upload avatar
- [ ] Update profile picture

#### 7.3.6 Offline Tests
- [ ] Enable airplane mode
- [ ] Send message (should queue)
- [ ] Disable airplane mode
- [ ] Verify message sent
- [ ] View cached messages offline

#### 7.3.7 Performance Tests
- [ ] App startup time (< 3 seconds)
- [ ] Chat message load time (< 1 second for 100 messages)
- [ ] Real-time latency (< 500ms for message delivery)
- [ ] Memory usage (< 200MB baseline)

### 7.4 Rollback Plan (If Issues Found)

**If critical issues discovered**:

1. **Immediate Rollback** (< 1 hour):
   ```bash
   git checkout main
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Partial Rollback** (keep some Supabase features):
   - Re-add Firebase packages to pubspec.yaml
   - Keep Supabase for new features only
   - Firebase for legacy data read-only

3. **Migration Issue Resolution**:
   - Check Supabase logs: Dashboard → Logs → Postgres
   - Check RLS policies: Dashboard → Authentication → Policies
   - Verify data integrity: Run SQL count queries
   - Re-run migration script if data loss detected

---

## Success Criteria

### Phase Completion Checklist

- [ ] **Phase 1**: Complete Firebase inventory with 100% file coverage
- [ ] **Phase 2**: Zero legacy state management files remain
- [ ] **Phase 3**: 100% of Firebase calls replaced with Supabase
- [ ] **Phase 4**: All notifiers use repository pattern (no direct DB calls)
- [ ] **Phase 5**: Services reorganized into infrastructure/application folders
- [ ] **Phase 6**: Documentation updated with zero Firebase references
- [ ] **Phase 7**: Firebase packages removed, all tests passing

### Quality Gates

**Code Quality**:
- ✅ `flutter analyze` reports zero errors
- ✅ Zero direct database calls in presentation layer
- ✅ All services have single responsibility

**Data Integrity**:
- ✅ Migration report shows 100% data transfer
- ✅ Zero data loss (verified via SQL counts)
- ✅ User authentication works for all existing users

**Performance**:
- ✅ App startup time ≤ 3 seconds
- ✅ Real-time message latency ≤ 500ms
- ✅ Memory usage ≤ 200MB baseline

**Testing**:
- ✅ All authentication flows tested
- ✅ All core features tested
- ✅ Offline mode tested
- ✅ No regressions vs. pre-migration

---

## Risk Mitigation

### High-Risk Areas

1. **UID Format Mismatch** (Firebase 28-char vs Supabase 36-char UUID)
   - **Mitigation**: Create `uid_migration_map` table
   - **Fallback**: Keep Firebase Auth for 30 days read-only

2. **Data Loss During Migration**
   - **Mitigation**: Dry-run migration script first
   - **Fallback**: Firebase read-only backup for 30 days

3. **RLS Policy Misconfiguration**
   - **Mitigation**: Test policies with multiple user accounts
   - **Fallback**: Temporarily disable RLS if blocking access

4. **Real-time Subscription Failures**
   - **Mitigation**: Implement exponential backoff retry logic
   - **Fallback**: Polling fallback every 5 seconds

5. **Storage URL Migration**
   - **Mitigation**: Keep Firebase Storage read-only for 30 days
   - **Fallback**: Dual-read from both storages if URL not found

### Monitoring & Alerts

**Setup Supabase Alerts**:
```sql
-- Monitor RLS policy denials
SELECT * FROM pg_stat_statements 
WHERE query LIKE '%RLS%' 
ORDER BY calls DESC;

-- Monitor slow queries
SELECT * FROM pg_stat_statements 
WHERE mean_exec_time > 1000 
ORDER BY mean_exec_time DESC;
```

**App-Level Error Tracking**:
```dart
// Add Sentry or similar
await Sentry.captureException(error, stackTrace: stackTrace);
```

---

## Timeline Summary

| Phase | Duration | Depends On | Deliverables |
|-------|----------|------------|--------------|
| 1. Firebase Audit | 2 days | None | Inventory markdown file |
| 2. Legacy Cleanup | 1 day | Phase 1 | 4 files deleted |
| 3. Migration Implementation | 7 days | Phase 2 | 100% Supabase calls |
| 4. Repository Consolidation | 3 days | Phase 3 | Clean architecture |
| 5. Service Reorganization | 3 days | Phase 4 | infrastructure/ and application/ folders |
| 6. Documentation Update | 2 days | Phase 5 | Updated markdown files |
| 7. Firebase Removal & Testing | 3 days | Phase 6 | Passing tests, no Firebase deps |
| **TOTAL** | **21 days** | - | **Supabase-only app** |

**Estimated Effort**: 3 weeks (1 developer full-time)

---

## Post-Migration Maintenance

### First 30 Days
- Monitor Supabase Dashboard daily for errors
- Keep Firebase project active but read-only
- Address any user-reported issues immediately

### After 30 Days
- Delete Firebase project (if no issues)
- Remove Firebase API keys
- Close Firebase billing

### Long-Term
- Quarterly Supabase performance review
- Update RLS policies as features evolve
- Expand test coverage to 80%+

---

**Document Version**: 1.0  
**Last Updated**: December 7, 2025  
**Owner**: SquadSync Development Team  
**Status**: Ready for Execution
