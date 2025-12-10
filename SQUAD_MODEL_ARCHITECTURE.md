# Squad Model Architecture - SquadSync

**Last Updated**: December 9, 2025  
**Status**: ✅ Clarified - Two distinct models serving different purposes

---

## Executive Summary

SquadSync uses **two separate Squad models** that serve **completely different purposes** in the application architecture. This is **intentional design**, not redundancy.

| Model | Purpose | Context | Database Focus |
|-------|---------|---------|----------------|
| **Squad** | Active gameplay state management | Domain/Repository layer | Core squad operations |
| **PublicSquad** | Squad discovery and social features | Discovery/UI layer | Public browsing metadata |

**Key Insight**: These models **do not convert between each other**. They query the same Supabase `squads` table but focus on different subsets of columns for their specific use cases.

---

## Model 1: Squad (Domain Entity)

**File**: `lib/domain/entities/squad.dart` (~200 lines)  
**Pattern**: Clean Architecture domain entity  
**Purpose**: Active gameplay state for squad CRUD operations

### Usage Context

**Layer**: Domain + Data  
**Used By**:
- **Data Sources**: `SquadRemoteDataSource`, `SquadLocalDataSource`
- **Repositories**: `SquadRepositoryImpl`
- **Use Cases**: `CreateSquad`, `JoinSquad`, `LeaveSquad`, `AssignSpot`, `StartSpotTimer`, `ProcessTimers`, `ManagePeacockQueue`
- **State Management**: `SquadState.userSquads` (Map<String, Squad>)
- **Notifiers**: `SquadNotifier` (via use cases)
- **Tests**: 168 usages across 15+ test files

### Fields (Gameplay-Focused)

```dart
class Squad {
  required String id;
  required String name;
  required List<String> memberUids;        // All squad members
  required String gameName;
  required int maxSpots;                   // Max spots for this game
  required String createdBy;
  required DateTime createdAt;
  
  // GAMEPLAY STATE (Core Focus)
  required List<String?> spots;            // Array-indexed spots [uid1, null, uid3, ...]
  required List<Map?> spotTimers;          // Array-indexed timers [{endTime: ...}, null, ...]
  required List<String> viewers;           // Users viewing but not in squad
  required Map<String, String> statuses;   // {uid: "ready" | "away" | "in-game"}
  required bool isActive;                  // Squad is currently active
  
  // OPTIONAL
  String? description;
  Map<String, dynamic>? settings;
}
```

### Database Mapping (Supabase)

Maps to `squads` table **core columns**:

| Squad Field | Supabase Column | Type | Purpose |
|-------------|-----------------|------|---------|
| `id` | `id` | TEXT PRIMARY KEY | Unique identifier |
| `name` | `name` | TEXT | Squad name |
| `memberUids` | `member_uids` | TEXT[] | All members |
| `gameName` | `game_name` | TEXT | Current game |
| `maxSpots` | `max_spots` | INTEGER | Max squad size |
| `createdBy` | `created_by` | TEXT (FK users) | Creator UID |
| `createdAt` | `created_at` | TIMESTAMPTZ | Creation time |
| `spots` | `squad_spots` | JSONB | **List format** for gameplay |
| `spotTimers` | `spot_timers` | JSONB | **Map converted to list** |
| `viewers` | `viewers` | TEXT[] | Viewer UIDs |
| `statuses` | `statuses` | JSONB | Member statuses |
| `isActive` | `is_active` | BOOLEAN | Active state |
| `description` | `description` | TEXT | Optional description |
| `settings` | `settings` | JSONB | Squad settings |

### Data Structure Rationale

**Why List-indexed spots/timers?**
- **Performance**: Direct array access by spot index `spots[0]`, `spots[1]`
- **Gameplay logic**: "Fill spot 3" means `spots[3] = userId`
- **Sequential operations**: Easy to iterate through all spots
- **Fixed size**: Spots array always has `maxSpots` length

### Code Example

```dart
// Creating a squad (use case layer)
final squad = Squad.create(
  name: 'CoD Warzone Squad',
  gameName: 'Call of Duty: Warzone',
  maxSpots: 4,
  createdBy: currentUserId,
);

// Assigning spot (repository operation)
await squadRepository.assignSpot(
  squadId: 'squad123',
  spotIndex: 2,        // Direct array index
  userId: 'user456',
);

// Result: squad.spots = [null, null, 'user456', null]
```

---

## Model 2: PublicSquad (Discovery Model)

**File**: `lib/models/public_squad.dart` (~200 lines)  
**Pattern**: Presentation layer model with Riverpod  
**Purpose**: Squad discovery, browsing, invite system, social features

### Usage Context

**Layer**: Presentation + UI  
**Used By**:
- **Notifiers**: `CurrentSquadNotifier` (real-time selected squad), `DiscoveryNotifier`
- **Screens**: `DiscoveryScreen`, `DiscoverySwipeScreen`, `SquadDetailScreen`
- **Widgets**: `SpotsLobbyBar`, discovery cards, squad preview cards
- **Providers**: `publicSquadsProvider`, `currentSquadProvider`
- **Features**: Squad browsing, invite codes, tags, bumping

### Fields (Discovery-Focused)

```dart
class PublicSquad {
  required String id;
  required String name;
  String? primaryGameId;                  // IGDB game ID
  String? primaryGameName;
  int? maxSpots;
  required String creatorUid;
  required DateTime createdAt;
  
  // DISCOVERY & SOCIAL (Core Focus)
  required bool isPublic;                 // Visible in discovery?
  String? inviteCode;                     // Shareable invite code
  required List<String> memberUids;
  required DateTime lastActivity;         // For sorting/ranking
  required Map<String, String?> spotClaims;      // Map-based claiming
  required Map<String, PeacockTimer> peacockTimers;  // Named timers
  required Map<String, String> userStatuses;
  required List<String> tags;             // ["casual", "competitive", "18+"]
  required bool lookingForMore;           // Active recruitment flag
  required String description;
  DateTime? bumpTimestamp;                // Last bump time for ranking
}
```

### Sub-Model: PeacockTimer

```dart
class PeacockTimer {
  required DateTime endTime;
  required bool isActive;
}
```

### Database Mapping (Supabase)

Maps to `squads` table **discovery/social columns**:

| PublicSquad Field | Supabase Column | Type | Purpose |
|-------------------|-----------------|------|---------|
| `id` | `id` | TEXT PRIMARY KEY | Unique identifier |
| `name` | `name` | TEXT | Squad name |
| `primaryGameId` | `primary_game_id` | TEXT | IGDB game ID |
| `primaryGameName` | `primary_game_name` | TEXT | Game name |
| `maxSpots` | `max_spots` | INTEGER | Max size |
| `creatorUid` | `created_by` | TEXT | Creator |
| `createdAt` | `created_at` | TIMESTAMPTZ | Created |
| `isPublic` | `is_public` | BOOLEAN | **Discovery visibility** |
| `inviteCode` | `invite_code` | TEXT | **Shareable code** |
| `memberUids` | `member_uids` | TEXT[] | Members |
| `lastActivity` | `last_activity` | TIMESTAMPTZ | **Activity tracking** |
| `spotClaims` | `spot_claims` | JSONB | **Map format** for claims |
| `peacockTimers` | `peacock_timers` | JSONB | **Named timers** |
| `userStatuses` | `user_statuses` | JSONB | Statuses |
| `tags` | `tags` | TEXT[] | **Discovery tags** |
| `lookingForMore` | `looking_for_more` | BOOLEAN | **Recruitment flag** |
| `description` | `description` | TEXT | Description |
| `bumpTimestamp` | `bump_timestamp` | TIMESTAMPTZ | **Bump ranking** |

### Data Structure Rationale

**Why Map-based spotClaims/peacockTimers?**
- **Flexibility**: Can claim spot by name ("spot_1", "tank", "healer")
- **Discovery UI**: Show available spots without fixed array size
- **Social features**: Named roles more user-friendly than indices
- **Real-time updates**: Easier to update single spot claim in map

### Code Example

```dart
// Discovering squads (notifier layer)
final publicSquads = ref.watch(publicSquadsProvider);

// User browses discovery feed
for (final squad in publicSquads) {
  print('${squad.name} - ${squad.tags.join(", ")}');
  print('Looking for ${squad.maxSpots! - squad.memberUids.length} more');
  print('Invite code: ${squad.inviteCode}');
}

// Claiming a spot via CurrentSquadNotifier
await currentSquadNotifier.claimSpot('spot_2');

// Result: squad.spotClaims = {'spot_1': 'user123', 'spot_2': 'user456'}
```

---

## Why Two Models? (Architectural Reasoning)

### Different Contexts, Different Needs

| Aspect | Squad (Gameplay) | PublicSquad (Discovery) |
|--------|------------------|-------------------------|
| **User flow** | Active gameplay session | Browsing/finding squads |
| **Data access** | Repository pattern (CRUD) | Real-time subscriptions |
| **State management** | Domain entities in SquadState | Riverpod AsyncNotifier |
| **Updates** | Use case operations | Direct Supabase updates |
| **Focus** | Performance, spot assignment | Social, discovery, invites |
| **Real-time** | Optional (state sync) | Required (live updates) |

### Separation of Concerns

1. **Domain Layer (Squad)**: Business logic for squad operations, game rules, spot management
2. **Presentation Layer (PublicSquad)**: UI concerns for discovery, social features, user engagement

### No Conversion Needed

**Key Insight**: These models **never convert between each other**. 

**User Journey**:
1. User browses discovery feed → sees `PublicSquad` objects
2. User joins via invite code → `DiscoveryScreen` calls backend
3. Backend creates/updates `squads` table row
4. **Separate query**: `SquadRepository.getSquad()` fetches as `Squad` entity
5. Gameplay begins with `Squad` model
6. Meanwhile, discovery feed still shows `PublicSquad` for that squad

**Both models coexist** pointing to same database row, but used in different contexts.

---

## Database Schema Analysis

### Single `squads` Table Strategy

**Current Design**: One Supabase table with **all columns** used by both models

**Pros**:
- Simple schema, no joins needed
- Both models can query same table
- Real-time subscriptions work for both

**Cons**:
- Mixing gameplay and discovery concerns in one table
- Large table with many columns (some unused by each model)

### Alternative: Split Tables (Not Recommended)

```sql
-- Core gameplay table
CREATE TABLE squads (
  id TEXT PRIMARY KEY,
  game_name TEXT,
  squad_spots JSONB,
  spot_timers JSONB,
  viewers TEXT[],
  statuses JSONB,
  is_active BOOLEAN
);

-- Discovery metadata table
CREATE TABLE squad_discovery (
  squad_id TEXT PRIMARY KEY REFERENCES squads(id),
  is_public BOOLEAN,
  invite_code TEXT UNIQUE,
  tags TEXT[],
  looking_for_more BOOLEAN,
  bump_timestamp TIMESTAMPTZ
);
```

**Why not split?**:
- Adds complexity (joins, foreign keys)
- Worse real-time performance (need 2 subscriptions)
- Current single-table design works well
- Both models need some shared fields anyway (name, memberUids)

---

## Usage Patterns

### When to Use Squad

Use `Squad` entity when:
- ✅ Creating a new squad (CreateSquad use case)
- ✅ Joining/leaving squad (repository operations)
- ✅ Assigning spots (spot index needed)
- ✅ Managing timers for gameplay
- ✅ Updating member statuses during game
- ✅ CRUD operations via repository pattern
- ✅ Testing domain logic

**Example**:
```dart
final createSquad = ref.read(createSquadProvider);
final squad = await createSquad.execute(
  name: 'Ranked Squad',
  gameName: 'Apex Legends',
  maxSpots: 3,
);
```

### When to Use PublicSquad

Use `PublicSquad` when:
- ✅ Displaying discovery feed
- ✅ Showing squad preview cards
- ✅ Joining via invite code
- ✅ Filtering by tags
- ✅ Bumping squad in discovery
- ✅ Tracking last activity
- ✅ Real-time updates to current squad
- ✅ Social features (invite sharing)

**Example**:
```dart
final currentSquad = ref.watch(currentSquadProvider);
if (currentSquad.value?.isPublic == true) {
  showInviteCode(currentSquad.value!.inviteCode);
}
```

---

## Testing Implications

### Squad Testing

Focus on **domain logic**:
- Squad creation validation
- Spot assignment rules
- Timer processing
- Member management
- Repository CRUD operations

**Test Files** (15+ files, 168 usages):
- `test/domain/entities/squad_test.dart`
- `test/domain/usecases/create_squad_test.dart`
- `test/domain/usecases/assign_spot_test.dart`
- `test/data/repositories/squad_repository_impl_test.dart`

### PublicSquad Testing

Focus on **discovery features**:
- Real-time subscription updates
- Invite code generation/validation
- Discovery filtering by tags
- Bump timestamp ranking
- Spot claiming via map keys

**Test Files**:
- Integration tests for discovery screens
- CurrentSquadNotifier tests
- PublicSquad model serialization tests

---

## Migration Notes

### From Firebase to Supabase

**Squad (Domain Entity)**:
- Firebase: `squads/{squadId}` collection
- Supabase: `squads` table with camelCase → snake_case conversion
- Conversion layer: `SquadRemoteDataSourceImpl._toEntityJson()`

**PublicSquad (Discovery Model)**:
- Firebase: Same `squads/{squadId}` collection (different fields)
- Supabase: Same `squads` table (different columns queried)
- Conversion layer: `CurrentSquadNotifier._squadFromSupabase()`

### Data Transformation

**Example: spot_timers**

Firebase (Firestore):
```json
{
  "spot_timers": [
    {"endTime": "2025-12-09T10:00:00Z", "active": true},
    null,
    {"endTime": "2025-12-09T11:00:00Z", "active": false}
  ]
}
```

Supabase (Squad entity):
```sql
spot_timers: {
  "0": {"endTime": "...", "active": true},
  "2": {"endTime": "...", "active": false}
}
-- Converted to List by _convertSpotTimersToList()
```

Supabase (PublicSquad):
```sql
peacock_timers: {
  "user123": {"endTime": "...", "isActive": true},
  "user456": {"endTime": "...", "isActive": false}
}
-- Used directly as Map<String, PeacockTimer>
```

---

## Future Considerations

### Potential Improvements

1. **Shared Base Class** (Low Priority)
   ```dart
   abstract class SquadBase {
     String id;
     String name;
     List<String> memberUids;
     // ... shared fields
   }
   
   class Squad extends SquadBase { /* gameplay fields */ }
   class PublicSquad extends SquadBase { /* discovery fields */ }
   ```
   **Pros**: Reduced duplication  
   **Cons**: Adds complexity, breaks freezed pattern

2. **Conversion Utilities** (Not Needed)
   - No use case for Squad ↔ PublicSquad conversion
   - Keep separate queries to database

3. **Database View** (Possible Enhancement)
   ```sql
   CREATE VIEW public_squads AS
   SELECT id, name, is_public, invite_code, tags, bump_timestamp
   FROM squads
   WHERE is_public = true;
   ```
   **Benefit**: Optimized discovery queries  
   **Cost**: More database complexity

---

## Summary

### Key Takeaways

1. ✅ **Two models are intentional design**, not redundancy
2. ✅ **Squad** = Domain entity for gameplay operations (repository pattern)
3. ✅ **PublicSquad** = Discovery model for browsing/social (real-time Riverpod)
4. ✅ Both query same `squads` table but focus on different columns
5. ✅ No conversion needed - separate contexts, separate queries
6. ✅ Architecture is clean and appropriate for use cases

### Recommendations

- ✅ **Keep both models** - they serve distinct purposes
- ✅ **Document clearly** - avoid future confusion (this file!)
- ⚠️ **Consider table split** - if performance issues arise (unlikely)
- ✅ **Add code comments** - reference this doc in model files

---

**Last Updated**: December 9, 2025  
**Analysis By**: AI Code Review (Anthropic Claude)  
**Status**: ✅ Architecture Validated - No Changes Needed
