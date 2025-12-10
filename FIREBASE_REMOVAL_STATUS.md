# Firebase to Supabase Migration Status
**Date:** December 6, 2025
**Branch:** feature/material3-theme-2026

## ✅ Completed

### 1. Supabase Voice Room Service
- ✅ Created `lib/services/supabase_voice_room_service.dart`
- ✅ Uses Realtime channels for presence tracking
- ✅ Broadcast for mute/speaking state
- ✅ Real-time participant synchronization

### 2. VoiceService Migration
- ✅ Removed `cloud_firestore` import
- ✅ Removed `FirestoreService` dependency
- ✅ Integrated `SupabaseVoiceRoomService`
- ✅ Updated `VoiceRoomNotifier` to use Supabase Realtime
- ✅ Voice rooms now 100% Supabase (no Firestore)

### 3. Dual-Write System Removal
- ✅ Deleted `lib/services/dual_database_service.dart`
- ✅ Simplified `lib/core/app_config.dart` (removed migration flags)
- ✅ Removed all dual-write infrastructure

## 🚧 In Progress

### 4. Firestore Services Migration to Supabase

**Files Still Using Firestore:**
- `lib/chat/chat_service.dart` - Main chat service (dual-write code still present)
- `lib/services/message_service.dart` - Message handling (dual-write code still present)
- `lib/services/poll_service.dart` - Poll functionality
- `lib/services/ai_service.dart` - AI context queries
- `lib/services/reaction_service.dart` - Message reactions
- `lib/services/onboarding_service.dart` - User onboarding
- `lib/services/firestore_service.dart` - Legacy Firestore wrapper
- `lib/data/datasources/user_remote_datasource.dart`
- `lib/data/datasources/squad_remote_datasource.dart`
- `lib/data/datasources/chat_remote_datasource_impl.dart`
- `lib/data/datasources/system_remote_datasource.dart`
- `lib/data/repositories/user_repository_impl.dart`
- `lib/data/repositories/game_repository_impl.dart`
- `lib/presentation/onboarding/onboarding_notifier.dart`
- `lib/presentation/onboarding/onboarding_wrapper_example.dart`

**Strategy:**
1. Replace Firestore queries with `supabase.from().select()/insert()/update()/delete()`
2. Replace Firestore streams with `supabase.from().stream(primaryKey: ['id'])`
3. Update FieldValue.serverTimestamp() with DateTime.now().toIso8601String()
4. Handle foreign key constraints (ensure users exist before inserting messages)

## ⏳ Pending

### 5. Firebase Package Removal
**To Remove from pubspec.yaml:**
- `cloud_firestore: ^6.0.2`
- `firebase_storage: ^13.0.2`
- `firebase_database: ^12.0.2`
- `cloud_functions: ^6.0.4`

**To Keep:**
- `firebase_core: ^4.1.1` ✅
- `firebase_auth: ^4.1.1` ✅ (primary auth)
- `firebase_messaging: ^16.0.2` ✅ (push notifications)
- `firebase_analytics: ^12.0.2` ✅ (analytics)

### 6. Backend Migration
**backend/server.js:**
- Remove Firestore cleanup job (lines 80-95)
- Replace Firebase Storage signed URLs with Supabase Storage
- Remove `firebase-admin` dependency
- Remove `@google-cloud/firestore` dependency

**functions/ directory:**
- Archive to `functions_archived_2025-12-06/`
- Keep for 30 days as backup
- Cloud Functions timers replaced by Supabase pg_cron

## 📊 Migration Progress
- Voice/Video: **100%** ✅
- Chat Services: **25%** (dual-write code identified)
- Data Layer: **0%** (repositories still use Firestore)
- Backend: **0%**
- Package Cleanup: **0%**

## 🔑 Key Changes Made
1. Voice rooms are ephemeral - started fresh with Supabase (no data migration needed)
2. Simplified app_config.dart - removed all migration complexity
3. Supabase Realtime for voice room presence instead of Firestore documents
4. All voice room state managed via broadcast messages and presence tracking

## 📝 Next Steps
1. Complete chat service migration (remove Firestore, use Supabase only)
2. Migrate data layer repositories to Supabase
3. Remove Firebase packages
4. Archive backend Firebase dependencies
5. Test all functionality
6. Update documentation

