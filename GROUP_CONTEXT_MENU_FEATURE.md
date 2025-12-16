# Group Chat Context Menu Feature

## Overview
Added comprehensive context menu for group chats with long-press interaction, visual indicators for muted/pinned/unread status, and full CRUD operations.

## Features Implemented

### 1. Context Menu Actions
**Long press** on any group chat to access:
- ✅ **Mark as Unread** - Sets has_unread flag and unread_count
- ✅ **Pin/Unpin** - Toggle pinned status (pinned groups show pin icon)
- ✅ **Mute/Unmute** - Toggle mute notifications (muted groups show bell icon)
- ✅ **Ignore** - Mute + hide from main list (can be reversed later)
- ✅ **Leave Chat** - Remove yourself from group (existing functionality)
- ✅ **Delete Chat** - Delete entire group (creator only, with confirmation)

### 2. Visual Indicators
Each group chat tile now displays:
- **Unread Badge** (cyan badge with count) - Shows when `has_unread` is true
- **Pin Icon** (amber push pin) - Shows when `is_pinned` is true
- **Mute Icon** (grey bell-off, far right) - Shows when `is_muted` is true

### 3. Metadata Storage
All group-specific settings stored in `users.user_groups` JSONB:
```json
{
  "id": "group-uuid",
  "name": "Group Name",
  "avatar_url": "https://...",
  "is_muted": true,
  "muted_at": "2025-01-15T12:00:00Z",
  "is_pinned": false,
  "pinned_at": null,
  "has_unread": true,
  "unread_count": 5,
  "last_read_at": "2025-01-14T10:00:00Z",
  "is_ignored": false,
  "ignored_at": null
}
```

## Files Modified

### 1. `lib/presentation/notifiers/chat_notifier.dart`
Added 8 new methods:
- `toggleMuteGroup(groupId, currentlyMuted)` - Toggle mute with timestamp
- `togglePinGroup(groupId, currentlyPinned)` - Toggle pin with timestamp
- `markGroupAsUnread(groupId)` - Set unread flag and count
- `markGroupAsRead(groupId)` - Clear unread flag and count
- `ignoreGroup(groupId)` - Set ignored + muted flags
- `deleteGroup(groupId)` - Delete group (creator only, cascades to messages)
- `_updateGroupMetadata(groupId, metadata)` - Helper to update JSONB cache

### 2. `lib/chat/widgets/user_groups_tab.dart`
- Added `_groupMetadataCache` for caching metadata lookups
- Added `_getGroupMetadata(groupId)` method to fetch from JSONB
- Updated `onLongPress` to show `GroupChatContextMenu`
- Added `isMuted`, `hasUnread`, `unreadCount`, `isPinned` params to `_buildGroupTile()`
- Added `trailing` Row to ListTile with badge/pin/mute icons
- Pre-fetch metadata for all groups in `_buildContent()`

### 3. `lib/chat/widgets/group_chat_context_menu.dart`
Created new widget with:
- Material bottom sheet design with rounded corners
- List of menu items with icons and labels
- Confirmation dialogs for destructive actions (ignore, leave, delete)
- Creator-only delete option
- Haptic feedback on interactions

## Usage

### As a User
1. **Long press** any group chat in the list
2. Select an action from the context menu
3. Visual indicators update immediately
4. Changes persist across app restarts

### As a Developer
```dart
// Toggle mute status
await ref.read(chatNotifierProvider.notifier)
  .toggleMuteGroup(groupId, currentlyMuted);

// Mark as unread
await ref.read(chatNotifierProvider.notifier)
  .markGroupAsUnread(groupId);

// Delete group (creator only)
await ref.read(chatNotifierProvider.notifier)
  .deleteGroup(groupId);
```

## Database Schema Impact

### users.user_groups JSONB
Extended with new fields:
- `is_muted: boolean` - Notification mute status
- `muted_at: string` - ISO timestamp when muted
- `is_pinned: boolean` - Pin to top of list
- `pinned_at: string` - ISO timestamp when pinned
- `has_unread: boolean` - Has unread messages
- `unread_count: int` - Number of unread messages
- `last_read_at: string` - ISO timestamp of last read
- `is_ignored: boolean` - Ignored (muted + hidden)
- `ignored_at: string` - ISO timestamp when ignored

### chat_groups table
No changes - all per-user settings in JSONB only

## Future Enhancements
- [ ] Sort groups with pinned ones at the top
- [ ] Filter ignored groups from main list
- [ ] Real-time unread count tracking from new messages
- [ ] Batch actions (select multiple groups to mute/pin)
- [ ] Custom notification sounds per group
- [ ] Auto-read on scroll (mark as read when visible)

## Testing Checklist
- [x] Long press shows context menu
- [x] All menu items trigger correct actions
- [x] Visual indicators display correctly
- [x] Metadata persists across app restarts
- [x] Delete shows confirmation and cascades properly
- [x] Creator-only delete enforcement works
- [x] Non-creator sees "Leave" but not "Delete"
- [ ] Unread count updates when new messages arrive
- [ ] Pinned groups sort to top
- [ ] Ignored groups filter from list

## Known Limitations
1. **Sorting**: Currently sorts by last_message_time only. Pinned groups don't sort to top yet (requires async metadata in sort function).
2. **Unread Tracking**: Unread count must be manually set. No automatic increment on new messages yet.
3. **Ignored Filter**: Ignored groups still show in list (needs filter in _buildContent).
