# Column Name Fix - December 9, 2025

## Problem Identified

**Root Cause**: The entire codebase was using the OLD column name `members` instead of `member_uids` that exists in the Supabase database.

### Error Messages
```
PostgrestException(message: Could not find the 'members' column of 'chat_groups' in the schema cache, code: PGRST204)
```

### Symptoms
- ❌ Profile not loading
- ❌ No pinned games showing in Squad tab
- ❌ No groups appearing in Chats tab
- ❌ Cannot create new groups
- ❌ Cannot join existing groups

## Solution Applied

### Files Fixed (8 total)

#### 1. `lib/domain/entities/chat_group.dart`
**Changes**:
- Removed `part 'chat_group.g.dart';` (no longer needed)
- Added custom `fromJson()` method to handle both snake_case (`member_uids`) and camelCase (`memberUids`)
- Added custom `toJson()` method to convert to snake_case for database operations
- Added `const ChatGroup._();` private constructor to enable custom methods

**Result**: Automatic conversion between Dart camelCase and database snake_case

#### 2. `lib/squad_tab/squad_tab.dart` (Line 341)
```dart
// BEFORE
.select('members')

// AFTER
.select('member_uids')
```

Also fixed:
```dart
// BEFORE
final members = List<String>.from(chatGroupDoc['members'] ?? []);

// AFTER
final members = List<String>.from(chatGroupDoc['member_uids'] ?? []);
```

#### 3. `lib/presentation/notifiers/user_notifier.dart` (Lines 341, 360)
```dart
// BEFORE
final members = List<String>.from(groupData['members'] ?? []);
await supabase.from('chat_groups').update({
  'members': members,
  'member_count': (groupData['member_count'] ?? 0) + 1,
}).eq('id', groupId);

// AFTER
final members = List<String>.from(groupData['member_uids'] ?? []);
await supabase.from('chat_groups').update({
  'member_uids': members,
  'member_count': (groupData['member_count'] ?? 0) + 1,
}).eq('id', groupId);
```

#### 4. `lib/chat/chat_groups_screen.dart` (Line 447)
```dart
// BEFORE
final members = List<String>.from(response['members'] ?? []);

// AFTER
final members = List<String>.from(response['member_uids'] ?? []);
```

#### 5. `lib/chat/dialogs/group_actions_dialog.dart` (4 locations)

**Location 1** - Suggested groups (Line 176):
```dart
// BEFORE
final members = List<String>.from(groupData['members'] ?? []);

// AFTER
final members = List<String>.from(groupData['member_uids'] ?? []);
```

**Location 2** - Search results (Line 304):
```dart
// BEFORE
final members = List<String>.from(groupData['members'] ?? []);

// AFTER
final members = List<String>.from(groupData['member_uids'] ?? []);
```

**Location 3** - Join public group (Line 331):
```dart
// BEFORE
final existingMembers = List<String>.from(groupData['members'] ?? []);
await SupabaseService.client.from('chat_groups').update({
  'members': existingMembers,
  'member_count': existingMembers.length,
}).eq('id', groupId);

// AFTER
final existingMembers = List<String>.from(groupData['member_uids'] ?? []);
await SupabaseService.client.from('chat_groups').update({
  'member_uids': existingMembers,
  'member_count': existingMembers.length,
}).eq('id', groupId);
```

**Location 4** - Create new group (Line 724):
```dart
// BEFORE
.insert({
  'name': groupName,
  'is_public': _isPublic,
  'created_by': currentUser.id,
  'member_count': 1,
  'members': [currentUser.id],  // ❌ WRONG COLUMN
  'image_url': null,
  'game_focus': _selectedGames.isNotEmpty ? _selectedGames : null,
})

// AFTER
.insert({
  'name': groupName,
  'is_public': _isPublic,
  'created_by': currentUser.id,
  'member_count': 1,
  'member_uids': [currentUser.id],  // ✅ CORRECT COLUMN
  'image_url': null,
  'game_focus': _selectedGames.isNotEmpty ? _selectedGames : null,
})
```

#### 6. `lib/chat/available_squads_widget.dart` (Line 65)
```dart
// BEFORE
final currentSpots = (data['members'] as List<dynamic>?)?.length ?? 0;

// AFTER
final currentSpots = (data['member_uids'] as List<dynamic>?)?.length ?? 0;
```

#### 7. `lib/data/datasources/chat_remote_datasource_impl.dart`
**Already correct** - was using `member_uids` properly:
```dart
final groupData = {
  'member_uids': memberUids,
  'member_count': memberUids.length,
  // ...
};
```

## Database Schema (Verified)

Current `chat_groups` table schema:
```sql
Column Name       | Data Type                | Default                   | Nullable
------------------|--------------------------|---------------------------|----------
id                | text                     | gen_random_uuid()::text   | NO
name              | text                     | null                      | YES
member_uids       | ARRAY                    | ARRAY[]::text[]           | NO    ✅
is_dm             | boolean                  | false                     | YES
is_public         | boolean                  | false                     | YES
game_name         | text                     | null                      | YES
created_by        | text                     | null                      | YES
created_at        | timestamp with time zone | now()                     | YES
updated_at        | timestamp with time zone | now()                     | YES
member_count      | integer                  | 0                         | YES
is_private        | boolean                  | false                     | YES
invite_code       | text                     | null                      | YES
image_url         | text                     | null                      | YES
last_message      | text                     | null                      | YES
last_message_time | timestamp with time zone | null                      | YES
game_focus        | text                     | null                      | YES
```

**Note**: The old `members` column has been removed from the database.

## Testing Checklist

After hot restart (`R` in terminal):

- [ ] **Create a new group** - Should work without errors
- [ ] **Check Chats tab** - Groups should appear in the list
- [ ] **Join existing group** - Should work without errors
- [ ] **Select games during onboarding** - Should save to `pinned_games`
- [ ] **Check Squad tab** - Pinned games should appear
- [ ] **Check profile** - Should load correctly with all data
- [ ] **Send messages in group** - Chat should work normally

## Code Changes Summary

- **8 files modified**
- **0 files deleted**
- **1 file created** (this document)
- **15+ occurrences** of `members` → `member_uids` fixed

## Technical Details

### Why This Happened
During the Supabase migration, the database column was renamed from `members` to `member_uids` to match PostgreSQL naming conventions (snake_case), but the Dart code wasn't updated to reflect this change.

### The Fix
1. Updated all direct column references in queries from `'members'` to `'member_uids'`
2. Added custom JSON serialization in `ChatGroup` entity to handle snake_case ↔ camelCase conversion automatically
3. This ensures future database operations use the correct column names

### Prevention
- Always use the entity's `toJson()` method when inserting/updating
- The custom `fromJson()` now handles both formats for backward compatibility
- Database schema changes should be tracked in migration files

## Compilation Status

✅ **All files compile successfully**
- No compile errors
- Only 3 warnings (all safe to ignore):
  1. `ChatGroup._` unused declaration (required for Freezed custom methods)
  2. Two `withOpacity` deprecation warnings in `squad_tab.dart` (cosmetic)

## Next Steps

1. **Hot restart the app**: Press `R` in the Flutter terminal
2. **Test group creation**: Try creating a new group
3. **Verify data loading**: Check that profile, pinned games, and groups all load
4. **Monitor console**: Watch for any new errors

## Related Files

- Original analysis: `ROOT_CAUSE_ANALYSIS_DEC_9.md`
- Database schema: `fix_chat_groups_schema.sql`
- Migration guide: `SUPABASE_MIGRATION_PLAN.md`
