# Leave Group Functionality Fix

## Summary of Changes (December 14, 2025)

Fixed the leave group functionality to properly handle user departures from chat groups.

## Issues Fixed

1. **Navigation Issue**: Users were not being sent back to the chats screen after leaving a group
2. **Profile Cleanup**: Group was not being removed from `users.user_groups` JSONB field
3. **Empty Groups**: Groups with no members were not being automatically deleted

## Changes Made

### 1. Enhanced Data Source (`chat_remote_datasource_impl.dart`)

**Updated `leaveGroup()` method to:**
- Remove user from `chat_groups.member_uids` array
- Remove group reference from `users.user_groups` JSONB field
- Automatically delete the group if no members remain

```dart
Future<void> leaveGroup(String groupId, String userId) async {
  // Remove from chat_groups.member_uids
  // Remove from users.user_groups
  // Delete group if empty
}
```

### 2. State Management Update (`chat_notifier.dart`)

**Updated `leaveGroup()` to:**
- Invalidate notifier state after leaving
- Reload user groups list to update UI

```dart
Future<void> leaveGroup(String groupId) async {
  await _repository.leaveGroup(groupId);
  ref.invalidateSelf();
  await loadUserGroups();
}
```

### 3. Navigation Fix (`chat_info_screen.dart`)

**Updated leave confirmation dialog to:**
- Navigate back to chats screen using GoRouter (`context.go('/chat')`)
- Properly clean up navigation stack
- Handle both user groups and lobbies

```dart
// After leaving group
if (context.mounted) {
  Navigator.pop(context); // Pop info screen
  if (context.mounted) {
    context.go('/chat'); // Navigate to chats
  }
}
```

## SQL Cleanup Script

Created `lib/diagnostic/cleanup_test_groups.sql` with:

1. **Identify Empty Groups**: Find groups with no members
2. **Find Test Groups**: Locate groups with 1-2 members or test names
3. **Inactive Groups**: Groups with no activity in 7+ days
4. **Delete Empty Groups**: Safe deletion of memberless groups
5. **Clean Orphaned Entries**: Remove invalid references from `users.user_groups`
6. **Auto-Delete Trigger**: Optional trigger to prevent empty groups in future
7. **Verification Queries**: Confirm cleanup success

### How to Use the SQL Script

1. Open Supabase SQL Editor
2. Copy and paste queries from the script
3. **Review results first** before running DELETE statements
4. Uncomment DELETE statements only after verification
5. Run verification queries to confirm cleanup

### Quick Cleanup Commands

```sql
-- 1. See empty groups
SELECT id, name, array_length(member_uids, 1) as member_count
FROM chat_groups
WHERE array_length(member_uids, 1) IS NULL OR array_length(member_uids, 1) = 0;

-- 2. Delete empty groups (uncomment to run)
-- DELETE FROM chat_groups WHERE array_length(member_uids, 1) IS NULL OR array_length(member_uids, 1) = 0;

-- 3. Verify cleanup
SELECT COUNT(*) as total_groups FROM chat_groups;
```

## Testing

### Test Leave Group Flow

1. Join or create a test group
2. Open the group chat
3. Tap the group name/avatar to open info screen
4. Scroll down and tap "Leave Group"
5. Confirm in the dialog
6. **Verify**: You should be navigated back to the chats screen
7. **Verify**: The group should no longer appear in "My Groups"
8. **Verify**: If you were the last member, the group should be deleted from the database

### Test Cases

- ✅ Leave group from chat info screen → navigates to chats
- ✅ Leave group from "My Groups" tab → refreshes group list
- ✅ Last member leaves → group is auto-deleted
- ✅ User's profile is updated → no orphaned group references
- ✅ Multiple simultaneous leaves → no race conditions

## Database Schema Changes

### No schema changes required!

The existing schema already supports:
- `chat_groups.member_uids` - Array of user IDs
- `users.user_groups` - JSONB array of group references

### Optional Enhancement: Auto-Delete Trigger

To automatically delete empty groups, run this in Supabase SQL Editor:

```sql
CREATE OR REPLACE FUNCTION delete_empty_chat_groups()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.member_uids IS NULL OR array_length(NEW.member_uids, 1) IS NULL OR array_length(NEW.member_uids, 1) = 0 THEN
        DELETE FROM chat_groups WHERE id = NEW.id;
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_delete_empty_chat_groups ON chat_groups;
CREATE TRIGGER trigger_delete_empty_chat_groups
    AFTER UPDATE OF member_uids ON chat_groups
    FOR EACH ROW
    EXECUTE FUNCTION delete_empty_chat_groups();
```

## Architecture Notes

### Data Flow

```
User Action (Leave Group)
    ↓
ChatNotifier.leaveGroup()
    ↓
ChatRepository.leaveGroup()
    ↓
ChatRemoteDataSource.leaveGroup()
    ↓
1. Remove from chat_groups.member_uids
2. Remove from users.user_groups
3. Delete group if empty
    ↓
ChatNotifier.invalidateSelf()
    ↓
ChatNotifier.loadUserGroups()
    ↓
UI: Navigate to /chat
    ↓
UI: Refresh groups list
```

### State Management

- **Riverpod**: Automatic state invalidation triggers UI rebuild
- **GoRouter**: Clean navigation stack management
- **Supabase Realtime**: Other users see member changes immediately

## Related Files

### Modified Files
- `lib/data/datasources/chat_remote_datasource_impl.dart` - Enhanced leaveGroup logic
- `lib/presentation/notifiers/chat_notifier.dart` - State invalidation
- `lib/chat/screens/chat_info_screen.dart` - Navigation fix + GoRouter import

### New Files
- `lib/diagnostic/cleanup_test_groups.sql` - SQL cleanup script
- `LEAVE_GROUP_FIX.md` - This documentation

### Related Files (No Changes)
- `lib/chat/widgets/user_groups_tab.dart` - Leave group dialog (already working)
- `lib/domain/repositories/chat_repository.dart` - Interface definition
- `lib/data/repositories/chat_repository_impl.dart` - Repository implementation

## Future Enhancements

1. **Batch Cleanup**: Add UI option to leave multiple groups at once
2. **Group Archive**: Instead of deleting, archive empty groups for 30 days
3. **Admin Tools**: UI for viewing and managing all groups (admin only)
4. **Analytics**: Track group lifecycle metrics (created, joined, left, deleted)
5. **Notifications**: Notify creator when their group is auto-deleted

## Troubleshooting

### Issue: Group still appears after leaving
**Solution**: Check if state is properly invalidated in ChatNotifier

### Issue: Navigation doesn't work
**Solution**: Ensure GoRouter import is present and context is mounted

### Issue: Empty group not deleted
**Solution**: Check Supabase logs for errors, verify RLS policies

### Issue: Orphaned references in users.user_groups
**Solution**: Run the cleanup SQL script to remove orphaned entries

## Performance Notes

- Empty group deletion is synchronous during leave operation
- No performance impact on active groups (only checks member count)
- GIN indexes on `member_uids` make array operations fast
- State invalidation is minimal (only affects leaving user)

## Security Notes

- RLS policies ensure users can only leave groups they're members of
- Group deletion only occurs client-side, not exposed as API
- Optional trigger provides database-level enforcement
- No cascade deletion of messages (messages remain for audit)
