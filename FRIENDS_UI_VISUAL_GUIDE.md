# Friends System - Visual UI Guide

This guide shows what users will see when using the friends system.

---

## 1. Add Friend Button (with Badge)

**Location**: Chat Groups Screen → DM View → Top Right

```
┌─────────────────────────────────────┐
│  Direct Messages            [👤+3]  │ ← Red badge shows 3 pending requests
└─────────────────────────────────────┘
```

**States**:
- **No pending requests**: Just the icon `[👤+]`
- **1-9 requests**: Badge shows count `[👤+5]`
- **10+ requests**: Badge shows `[👤+9+]`

---

## 2. AddFriendDialog - Search Tab

**When user clicks the Add Friend button:**

```
┌─────────────────────────────────────────────┐
│  Add Friend                              ✕  │
├─────────────────────────────────────────────┤
│  [Search] [Requests] [Friends]              │ ← 3 Tabs
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │ 🔍 Search users by name (min 2 ch... │ │ ← Search input
│  └───────────────────────────────────────┘ │
│                                             │
│  ┌─────────────────────────────────────────┐
│  │ [JD] John Doe                           │
│  │      john.doe@email.com                 │
│  │                      [+ Add] [💬]       │ ← Add friend & DM buttons
│  └─────────────────────────────────────────┘
│                                             │
│  ┌─────────────────────────────────────────┐
│  │ [JS] Jane Smith                         │
│  │      jane.smith@email.com               │
│  │                      [+ Add] [💬]       │
│  └─────────────────────────────────────────┘
│                                             │
└─────────────────────────────────────────────┘
```

**Features**:
- **Real-time search** as you type
- **Avatar circles** with first letter (or profile pic)
- **Green "Add" button** sends friend request
- **Cyan message icon** starts DM directly

**Empty state** (before typing):
```
  Type at least 2 characters to search
```

**No results**:
```
  No users found
```

---

## 3. AddFriendDialog - Requests Tab (NEW!)

**Shows incoming friend requests:**

```
┌─────────────────────────────────────────────┐
│  Add Friend                              ✕  │
├─────────────────────────────────────────────┤
│  [Search] [Requests] [Friends]              │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────────┐
│  │ [MJ] Mike Johnson                       │
│  │      "Let's play COD together!"         │ ← Optional message
│  │      Received: 5m ago                   │
│  │                          [✓] [✕]        │ ← Accept/Decline
│  └─────────────────────────────────────────┘
│                                             │
│  ┌─────────────────────────────────────────┐
│  │ [SC] Sarah Connor                       │
│  │      Received: 2h ago                   │
│  │                          [✓] [✕]        │
│  └─────────────────────────────────────────┘
│                                             │
└─────────────────────────────────────────────┘
```

**Features**:
- **Real-time updates** when new requests arrive
- **Purple avatars** for pending requests
- **Optional message** from sender
- **Timestamp** shows when request was sent
- **Green checkmark** accepts request
- **Red X** declines request

**Empty state** (no requests):
```
  ┌─────────────────────────────────┐
  │          ✉️                      │
  │                                 │
  │   No pending friend requests    │
  └─────────────────────────────────┘
```

---

## 4. AddFriendDialog - Friends Tab

**Shows accepted friends:**

```
┌─────────────────────────────────────────────┐
│  Add Friend                              ✕  │
├─────────────────────────────────────────────┤
│  [Search] [Requests] [Friends]              │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────────────────────────────┐
│  │ [AL] Alice Lee                          │
│  │      ✓ Friend                           │
│  │      Friends since 3d ago               │
│  │                          [💬] [🗑️]     │ ← Message/Remove
│  └─────────────────────────────────────────┘
│                                             │
│  ┌─────────────────────────────────────────┐
│  │ [BW] Bob Wilson                         │
│  │      ✓ Friend                           │
│  │      Friends since 1w ago               │
│  │                          [💬] [🗑️]     │
│  └─────────────────────────────────────────┘
│                                             │
└─────────────────────────────────────────────┘
```

**Features**:
- **Real-time updates** when friendships change
- **Blue avatars** for existing friends
- **Green checkmark** shows accepted status
- **"Friends since"** timestamp
- **Cyan message icon** starts DM
- **Red remove icon** removes friend (with confirmation)

**Empty state** (no friends):
```
  ┌─────────────────────────────────┐
  │          👥                      │
  │                                 │
  │      No friends yet             │
  │                                 │
  │  Search for users to add them!  │
  └─────────────────────────────────┘
```

---

## 5. SnackBar Notifications

**Appear at bottom of screen after actions:**

### Friend request sent (GREEN)
```
┌─────────────────────────────────────┐
│ Friend request sent to John Doe     │
└─────────────────────────────────────┘
```

### Friend request accepted (GREEN)
```
┌─────────────────────────────────────┐
│ You are now friends with Mike!      │
└─────────────────────────────────────┘
```

### Friend request declined (ORANGE)
```
┌─────────────────────────────────────┐
│ Friend request declined             │
└─────────────────────────────────────┘
```

### Friend removed (RED)
```
┌─────────────────────────────────────┐
│ Friend removed                      │
└─────────────────────────────────────┘
```

### Error (RED)
```
┌─────────────────────────────────────┐
│ Error sending friend request: ...   │
└─────────────────────────────────────┘
```

---

## 6. Remove Friend Confirmation Dialog

**Appears when user clicks remove button:**

```
┌─────────────────────────────────────┐
│                                     │
│         Remove Friend?              │
│                                     │
│  Are you sure you want to remove    │
│  Alice Lee from your friends?       │
│                                     │
│           [Cancel]  [Remove]        │
│                                     │
└─────────────────────────────────────┘
```

**Features**:
- **Dark background** (`Colors.grey[900]`)
- **White title** text
- **Gray "Cancel"** button (dismisses dialog)
- **Red "Remove"** button (confirms removal)

---

## 7. Loading States

### While searching:
```
  ┌───────────────────────────────────┐
  │ 🔍 Search...              ⌛      │ ← Spinner in search box
  └───────────────────────────────────┘
```

### While loading requests/friends:
```
  ┌─────────────────────────────────┐
  │                                 │
  │             ⌛                   │ ← Centered spinner
  │                                 │
  └─────────────────────────────────┘
```

---

## 8. Error States

### Request loading error:
```
  ┌─────────────────────────────────┐
  │          ⚠️                      │
  │                                 │
  │  Error loading friend requests  │
  │                                 │
  │  [Error details...]             │
  └─────────────────────────────────┘
```

### Friend loading error:
```
  ┌─────────────────────────────────┐
  │          ⚠️                      │
  │                                 │
  │     Error loading friends       │
  │                                 │
  │  [Error details...]             │
  └─────────────────────────────────┘
```

---

## Color Scheme

| Element | Color | Purpose |
|---------|-------|---------|
| Background | `Colors.grey[900]` | Dark card background |
| Card | `Colors.grey[800]` | Slightly lighter cards |
| Text (primary) | `Colors.white` | Main text |
| Text (secondary) | `Colors.grey[400]` | Subtitles, hints |
| Text (tertiary) | `Colors.grey[600]` | Timestamps, metadata |
| Accept/Add | `Colors.green` | Positive actions |
| Decline/Remove | `Colors.red` | Negative actions |
| Message/Primary | `Colors.cyanAccent` | Main brand color |
| Pending Request | `Colors.purple` | Request avatars |
| Friend | `Colors.blue` | Friend avatars |
| Badge | `Colors.red` | Notification badge |

---

## Icon Reference

| Icon | Meaning |
|------|---------|
| 👤+ | Add friend |
| 🔍 | Search |
| 💬 | Send message |
| ✓ | Accept / Confirmed friend |
| ✕ | Decline / Close |
| 🗑️ | Remove friend |
| ⌛ | Loading |
| ⚠️ | Error |
| ✉️ | No requests |
| 👥 | No friends |

---

## User Experience Flow Visualization

```
User sees badge [👤+3]
      ↓
Clicks Add Friend button
      ↓
Dialog opens to Search tab
      ↓
User types "john" → Auto-searches
      ↓
Results appear with [+ Add] buttons
      ↓
User clicks [+ Add] on John Doe
      ↓
✅ Green SnackBar: "Friend request sent to John Doe"
      ↓
Badge increments to [👤+4] on John's device
      ↓
John clicks Add Friend → Requests tab
      ↓
Sees request from user with [✓] [✕] buttons
      ↓
John clicks [✓]
      ↓
✅ Green SnackBar: "You are now friends with [User]!"
      ↓
Both users see each other in Friends tab
      ↓
Badge decrements to [👤+3] on John's device
      ↓
User clicks [💬] on John in Friends tab
      ↓
DM chat opens → Can send messages
```

---

## Technical Details for Developers

### Real-time Updates
- **Badge**: Updates every time `streamPendingRequests()` emits
- **Requests tab**: Rebuilds when new request arrives
- **Friends tab**: Rebuilds when friendship added/removed

### Performance
- **Debounced search**: Searches as you type (after 2 chars)
- **Limited results**: Max 20 users per search
- **Efficient streams**: Only sends changes, not full data
- **Auto-dispose**: Streams cancelled when dialog closes

### Accessibility
- All buttons have tooltips
- Semantic colors (green=good, red=bad)
- Clear labels on all actions
- Haptic feedback on interactions

---

## Summary

✅ **Professional UI** with modern Material Design  
✅ **Real-time updates** keep users in sync  
✅ **Clear feedback** for all actions  
✅ **Empty & error states** handle edge cases  
✅ **Smooth animations** via DraggableScrollableSheet  
✅ **Accessible** with tooltips and semantic colors

**Result**: A complete, production-ready friends system that users will love! 🎉
