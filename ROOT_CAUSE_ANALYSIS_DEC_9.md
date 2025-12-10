# Root Cause Analysis & Fixes - December 9, 2025

## Issues Reported
1. Profile not loading
2. No pinned games showing in squad
3. No groups in chats tab
4. Error creating group: "null value in column 'id' violates not-null constraint"

## Root Causes Identified

### 1. **Database Schema Mismatch** 🔴 CRITICAL
**Problem**: The `chat_groups` table's `id` column was defined as `PRIMARY KEY` without a default value, but the code was trying to insert groups without always providing an ID.

**Evidence**:
```sql
-- Old schema (wrong)
CREATE TABLE chat_groups (
  id TEXT PRIMARY KEY,  -- ❌ No default, requires manual value
  ...
)
```

**Impact**: 
- Creating groups failed with "null value in column 'id'" error
- Users couldn't create any chat groups

**Fix**: 
- Updated database schema to auto-generate UUIDs: `id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text`
- Modified insert code to retrieve the generated ID from database response
- See `fix_chat_groups_schema.sql` for migration

### 2. **Column Naming Inconsistency** 🔴 CRITICAL
**Problem**: Code used camelCase (`pinnedGames`) but database uses snake_case (`pinned_games`)

**Evidence**:
```dart
// Old code (wrong)
await _remoteDataSource.updateUserProfile(user.id, {
  'pinnedGames': currentPinned,  // ❌ Database has pinned_games
});
```

**Impact**:
- Pinned games not saving to database
- Games selected during onboarding disappeared after refresh
- Profile showed "no pinned games" even after selection

**Fix**:
```dart
// Fixed code
await _remoteDataSource.updateUserProfile(user.id, {
  'pinned_games': currentPinned,  // ✅ Matches database
});
```

### 3. **User Groups Not Being Loaded** 🟡 MAJOR
**Problem**: Code tried to load `user_groups` from `users` table, but groups actually live in `chat_groups` table

**Evidence**:
```dart
// Old code (wrong)
userGroups: List<Map<String, dynamic>>.from(profile['user_groups'] ?? [])
```

**Impact**:
- Chat tab always showed "No groups yet"
- Users couldn't see groups they were members of
- Profile loading appeared to work but groups were empty

**Fix**:
- Added `getUserGroups()` method to query `chat_groups` table
- Filter groups where `member_uids` contains the user's UID
```dart
Future<List<Map<String, dynamic>>> getUserGroups(String uid) async {
  final response = await _supabase
      .from('chat_groups')
      .select()
      .contains('member_uids', [uid]);
  return List<Map<String, dynamic>>.from(response as List);
}
```

### 4. **Missing Database Columns** 🟡 MAJOR
**Problem**: The migration scripts show that `user_ratings` and `complaints` tables were using wrong column names

**Evidence**:
```
PostgrestException: column user_ratings.uid does not exist
Hint: Perhaps you meant to reference the column "user_ratings.id"
```

**Impact**:
- Profile loading partially failed (but continued with basic user)
- Ratings and complaints data not loading

**Fix**:
- Changed queries from `.eq('uid', uid)` to `.eq('id', uid)`
- Applied to both `user_ratings` and `complaints` tables

## Files Modified

### 1. `/lib/data/datasources/chat_remote_datasource_impl.dart`
**Changes**:
- Modified `createGroup()` to conditionally include ID
- Added `.select().single()` to retrieve generated ID from database
- Return group with actual database-generated ID via `copyWith()`

**Before**:
```dart
final groupData = {'id': group.id, ...};
await _supabase.from('chat_groups').insert(groupData);
return group;
```

**After**:
```dart
final groupData = {
  if (group.id.isNotEmpty) 'id': group.id,
  ...
};
final response = await _supabase.from('chat_groups').insert(groupData).select().single();
return group.copyWith(id: response['id'] as String);
```

### 2. `/lib/data/repositories/user_repository_impl.dart`
**Changes**:
- Fixed `addPinnedGame()` column name: `pinnedGames` → `pinned_games`
- Fixed `removePinnedGame()` column name: `pinnedGames` → `pinned_games`
- Added call to `getUserGroups()` in `getCurrentUser()`
- Use `userGroups` from database instead of profile field

**Before**:
```dart
await _remoteDataSource.updateUserProfile(user.id, {
  'pinnedGames': currentPinned,  // ❌ Wrong
});

userGroups: List<Map<String, dynamic>>.from(profile['user_groups'] ?? [])  // ❌ Wrong
```

**After**:
```dart
await _remoteDataSource.updateUserProfile(user.id, {
  'pinned_games': currentPinned,  // ✅ Correct
});

final userGroups = await _remoteDataSource.getUserGroups(user.id);
userGroups: userGroups,  // ✅ Correct
```

### 3. `/lib/data/datasources/user_remote_datasource.dart`
**Changes**:
- Added `getUserGroups()` method to abstract class
- Implemented `getUserGroups()` to query `chat_groups` table
- Fixed column names in `getUserRatings()` and `getUserComplaints()`

**Added**:
```dart
Future<List<Map<String, dynamic>>> getUserGroups(String uid) async {
  final response = await _supabase
      .from('chat_groups')
      .select()
      .contains('member_uids', [uid]);
  return List<Map<String, dynamic>>.from(response as List);
}
```

### 4. `/fix_chat_groups_schema.sql` (NEW FILE)
**Purpose**: Database migration to fix `chat_groups` schema

**Key Changes**:
- Set default for `id` column: `DEFAULT gen_random_uuid()::text`
- Add performance indexes
- Update RLS policies
- Verification queries

## Testing Checklist

After applying these fixes, test the following:

### ✅ Onboarding Flow
- [ ] Sign up with email
- [ ] Select callsign and avatar
- [ ] Select games (1-6 games)
- [ ] Complete preferences
- [ ] Verify games appear in Squad tab after onboarding

### ✅ Profile Loading
- [ ] Profile displays correct display name
- [ ] Profile image shows (if set)
- [ ] Pinned games display in Squad tab
- [ ] No console errors about missing columns

### ✅ Chat Groups
- [ ] Create a new group (should succeed without ID error)
- [ ] Group appears in Chats tab
- [ ] Can send messages in group
- [ ] Group persists after app restart

### ✅ Database
- [ ] Run `fix_chat_groups_schema.sql` in Supabase SQL Editor
- [ ] Verify `chat_groups` table has default for `id` column
- [ ] Check that `users` table has `pinned_games` column (snake_case)

## Migration Steps

1. **Run SQL Migration**:
   ```bash
   # In Supabase SQL Editor, run:
   cat fix_chat_groups_schema.sql
   ```

2. **Hot Restart Flutter App**:
   ```bash
   # Press 'R' in terminal or:
   flutter run
   ```

3. **Test Critical Flows**:
   - Sign out and sign in again
   - Try creating a group
   - Select some games
   - Check if they appear in Squad tab

4. **Monitor Logs**:
   ```bash
   # Watch for these success messages:
   ✅ Profile loaded successfully
   UserRepository: Pinned games count: X
   UserRepository: User groups count: Y
   ✅ Group created successfully
   ```

## Prevention

To avoid similar issues in the future:

1. **Always use snake_case for database columns** (PostgreSQL convention)
2. **Let database auto-generate IDs** unless there's a specific reason not to
3. **Load relational data from proper tables** (groups from chat_groups, not users)
4. **Test database operations in SQL Editor first** before implementing in code
5. **Check database schema matches code expectations** (column names, types, defaults)

## Related Documentation

- Database schema: `supabase_schema.sql`
- Migration history: `supabase_migration_day5_complete.sql`
- Onboarding flow: `lib/presentation/onboarding/onboarding_flow.dart`
- User data flow: `lib/data/repositories/user_repository_impl.dart`
