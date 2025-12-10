# SquadSync Supabase Schema & Architecture Analysis

**Generated:** December 9, 2025  
**Purpose:** Complete database schema documentation and squad system analysis for debugging and planning fixes

---

## Database Tables Overview

### 1. `users` Table
**Purpose:** User profiles and authentication data

**Key Columns:**
- `uid` (text, PRIMARY KEY) - Firebase/Supabase Auth UID
- `email` (text)
- `display_name` (text)
- `created_at` (timestamp)
- `user_groups` (jsonb) - Array of `{chat_group_id, joined_at}` objects
- `pinned_games` (jsonb) - User's favorite games
- `profile_image_url` (text)
- `bio` (text)
- `blocked_users` (jsonb) - Array of blocked user UIDs
- `squad_ids` (jsonb) - Array of squad IDs the user belongs to

**Critical Issues:**
- ❌ Had broken composite primary key on (`id`, `uid`) where `id` column didn't exist
- ✅ Fixed: Now uses `uid` as sole primary key
- ❌ Legacy code still references `users.id` in some places (should be `users.uid`)

---

### 2. `chat_groups` Table
**Purpose:** Chat groups where users communicate

**Key Columns:**
- `id` (text/bigint, PRIMARY KEY) - Chat group ID
- `name` (text) - Group name
- `member_uids` (text[]) - Array of member UIDs
- `is_public` (boolean) - Public vs private group
- `created_by` (text) - Creator's UID (references `users.uid`)
- `created_at` (timestamp)
- `member_count` (integer)
- `is_dm` (boolean) - Is this a direct message
- `game_name` (text) - Associated game (nullable)
- `game_focus` (text) - Primary game for the group
- `invite_code` (text) - Invite code for joining
- `image_url` (text) - Group avatar
- `last_message` (text) - Last message preview
- `last_message_time` (timestamp)
- `is_private` (boolean)
- `description` (text)
- `avatar_url` (text)
- `metadata` (jsonb)
- `admins` (text[])
- `moderators` (text[])
- `is_active` (boolean)
- `last_activity` (timestamp)
- `settings` (jsonb)

**Foreign Keys:**
- `created_by` → `users.uid`

**Current Implementation:**
- ✅ Groups created successfully
- ✅ Members stored in `member_uids` array
- ✅ User's groups cached in `users.user_groups` jsonb field
- ❌ **NOT linked to squads table** - this is the core issue

---

### 3. `squads` Table
**Purpose:** Game lobbies/sessions for organizing players into game spots

**Key Columns:**
- `id` (text, PRIMARY KEY) - Squad ID
- `name` (text) - Squad/lobby name
- `member_uids` (text[]) - Array of member UIDs
- `game_name` (text) - Specific game for this squad
- `max_spots` (integer) - Maximum number of spots
- `created_by` (text) - Creator's UID
- `created_at` (timestamp)
- `squad_spots` (text[]) - Array of UIDs claiming spots (nullable entries)
- `spot_timers` (jsonb) - Timer data for each spot `{spotIndex: {expiresAt, userId}}`
- `viewers` (text[]) - Users who can view this squad
- `statuses` (jsonb) - Player statuses `{userId: "Ready"/"Calling"/"AFK"}`
- `is_active` (boolean)
- `description` (text)
- `settings` (jsonb)

**How Squads Work (Intended Design):**
1. Squad represents a **game lobby** for a specific game
2. Each squad has **spots** (like a party roster)
3. Users "claim" spots by clicking on them
4. When claimed, spot shows user's name and starts a 5-minute timer
5. User must "lock in" (confirm ready) before timer expires
6. Once all spots filled and locked, game session starts

**Current Issues:**
- ❌ Squads table exists but is NOT created when chat groups are created
- ❌ No link between `chat_groups.id` and `squads.id`
- ❌ When users navigate to chat group, `selectedSquadId` remains null
- ❌ Code tries to claim spots but can't find squad record (PGRST116 error: 0 rows)

---

### 4. `chat_messages` Table (Assumed - standard chat messages)
**Purpose:** Store chat message history

**Key Columns:**
- `id` (text, PRIMARY KEY)
- `chat_group_id` (text) - References chat group
- `sender_id` (text) - Sender's UID
- `text` (text) - Message content
- `timestamp` (timestamp)
- `message_type` (text) - text/image/video/poll/etc
- `media_url` (text)
- `reactions` (jsonb)
- `reply_to` (text) - Message ID being replied to
- `is_deleted` (boolean)

---

### 5. Other Supporting Tables
- `chat_metadata` - Message read receipts, typing indicators
- `chat_read_states` - Track what users have read
- `user_ratings` - User reputation/ratings
- `complaints` - User reports (table may be missing)
- `game_history` - Past game sessions
- `timers` - Background timer processing (Firebase Functions)

---

## Current Squad System Architecture

### How It SHOULD Work:

```
User Flow:
1. User creates/joins a chat group → chat_groups record created
2. Chat group auto-creates a linked squad → squads record created with same ID
3. User navigates to chat screen → selectedSquadId = chat_group.id
4. User clicks "Create Game Lobby" → Shows available games
5. User selects game (e.g., "Satisfactory") → Squad's game_name updated
6. Game lobby shows with empty spots → squad_spots array initialized
7. User clicks spot → claimSpot(gameName, spotIndex) called
8. Spot updates to show user's name + "Calling" status
9. 5-minute timer starts → spot_timers updated
10. User clicks "Lock In" → Status changes to "Ready"
11. When all spots ready → Game session notification sent
```

### Current Broken Flow:

```
Actual Flow:
1. User creates/joins chat group → chat_groups record created ✅
2. NO squad created → squads table has no matching record ❌
3. User navigates to chat screen → selectedSquadId = null ❌
4. User tries to claim spot → Error: squadId is null ❌
5. Even if squadId was set → Error: No squad record exists (0 rows) ❌
```

---

## Code Architecture

### State Management (Riverpod)

**SquadNotifier** (`lib/presentation/notifiers/squad_notifier.dart`)
- Manages `SquadState` with all squad-related data
- Contains `selectedSquadId` - currently active squad
- Methods: `claimSpot()`, `lockSpot()`, `setSelectedSquadId()`

**SquadState** (`lib/domain/entities/squad_state.dart`)
- Contains:
  - `selectedSquadId` - The active squad ID
  - `gameSquadSpots` - Map of game name → array of UIDs in spots
  - `gameSpotTimers` - Map of game name → timer data
  - `userSquads` - Map of squad ID → Squad entity

**ChatNotifier** (`lib/presentation/notifiers/chat_notifier.dart`)
- Manages chat groups and messages
- Methods: `createGroup()`, `joinGroup()`, `leaveGroup()`

### Data Flow

```
Repository Pattern:
UI (ChatScreen, SpotsSheet)
  ↓
Notifier (SquadNotifier, ChatNotifier)
  ↓
Use Case (CreateSquad, AssignSpot)
  ↓
Repository (SquadRepository, ChatRepository)
  ↓
DataSource (SquadRemoteDataSource, ChatRemoteDataSource)
  ↓
Supabase PostgreSQL
```

---

## The Core Problem: Disconnected Systems

### Current State:
- **Chat Groups** exist as social entities
- **Squads** exist as game lobby entities  
- **NO CONNECTION** between them

### What Happens:
1. User creates group "My Friends" (ID: `1765313850363`)
   - Creates record in `chat_groups` ✅
   - Does NOT create record in `squads` ❌

2. User opens chat, tries to create game lobby
   - ChatScreen sets `selectedSquadId = 1765313850363`
   - User clicks game, tries to claim spot
   - Code queries: `SELECT * FROM squads WHERE id = '1765313850363'`
   - Result: 0 rows (PostgrestException PGRST116) ❌

### Recent Failed Fix Attempts:
1. ✅ Fixed `users` table primary key (removed broken composite key)
2. ✅ Fixed column names (`members` → `member_uids`)
3. ✅ Fixed foreign keys to use `users.uid` instead of `users.id`
4. ✅ Added code to set `selectedSquadId` in ChatScreen
5. ❌ **But never created the actual squad record in database**

---

## Proposed Solutions

### Option 1: Auto-Create Squad When Creating Chat Group (ATTEMPTED)
**Status:** Partially implemented in `chat_remote_datasource_impl.dart` but not working

```dart
// In createGroup():
final squadData = {
  'id': groupId, // Same ID as chat group
  'name': group.name,
  'member_uids': memberUids,
  'game_name': null,
  'max_spots': 8,
  'created_by': group.createdBy,
  'created_at': DateTime.now().toIso8601String(),
  'squad_spots': <String?>[],
  'spot_timers': <String, dynamic>{},
  'viewers': memberUids,
  'statuses': <String, String>{},
  'is_active': true,
};

await _supabase.from('squads').insert(squadData);
```

**Issues:**
- Code added but may not be executing
- Error handling might be swallowing failures
- Need to verify if squad is actually being created

### Option 2: Create Squad On-Demand
When user first tries to create a game lobby in a chat group, check if squad exists:
- If exists → Use it
- If not → Create it on the fly

### Option 3: Separate Squads from Chat Groups (Major Refactor)
- Chat groups remain social
- Squads are created via dedicated UI ("Create Game Lobby" button)
- Multiple squads can exist per chat group (different games)
- Squads have their own lifecycle (expire after game ends)

---

## Critical Code Locations

### Squad Creation (Should Happen, Currently Broken)
- `lib/data/datasources/chat_remote_datasource_impl.dart:329-420`
  - `createGroup()` method has squad creation code
  - Need to verify if it's executing and check for errors

### Squad Selection (Works but No Squad Exists)
- `lib/chat/chat_screen.dart:200-214`
  - `didChangeDependencies()` sets `selectedSquadId`
  - This works, but points to non-existent squad

### Spot Claiming (Fails Because No Squad)
- `lib/presentation/notifiers/squad_notifier.dart:239-298`
  - `claimSpot()` checks if `squadId` is not null
  - Calls `_assignSpot()` use case
- `lib/data/datasources/squad_remote_datasource.dart:246-264`
  - `assignSpot()` queries squads table with `.single()`
  - **This fails with PGRST116 if squad doesn't exist**

### UI Entry Points
- `lib/chat/spots_sheet.dart` - Modal for claiming spots
- `lib/chat/squad_sheet.dart` - Shows available game lobbies
- `lib/squad_tab/squad_tab.dart` - Main squad tab (public lobbies)

---

## Database Schema Issues to Check

### RLS Policies
- Need to verify RLS (Row Level Security) is not blocking squad inserts
- Check if authenticated users can insert into `squads` table
- May need permissive policy like:
  ```sql
  CREATE POLICY "squads_full_access" ON squads
  FOR ALL USING (true) WITH CHECK (true);
  ```

### Foreign Key Constraints
- `chat_groups.created_by` → `users.uid` ✅
- `squads.created_by` → `users.uid` (need to verify)
- No explicit FK between `chat_groups.id` and `squads.id` (by design)

### Data Type Mismatches
- `chat_groups.id` is text/bigint (generated as timestamp)
- `squads.id` should match (text)
- Need to ensure ID types are compatible

---

## Next Steps for Complete Fix

### Immediate Diagnostics:
1. **Check if squad creation is failing silently**
   - Add better error logging in `createGroup()`
   - Remove try-catch that might swallow errors
   - Log every step of squad creation

2. **Verify existing chat groups have squads**
   ```sql
   SELECT cg.id, cg.name, s.id as squad_id
   FROM chat_groups cg
   LEFT JOIN squads s ON cg.id = s.id
   WHERE cg.created_by = '<your_uid>';
   ```

3. **Check RLS policies**
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'squads';
   ```

### Permanent Fix Strategy:

**Phase 1: Ensure Squad Creation Works**
1. Fix squad creation in `createGroup()` method
2. Add transaction support (create group + squad atomically)
3. Add proper error handling and rollback

**Phase 2: Backfill Missing Squads**
1. Find all chat groups without squads
2. Create matching squad records
3. Verify all groups now have squads

**Phase 3: Verify Squad Selection**
1. Confirm `selectedSquadId` is set correctly
2. Verify squad exists before allowing spot claims
3. Add UI feedback if squad is missing

**Phase 4: Improve Architecture (Future)**
1. Consider separating game lobbies from chat groups
2. Allow multiple active lobbies per chat group
3. Add lobby expiration and cleanup

---

## Current Error Messages Explained

### `claimSpot called: game=, spotIndex=0`
- Game name is empty string
- Means user hasn't selected a specific game yet
- Should show game selection UI first

### `squadId: null, userId: <uid>`
- `selectedSquadId` is null in SquadState
- Either not set in ChatScreen OR
- SquadState was reset/reloaded

### `Cannot claim spot: squadId or userId is null`
- Guard clause in `claimSpot()` preventing execution
- Correct behavior - shouldn't try to claim without squad ID

### `PostgrestException (message: Cannot coerce the result to a single JSON object, code: PGRST116, details: The result contains 0 rows)`
- Happens when squad ID is set BUT
- No matching record exists in `squads` table
- `.single()` expects exactly 1 row, got 0

---

## Summary

**The Problem:**
Chat groups and squads are disconnected. Creating a chat group doesn't create a corresponding squad record, so when users try to create game lobbies, the squad doesn't exist in the database.

**The Root Cause:**
1. Code exists to create squads in `createGroup()` method
2. But it's likely failing silently OR not executing
3. No verification that squad was created successfully
4. No fallback or retry mechanism

**The Fix:**
1. Debug why squad creation is failing
2. Ensure squads are created atomically with chat groups
3. Backfill missing squads for existing groups
4. Add validation before allowing spot claims

**Long-term Improvement:**
Consider redesigning so game lobbies (squads) are separate entities that reference chat groups, allowing multiple concurrent lobbies per group.
