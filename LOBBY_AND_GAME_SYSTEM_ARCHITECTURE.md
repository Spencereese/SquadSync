# SquadSync Lobby & Game System Architecture

**Complete Reference for AI-Assisted Development and System Improvements**

> **Last Updated**: December 16, 2025  
> **Purpose**: Comprehensive documentation of lobby management and game features for AI analysis and enhancement

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Principles](#architecture-principles)
3. [Core Entities & State](#core-entities--state)
4. [State Management (Riverpod)](#state-management-riverpod)
5. [Lobby System Deep Dive](#lobby-system-deep-dive)
6. [Game System Deep Dive](#game-system-deep-dive)
7. [Timer System](#timer-system)
8. [Peacock Queue System](#peacock-queue-system)
9. [Database Schema](#database-schema)
10. [Real-time Synchronization](#real-time-synchronization)
11. [UI Components](#ui-components)
12. [Data Flow Patterns](#data-flow-patterns)
13. [Key Workflows](#key-workflows)
14. [Known Issues & Technical Debt](#known-issues--technical-debt)
15. [Improvement Opportunities](#improvement-opportunities)

---

## System Overview

### High-Level Purpose
SquadSync is a **gaming lobby coordination app** that allows users to:
- **Create and join lobbies** for specific games
- **Claim spots** with timed countdowns (5-minute timers)
- **Join a "peacock queue"** when all spots are full
- **Discover games** via IGDB API integration
- **Track match history** and lobby stats
- **Coordinate with friends** via chat-integrated lobbies

### Technology Stack
- **Frontend**: Flutter with Riverpod 3.0 state management
- **Backend**: Supabase (PostgreSQL + Real-time + Storage)
- **Game Data**: IGDB API with caching layers
- **Timer Processing**: Server-side via Supabase pg_cron (runs every 30 seconds)
- **Offline Support**: SQLite local cache + JSON fallbacks

---

## Architecture Principles

### 1. Clean Architecture
```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  (Notifiers, Widgets, Screens)          │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Domain Layer                    │
│  (Entities, Repositories Interface)     │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Data Layer                      │
│  (Repository Impl, DataSources)         │
└─────────────────────────────────────────┘
```

### 2. Separation of Concerns
**Three Primary Notifiers** (post-refactoring):

| Notifier | Responsibilities | Lines of Code |
|----------|------------------|---------------|
| **LobbyNotifier** | Lobby lifecycle, spot management, member tracking | ~400 |
| **GameStateNotifier** | Game selection, IGDB integration, preferences | ~350 |
| **TimerManagementNotifier** | Spot timers, peacock timers, expiration | ~300 |

### 3. Offline-First Design
- **Primary Data Source**: Supabase (real-time)
- **Fallback Chain**: SQLite cache → Local JSON → User-friendly error
- **Sync Strategy**: Optimistic UI updates with server reconciliation

---

## Core Entities & State

### Lobby Entity
**File**: `lib/domain/entities/lobby.dart`

```dart
@freezed
class Lobby with _$Lobby {
  const factory Lobby({
    required String id,
    required String name,
    required List<String> memberUids,
    required String gameName,
    required int maxSpots,
    required String createdBy,
    required DateTime createdAt,
    required List<String?> spots,              // UIDs claiming spots (null = available)
    required List<Map<String, dynamic>?> spotTimers,  // Timer metadata per spot
    required List<String> viewers,             // Non-member viewers
    required Map<String, String> statuses,     // User status per member
    required bool isActive,
    String? description,
    Map<String, dynamic>? settings,
  }) = _Lobby;
}
```

**Key Properties**:
- `spots`: Array of UIDs (null = empty spot, `uid_calling` = user has timer)
- `spotTimers`: Array of timer objects `{expiresAt, duration, userId}`
- `statuses`: User readiness (`'Ready'`, `'Not Ready'`, `'Away'`)
- `memberUids`: Full lobby membership roster

### LobbyState Entity
**File**: `lib/domain/entities/lobby_state.dart`

```dart
@freezed
class LobbyState with _$LobbyState {
  const factory LobbyState({
    // Initialization
    required bool isInitialized,
    required bool isInitialDataLoaded,
    required String displayName,
    String? profileImage,

    // Spot Management (game-scoped)
    required Map<String, List<String?>> gameLobbySpots,          // {gameName: [uid1, uid2, ...]}
    required Map<String, List<Map<String, dynamic>?>> gameSpotTimers,  // {gameName: [{timer}, ...]}
    required Map<String, Map<String, String>> gameStatuses,      // {gameName: {uid: status}}
    required Map<String, String> globalStatuses,                 // {uid: global_status}

    // Peacock Queue
    required List<String> peacockQueue,                          // [uid1, uid2, ...]
    required Map<String, Map<String, dynamic>?> peacockTimers,   // {uid: {timer}}
    required Map<String, Duration> peacockTimerStates,           // {uid: remaining_duration}
    required Set<String> preferredPeacockGames,

    // Timer States (client-side tracking)
    required Map<String, Duration> spotTimerStates,              // {'spot_game_uid': remaining}

    // Current Lobby Context
    String? selectedLobbyId,
    Lobby? currentLobby,
    Map<String, dynamic>? currentLobbyData,
    Map<String, dynamic>? currentGame,

    // User Lobby Memberships
    required List<String> userLobbyIds,
    required Map<String, Lobby> userLobbies,                     // {lobbyId: Lobby}
    required List<String> lobbyMemberUids,
    required Map<String, String> memberDisplayNames,             // {uid: display_name}
    Map<String, String?>? memberProfileImages,

    // Game Data
    required List<Map<String, dynamic>> gameHistory,
    required Map<String, String?> preferredModes,
    required Set<String> mutedGames,
    required Set<String> hiddenGames,

    // Additional State
    required Map<String, bool> typing,
    required bool tiltEnabled,
    required bool hasNewLobbySpot,
    required bool hasUnreadMessages,
    required Map<String, Map<String, int>> dailyRatings,
    required Map<String, Map<String, int>> allTimeRatings,
    required DateTime lastSyncTimestamp,
  }) = _LobbyState;
}
```

**Critical State Properties**:
- `gameLobbySpots`: **Game-scoped spot assignment** (one game can have multiple spots claimed)
- `gameSpotTimers`: **Per-spot timer metadata** for expiration tracking
- `currentLobby`: **Active lobby context** (used for operations)
- `memberDisplayNames`: **Cached display names** to avoid repeated DB lookups

### Game Entity
**File**: `lib/domain/entities/game.dart`

```dart
@freezed
class Game with _$Game {
  const factory Game({
    required String name,
    required String slug,
    required int? igdbId,
    required String? coverUrl,
    required String? summary,
    required DateTime? firstReleaseDate,
    required List<String> genres,
    required List<String> platforms,
    required int? maxSpots,
    required bool isCached,
    required DateTime? cachedAt,
  }) = _Game;

  factory Game.fromIgdb(Map<String, dynamic> data) {
    // Normalizes IGDB API response
    final rawCover = data['cover']?['url'];
    final processedCover = rawCover != null
        ? 'https:${rawCover.replaceAll('t_thumb', 't_cover_big')}'
        : null;
    return Game(...);
  }

  factory Game.fromCache(Map<String, dynamic> data) {
    // Loads from SQLite or local JSON
  }
}
```

**Key Features**:
- **IGDB Integration**: `fromIgdb()` factory normalizes API responses
- **Cover Art Optimization**: Automatically upgrades thumbnail URLs to `t_cover_big`
- **Cache Metadata**: `isCached` and `cachedAt` track offline availability

---

## State Management (Riverpod)

### Provider Architecture

```dart
// Lobby Management
final lobbyNotifierProvider = AutoDisposeAsyncNotifierProvider<LobbyNotifier, LobbyState>(
  LobbyNotifier.new,
);

// Game Selection
final gameStateNotifierProvider = AutoDisposeAsyncNotifierProvider<GameStateNotifier, GameSelectionState>(
  GameStateNotifier.new,
);

// Timer Management
final timerManagementNotifierProvider = AutoDisposeAsyncNotifierProvider<TimerManagementNotifier, TimerManagementState>(
  TimerManagementNotifier.new,
);
```

### Notifier Responsibilities

#### LobbyNotifier
**File**: `lib/presentation/notifiers/lobby_notifier.dart`

**Core Methods**:
```dart
class LobbyNotifier extends AutoDisposeAsyncNotifier<LobbyState> {
  // Lobby Lifecycle
  Future<String> createLobby({required String chatGroupId, required String gameName, required int maxSpots, bool isPublic = false});
  Future<void> joinLobby(String squadId, String userId);
  Future<void> leaveSquad(String squadId, String userId);
  
  // Spot Management
  Future<void> claimSpot(String gameName, int spotIndex);
  Future<void> lockSpot(String gameName, int spotIndex);
  Future<void> removeSpot(String gameName, int spotIndex);
  
  // Peacock Queue
  Future<void> addToPeacockQueue(String userId, String gameName);
  Future<void> removeFromPeacockQueue(String userId);
  
  // Member Management
  Future<void> updateMemberStatus(String squadId, String userId, String status);
  Future<void> updateLobbyMembers(List<String> memberUids);
  
  // Match History
  Future<void> recordWin(String lobbyId);
  Future<void> recordLoss(String lobbyId);
  Future<void> recordDraw(String lobbyId);
  
  // Helpers
  String getDisplayNameForUid(String uid);
  List<String?> getSquadSpots(String gameName);
}
```

**Delegation Pattern**:
```dart
// Timer operations delegated to TimerManagementNotifier
Future<void> claimSpot(String gameName, int spotIndex) async {
  // 1. Assign spot via repository
  await _repository.assignSpot(squadId, spotIndex, userId);
  
  // 2. Delegate timer start to TimerManagementNotifier
  final timerNotifier = ref.read(timerManagementNotifierProvider.notifier);
  await timerNotifier.startSpotTimer(squadId, gameName, spotIndex, userId, Duration(minutes: 5));
  
  // 3. Reload state
  state = await AsyncValue.guard(() => _repository.loadLobbyState());
}
```

#### GameStateNotifier
**File**: `lib/presentation/notifiers/game_state_notifier.dart`

**Core Methods**:
```dart
class GameStateNotifier extends AutoDisposeAsyncNotifier<GameSelectionState> {
  // Game Selection
  Future<void> setCurrentGame(Map<String, dynamic>? game);
  
  // IGDB Integration
  Future<List<Game>> searchGames(String query, {int limit = 10});
  Future<List<Game>> getPopularGames();
  Future<Game?> getGameDetails(int igdbId);
  
  // Offline Support
  Future<List<Game>> getCachedGames(String query);
  Future<List<Game>> getOfflineGames(String query, {int limit = 10});
  
  // User Preferences
  Future<void> muteGame(String gameName);
  Future<void> unmuteGame(String gameName);
  Future<void> hideGame(String gameName);
  Future<void> setPreferredMode(String gameName, String mode);
  
  // Game History
  Future<void> refreshGameData();
  List<Map<String, dynamic>> getLobbiesForGame(String gameName);
}
```

**IGDB Fallback Chain**:
```dart
Future<List<Game>> searchGames(String query) async {
  try {
    // 1. Try IGDB API (primary)
    return await _repository.fetchGames(query);
  } catch (e) {
    // 2. Try SQLite cache
    final cached = await _repository.getCachedGames(query);
    if (cached.isNotEmpty) return cached;
    
    // 3. Final fallback: Local JSON (assets/popular_games.json)
    return await _repository.getOfflineGames(query);
  }
}
```

#### TimerManagementNotifier
**File**: `lib/presentation/notifiers/timer_management_notifier.dart`

**Core Methods**:
```dart
class TimerManagementNotifier extends AutoDisposeAsyncNotifier<TimerManagementState> {
  // Spot Timers
  Future<void> startSpotTimer(String lobbyId, String gameName, int spotIndex, String userId, Duration duration);
  Future<void> stopSpotTimer(String gameName, String userId);
  Future<void> resetTimersForGame(String gameName);
  
  // Peacock Timers
  Future<void> startPeacockTimer(String userId, Duration duration);
  Future<void> stopPeacockTimer(String userId);
  
  // Timer Processing (hybrid client-server)
  Future<void> processExpiredTimers();
  Future<void> cleanupExpiredPeacockTimers();
  
  // Real-time Subscriptions
  void subscribeToLobbyTimers(String lobbyId);
  void subscribeToPeacockTimers();
  
  // Timer State Queries
  Duration? getSpotTimerRemaining(String gameName, String userId);
  Duration? getPeacockTimerRemaining(String userId);
  bool hasActiveTimer(String gameName, String userId);
  Map<String, Duration> getActiveTimersForGame(String gameName);
}
```

**Timer State Structure**:
```dart
@freezed
class TimerManagementState with _$TimerManagementState {
  const factory TimerManagementState({
    required Map<String, Duration> spotTimerStates,        // {'spot_game_uid': remaining}
    required Map<String, Duration> peacockTimerStates,     // {'uid': remaining}
    required Map<String, List<Map<String, dynamic>?>> gameSpotTimers,
    required Map<String, Map<String, dynamic>?> peacockTimers,
    required bool isProcessing,
  }) = _TimerManagementState;
}
```

---

## Lobby System Deep Dive

### Lobby Lifecycle

#### 1. Lobby Creation
**Entry Points**:
- Chat screen: Create lobby for chat group
- Discovery screen: Create public lobby
- Direct API: `createLobby()` or `createPublicLobby()`

**Flow**:
```dart
// From chat screen with chat group context
await ref.read(lobbyNotifierProvider.notifier).createLobby(
  chatGroupId: 'group_123',
  gameName: 'Call of Duty',
  maxSpots: 4,
  isPublic: false,
);

// Creates:
// 1. Lobby record in Supabase 'lobbies' table
// 2. Links to chat_group via chat_group_id
// 3. Sends notifications to chat group members
// 4. Initializes spot array [null, null, null, null]
// 5. Returns lobbyId
```

**Database Operations**:
```sql
-- Insert lobby
INSERT INTO lobbies (id, name, created_by, settings, chat_group_id, member_uids, lobby_spots, max_spots)
VALUES ('lobby_123', 'COD Lobby', 'uid_user1', '{}', 'group_123', ARRAY['uid_user1'], ARRAY[]::text[], 4);

-- Send notifications
INSERT INTO notifications (id, user_id, title, body, data)
VALUES (...) FOR EACH member_uid;
```

#### 2. Joining a Lobby
**Entry Points**:
- Discovery screen: Browse public lobbies
- Invite link: Deep link (`codsquadapp://join/{lobbyId}`)
- Direct: `joinLobby(lobbyId, userId)`

**Flow**:
```dart
await ref.read(lobbyNotifierProvider.notifier).joinLobby(lobbyId, userId);

// Updates:
// 1. Adds userId to lobby.member_uids array
// 2. Updates lobby.last_activity timestamp
// 3. Sends join notification to existing members
// 4. Reloads user's lobby list
```

#### 3. Leaving a Lobby
```dart
await ref.read(lobbyNotifierProvider.notifier).leaveSquad(lobbyId, userId);

// Cleanup:
// 1. Removes userId from member_uids
// 2. Clears any claimed spots by this user
// 3. Stops any active timers for this user
// 4. Removes from peacock queue if present
```

### Spot Management System

#### Spot States
| State | Description | Database Value |
|-------|-------------|----------------|
| **Available** | No one has claimed this spot | `null` |
| **Calling** | User has claimed with 5-min timer | `uid_calling` |
| **Ready** | User locked in, timer cancelled | `uid` (plain) |

#### Claiming a Spot
**User Action**: Tap empty spot or "Call Spot" button

**Flow**:
```dart
await lobbyNotifier.claimSpot('Call of Duty', spotIndex: 2);

// 1. Repository: Update database
await _repository.assignSpot(lobbyId, spotIndex, userId);
// SQL: UPDATE lobbies SET lobby_spots[2] = 'uid_user1_calling' WHERE id = lobbyId

// 2. TimerNotifier: Start 5-minute countdown
await timerNotifier.startSpotTimer(lobbyId, 'Call of Duty', 2, userId, Duration(minutes: 5));
// Creates squad_timers record with expires_at = NOW() + 5 minutes

// 3. NotificationService: Notify other members
await NotificationService.sendNotificationToUsers(
  title: 'Spot Claimed',
  body: '$displayName claimed spot 2 for Call of Duty',
  recipientUids: otherMemberUids,
);

// 4. Reload UI state
state = await AsyncValue.guard(() => _repository.loadLobbyState());
```

#### Locking a Spot (Confirming Readiness)
**User Action**: Tap "Lock" or "Ready" button

**Flow**:
```dart
await lobbyNotifier.lockSpot('Call of Duty', spotIndex: 2);

// 1. Stop timer
await timerNotifier.stopSpotTimer('Call of Duty', userId);
// Deletes squad_timers record

// 2. Update spot to "Ready" status
await _repository.updateMemberStatus(lobbyId, userId, 'Ready');
// Updates lobby.statuses map

// 3. Remove "_calling" suffix from spot
// SQL: UPDATE lobbies SET lobby_spots[2] = 'uid_user1' WHERE id = lobbyId
```

#### Removing a Spot
**User Action**: Tap "X" or "Leave Spot" button

**Flow**:
```dart
await lobbyNotifier.removeSpot('Call of Duty', spotIndex: 2);

// 1. Clear spot assignment
await _repository.assignSpot(lobbyId, spotIndex, null);
// SQL: UPDATE lobbies SET lobby_spots[2] = NULL WHERE id = lobbyId

// 2. Cancel timer if user owns this spot
if (spots[spotIndex] == userId || spots[spotIndex] == '${userId}_calling') {
  await timerNotifier.stopSpotTimer('Call of Duty', userId);
}

// 3. Check peacock queue for next player
// Automatically handled by server-side pg_cron
```

### Game-Scoped Data
**Critical Design Pattern**: Lobbies are **game-scoped**, meaning:
- One lobby can support **multiple games** simultaneously
- Each game has its **own spot array** (`gameLobbySpots[gameName]`)
- Users can claim spots in **different games** within the same lobby

**Example State**:
```dart
LobbyState(
  selectedLobbyId: 'lobby_123',
  gameLobbySpots: {
    'Call of Duty': ['uid_user1', 'uid_user2_calling', null, null],
    'Fortnite': ['uid_user3', null, null, null, null],
    'Apex Legends': [null, null, null],
  },
  gameSpotTimers: {
    'Call of Duty': [null, {expiresAt: '...', userId: 'uid_user2'}, null, null],
    'Fortnite': [null, null, null, null, null],
  },
)
```

---

## Game System Deep Dive

### Game Discovery

#### IGDB API Integration
**Service**: `GameRemoteDataSourceImpl` (`lib/data/datasources/game_remote_datasource.dart`)

**Authentication**:
```dart
final IgdbAuthService authService;  // Loads from .env file
final clientId = await authService.getClientId();        // IGDB_CLIENT_ID
final clientSecret = await authService.getClientSecret(); // IGDB_CLIENT_SECRET
```

**Search Flow**:
```dart
// 1. User types in search bar
final query = 'call of duty';

// 2. GameNotifier searches IGDB
final result = await gameNotifier.searchGames(query);

// 3. API request with Dio + caching
_dio.post(
  'https://api.igdb.com/v4/games',
  data: '''
    search "$query";
    fields name, slug, cover.url, summary, first_release_date, genres.name, platforms.name;
    where version_parent = null & category = 0;
    limit 10;
  ''',
  options: Options(headers: {
    'Client-ID': clientId,
    'Authorization': 'Bearer $accessToken',
  }).copyWith(policy: CachePolicy.forceCache, maxStale: Duration(days: 7)),
);

// 4. Response cached in Hive for 7 days
// 5. Games normalized via Game.fromIgdb() factory
// 6. Duplicates removed by slug
// 7. Cached in SQLite for offline access
```

**Popular Games**:
```dart
// Fetches top 20 popular games (by IGDB rating)
final popularGames = await gameNotifier.loadPopularGames();

// SQL: SELECT * FROM games ORDER BY rating DESC LIMIT 20
```

#### Offline Game Support
**Three-Layer Fallback**:

1. **IGDB API** (Primary)
   - Live data, always up-to-date
   - Requires internet connection
   - Rate limited (4 requests/second)

2. **SQLite Cache** (Secondary)
   - Last 1000 searched games cached locally
   - 7-day cache expiration
   - Fast local queries

3. **Local JSON** (Tertiary)
   - `assets/popular_games.json` (100 pre-loaded games)
   - Always available offline
   - Manually curated for common games

**Cache Implementation**:
```dart
Future<List<Game>> searchGames(String query) async {
  try {
    // Try IGDB
    final games = await _repository.fetchGames(query);
    await _repository.cacheGamesLocally(query, games); // Save to SQLite
    return games;
  } catch (e) {
    // Try SQLite cache
    final cached = await _repository.getCachedGames(query);
    if (cached.isNotEmpty) return cached;
    
    // Fallback to local JSON
    final offline = await _repository.getOfflineGames(query);
    return offline;
  }
}
```

### Game Selection & Theming

#### Dynamic Theme System
**File**: `lib/presentation/controllers/game_theme_controller.dart`

**Flow**:
```dart
// 1. User selects game
await gameNotifier.setCurrentGame(game);

// 2. GameThemeController extracts dominant color from cover art
final dominantColor = await ColorScheme.fromImageProvider(
  provider: NetworkImage(game.coverUrl!),
);

// 3. AppTheme updates with game-specific color
ref.read(appThemeProvider.notifier).setColorSeed(dominantColor.primary);

// 4. All widgets using Theme.of(context) automatically update
```

**Example**:
- **Call of Duty** cover → Dark green/military theme
- **Fortnite** cover → Bright purple/blue theme
- **Cyberpunk 2077** cover → Neon yellow/cyan theme

#### Game History
**Tracked Automatically**:
```dart
Future<void> setCurrentGame(Map<String, dynamic>? game) async {
  state = AsyncData(currentState.copyWith(currentGame: game));
  
  if (game != null) {
    // Add to history (max 20 games)
    await _addToGameHistory(game);
  }
}
```

**Stored In**:
- Supabase `users.game_history` (JSONB array)
- Local SQLite `game_history` table

---

## Timer System

### Architecture

#### Hybrid Client-Server Model
**Why Hybrid?**
- **Client-side**: Smooth UI countdown (no network lag)
- **Server-side**: Authoritative expiration (prevents cheating)

**Components**:
1. **Client Timer Service** (`lib/services/timer_service.dart`)
   - Dart `Timer.periodic()` for UI countdown
   - Updates every 1 second
   - Persists to SQLite for app restart recovery

2. **Server pg_cron** (`lib/services/SUPABASE_TIMER_CRON.sql`)
   - PostgreSQL cron job runs every 30 seconds
   - Processes expired timers via `process_expired_timers()`
   - Frees spots, assigns peacock queue

### Server-Side Timer Processing

#### pg_cron Setup
```sql
-- Enable extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule timer processor (every 30 seconds)
SELECT cron.schedule(
  'process-lobby-timers',
  '*/30 * * * * *',  -- Every 30 seconds
  $$SELECT process_expired_timers()$$
);

-- Also schedule peacock queue cleanup
SELECT cron.schedule(
  'process-peacock-queue',
  '*/30 * * * * *',
  $$SELECT process_expired_queue()$$
);
```

#### Expiration Logic
**Function**: `process_expired_timers()`

```sql
CREATE OR REPLACE FUNCTION process_expired_timers()
RETURNS void AS $$
DECLARE
    expired_timer RECORD;
    next_in_queue RECORD;
BEGIN
    -- Find all expired timers
    FOR expired_timer IN 
        SELECT * FROM squad_timers 
        WHERE expires_at <= NOW()
    LOOP
        -- 1. Free the spot
        UPDATE squad_spots 
        SET occupied_by_uid = NULL, status = 'available'
        WHERE lobby_id = expired_timer.lobby_id 
          AND spot_index = expired_timer.spot_index;
        
        -- 2. Check peacock queue
        SELECT * INTO next_in_queue
        FROM peacock_queue
        WHERE lobby_id = expired_timer.lobby_id
          AND game_name = expired_timer.game_name
        ORDER BY position ASC
        LIMIT 1;
        
        -- 3. Assign to next in queue if exists
        IF FOUND THEN
            UPDATE squad_spots
            SET occupied_by_uid = next_in_queue.user_uid || '_calling',
                status = 'calling'
            WHERE lobby_id = expired_timer.lobby_id
              AND spot_index = expired_timer.spot_index;
            
            -- Start new timer for queued user
            INSERT INTO squad_timers (lobby_id, game_name, spot_index, claimed_by_uid, timer_duration, expires_at)
            VALUES (expired_timer.lobby_id, expired_timer.game_name, expired_timer.spot_index, 
                    next_in_queue.user_uid, 300, NOW() + INTERVAL '5 minutes');
            
            -- Send notification
            INSERT INTO peacock_notifications (user_uid, lobby_id, game_name, spot_index, title, body, data)
            VALUES (next_in_queue.user_uid, expired_timer.lobby_id, expired_timer.game_name, expired_timer.spot_index,
                    'Spot Available!', 'Your peacock spot is ready', '{"type": "spot_assigned"}');
            
            -- Remove from queue
            DELETE FROM peacock_queue WHERE id = next_in_queue.id;
        END IF;
        
        -- 4. Delete expired timer record
        DELETE FROM squad_timers WHERE id = expired_timer.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
```

### Client-Side Timer Management

#### Timer Service
**File**: `lib/services/timer_service.dart`

**Key Features**:
- Periodic ticks every 1 second
- Local state updates
- Persistence to SQLite
- Expiration callbacks

```dart
class TimerServiceNotifier extends StateNotifier<TimerServiceState> {
  final Map<String, Timer> _activeTimers = {};
  final Map<String, DateTime> _expirationTimes = {};
  
  Future<void> startSpotTimer(String gameName, String userId, Duration duration) async {
    final key = 'spot_${gameName}_$userId';
    final expiresAt = DateTime.now().add(duration);
    
    // Store expiration
    _expirationTimes[key] = expiresAt;
    await _persistTimer(key, expiresAt);
    
    // Start periodic timer
    _activeTimers[key] = Timer.periodic(Duration(seconds: 1), (timer) {
      final remaining = expiresAt.difference(DateTime.now());
      
      if (remaining.isNegative) {
        timer.cancel();
        _onTimerExpire(key);
      } else {
        _updateTimerState(key, remaining);
      }
    });
  }
  
  void _onTimerExpire(String key) {
    // Call expiration handler
    if (key.startsWith('spot_')) {
      _onSpotTimerExpire(key);
    }
    
    // Cleanup
    _activeTimers.remove(key);
    _expirationTimes.remove(key);
    _removePersistedTimer(key);
  }
}
```

#### Recovery After App Restart
```dart
Future<void> restorePersistedTimers() async {
  final timers = await _sqliteHelper.getActiveTimers();
  
  for (final timer in timers) {
    final expiresAt = DateTime.parse(timer['expires_at']);
    final remaining = expiresAt.difference(DateTime.now());
    
    if (remaining.isNegative) {
      // Already expired, trigger immediately
      _onTimerExpire(timer['key']);
    } else {
      // Restart timer with remaining time
      await startTimer(timer['key'], remaining);
    }
  }
}
```

---

## Peacock Queue System

### Concept
**"Peacocking"** = Showing off that you're ready to play when all spots are full

**User Flow**:
1. User joins lobby but all spots taken
2. User taps "Join Peacock Queue"
3. Timer starts (1 hour default)
4. When spot opens, user gets **priority assignment**
5. Notification sent: "Your spot is ready!"

### Queue Management

#### Adding to Queue
```dart
await lobbyNotifier.addToPeacockQueue(userId, gameName);

// Database:
INSERT INTO peacock_queue (lobby_id, game_name, user_uid, position, expires_at)
VALUES ('lobby_123', 'Call of Duty', 'uid_user1', 1, NOW() + INTERVAL '1 hour');
```

#### Queue Position Calculation
```sql
-- Position determined by joined_at timestamp
SELECT user_uid, position
FROM peacock_queue
WHERE lobby_id = 'lobby_123' AND game_name = 'Call of Duty'
ORDER BY joined_at ASC;
```

#### Spot Assignment from Queue
**Triggered by**: `process_expired_timers()` when spot becomes available

```sql
-- Get next in queue
SELECT * FROM peacock_queue
WHERE lobby_id = ? AND game_name = ?
ORDER BY position ASC
LIMIT 1;

-- Assign spot
UPDATE squad_spots
SET occupied_by_uid = next_user_uid || '_calling', status = 'calling'
WHERE lobby_id = ? AND spot_index = ?;

-- Start their timer
INSERT INTO squad_timers (...);

-- Send notification
INSERT INTO peacock_notifications (...);

-- Remove from queue
DELETE FROM peacock_queue WHERE id = next_queue_id;
```

#### Queue Expiration
**Function**: `process_expired_queue()`

```sql
CREATE OR REPLACE FUNCTION process_expired_queue()
RETURNS void AS $$
BEGIN
    -- Remove expired queue entries
    DELETE FROM peacock_queue
    WHERE expires_at <= NOW();
    
    RAISE NOTICE 'Cleaned up % expired peacock entries', FOUND;
END;
$$ LANGUAGE plpgsql;
```

### Peacock Notifications
**Table**: `peacock_notifications`

**Flow**:
1. Server creates notification record when spot assigned
2. Flutter app polls or receives real-time update
3. `NotificationService` sends push notification
4. User taps notification → Deep link to lobby

```dart
// Notification data structure
{
  "type": "spot_assigned",
  "lobby_id": "lobby_123",
  "game_name": "Call of Duty",
  "spot_index": 2,
  "expires_at": "2025-12-16T15:30:00Z"
}
```

---

## Database Schema

### Core Tables

#### lobbies
```sql
CREATE TABLE lobbies (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_by TEXT NOT NULL REFERENCES users(uid),
    game_focus TEXT,                      -- Primary game (optional)
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    is_public BOOLEAN DEFAULT TRUE,
    chat_group_id TEXT REFERENCES chat_groups(id),
    member_uids TEXT[],
    viewers TEXT[],
    max_spots INTEGER DEFAULT 8,
    spot_timers JSONB DEFAULT '{}',
    statuses JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT TRUE,
    description TEXT,
    lobby_spots TEXT[],                   -- Array of UIDs or NULL
    invite_code TEXT,
    last_activity TIMESTAMPTZ
);
```

#### squad_spots
```sql
CREATE TABLE squad_spots (
    lobby_id TEXT NOT NULL REFERENCES lobbies(id) ON DELETE CASCADE,
    game_name TEXT NOT NULL,
    spot_index INTEGER NOT NULL,
    occupied_by_uid TEXT REFERENCES users(uid),
    status TEXT DEFAULT 'available',      -- 'available', 'claimed', 'calling'
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY(lobby_id, game_name, spot_index)
);
```

#### squad_timers
```sql
CREATE TABLE squad_timers (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    lobby_id TEXT NOT NULL REFERENCES lobbies(id) ON DELETE CASCADE,
    game_name TEXT NOT NULL,
    spot_index INTEGER NOT NULL,
    claimed_by_uid TEXT NOT NULL REFERENCES users(uid),
    timer_duration INTEGER NOT NULL,      -- seconds
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(lobby_id, game_name, spot_index)
);

-- Index for efficient expiration queries
CREATE INDEX idx_squad_timers_expires ON squad_timers(expires_at);
```

#### peacock_queue
```sql
CREATE TABLE peacock_queue (
    id TEXT PRIMARY KEY DEFAULT uuid_generate_v4()::text,
    lobby_id TEXT NOT NULL REFERENCES lobbies(id) ON DELETE CASCADE,
    game_name TEXT NOT NULL,
    user_uid TEXT NOT NULL REFERENCES users(uid),
    position INTEGER NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    UNIQUE(lobby_id, game_name, user_uid)
);

CREATE INDEX idx_peacock_queue_lobby ON peacock_queue(lobby_id, game_name, position);
CREATE INDEX idx_peacock_queue_expires ON peacock_queue(expires_at);
```

#### match_history
```sql
CREATE TABLE match_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    lobby_id TEXT NOT NULL REFERENCES lobbies(id),
    game_name TEXT NOT NULL,
    result TEXT NOT NULL,                 -- 'win', 'loss', 'draw'
    player_uids TEXT[] NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by TEXT NOT NULL REFERENCES users(uid)
);
```

### Indexes & Constraints
```sql
-- Lobby lookups
CREATE INDEX idx_lobbies_chat_group ON lobbies(chat_group_id);
CREATE INDEX idx_lobbies_invite_code ON lobbies(invite_code);
CREATE INDEX idx_lobbies_is_public ON lobbies(is_public) WHERE is_public = TRUE;

-- Member queries
CREATE INDEX idx_lobbies_member_uids ON lobbies USING GIN(member_uids);

-- Match history
CREATE INDEX idx_match_history_lobby ON match_history(lobby_id);
CREATE INDEX idx_match_history_game ON match_history(game_name);
```

---

## Real-time Synchronization

### Supabase Realtime Channels

#### Lobby Updates
```dart
// Subscribe to specific lobby
final subscription = supabase
    .from('lobbies')
    .stream(primaryKey: ['id'])
    .eq('id', lobbyId)
    .listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty) {
        final lobbyData = data.first;
        // Update LobbyState with new data
        _updateLobbyFromRealtime(lobbyData);
      }
    });
```

#### Spot Changes
```dart
// Watch squad_spots for this lobby
final spotStream = supabase
    .from('squad_spots')
    .stream(primaryKey: ['lobby_id', 'game_name', 'spot_index'])
    .eq('lobby_id', lobbyId)
    .listen((spots) {
      // Update gameLobbySpots map
      _updateSpotsFromRealtime(spots);
    });
```

#### Timer Updates
```dart
// Watch active timers
final timerStream = supabase
    .from('squad_timers')
    .stream(primaryKey: ['id'])
    .eq('lobby_id', lobbyId)
    .listen((timers) {
      // Update gameSpotTimers map
      _updateTimersFromRealtime(timers);
    });
```

### Conflict Resolution
**Strategy**: Last-write-wins with server authority

```dart
Future<void> claimSpot(String gameName, int spotIndex) async {
  // 1. Optimistic UI update
  _updateLocalState(gameName, spotIndex, userId);
  
  try {
    // 2. Server update
    await _repository.assignSpot(lobbyId, spotIndex, userId);
    
    // 3. Realtime stream will confirm or correct
  } catch (e) {
    // 4. Rollback on error
    _revertLocalState(gameName, spotIndex);
    _showError('Spot claimed by someone else!');
  }
}
```

---

## UI Components

### Key Widgets

#### LobbyTabScreen
**File**: `lib/screens/lobby_tab_screen.dart`

**Modes**:
1. **Dashboard**: Shows user's active lobbies
2. **Full Interface**: Shows lobby with game-specific spots

```dart
@override
Widget build(BuildContext context) {
  return squadAsync.when(
    data: (squadState) {
      if (widget.gameName != null) {
        return _buildFullSquadInterface(context, squadState);
      }
      if (squadState.selectedLobbyId == null) {
        return _buildDashboardInterface(context, squadState, ref);
      }
      return _buildDashboardInterface(context, squadState, ref);
    },
    loading: () => CircularProgressIndicator(),
    error: (error, stack) => ErrorWidget(error),
  );
}
```

#### LobbyGrid
**File**: `lib/lobbies_tab/widgets/lobby_grid.dart`

**Displays**:
- Spot cards (4x2 or 2x2 grid)
- User avatars in claimed spots
- Timer countdown overlays
- "Call" button for empty spots
- Status indicators (Ready, Calling, Available)

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1.2,
  ),
  itemCount: maxSpots,
  itemBuilder: (context, index) {
    final spotUid = spots[index];
    final timer = spotTimers[index];
    
    return SpotCard(
      spotIndex: index,
      occupiedBy: spotUid,
      timer: timer,
      onTap: () => _handleSpotTap(index),
    );
  },
);
```

#### GameSelectionWidget
**File**: `lib/widgets/game_selection_widget.dart`

**Features**:
- Popular games grid (horizontal scroll)
- IGDB search button
- Game tile with cover art
- Multi-select mode for onboarding
- Primary game designation

```dart
// Show popular games
GameTile.grid(
  game: popularGames[index],
  onTap: () => _selectGame(game),
  isSelected: selectedGame?.igdbId == game.igdbId,
);

// Search button
ElevatedButton.icon(
  icon: Icon(Icons.search),
  label: Text('Search IGDB'),
  onPressed: () async {
    final game = await GameSearchDelegate.show(context, ref: ref);
    if (game != null) _selectGame(game);
  },
);
```

#### PeacockQueuePage
**File**: `lib/lobbies_tab/lobby_queue_page.dart`

**Displays**:
- Queue position (1st, 2nd, 3rd...)
- Estimated wait time
- Timer until queue expires
- Leave queue button

```dart
ListView.builder(
  itemCount: peacockQueue.length,
  itemBuilder: (context, index) {
    final uid = peacockQueue[index];
    final displayName = getDisplayNameForUid(uid);
    
    return ListTile(
      leading: CircleAvatar(child: Text('${index + 1}')),
      title: Text(displayName),
      subtitle: Text('Position: ${index + 1}'),
      trailing: PeacockTimerDisplay(player: uid),
    );
  },
);
```

---

## Data Flow Patterns

### Spot Claiming Flow (Complete)
```
[User Taps Empty Spot]
        ↓
[LobbyGrid Widget]
        ↓
[lobbyNotifier.claimSpot(gameName, spotIndex)]
        ↓
┌───────────────────────────────────────────┐
│ LobbyNotifier                             │
│  1. Create lobby if none selected        │
│  2. Call repository.assignSpot()          │
│  3. Delegate to TimerManagementNotifier   │
│  4. Send notifications                    │
│  5. Reload state                          │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ LobbyRepositoryImpl                       │
│  1. Update Supabase lobbies table         │
│  2. Update squad_spots table              │
│  3. Track event in analytics              │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ Supabase Database                         │
│  UPDATE lobbies                           │
│    SET lobby_spots[spotIndex] =           │
│        'uid_user1_calling'                │
│  INSERT INTO squad_timers                 │
│    (lobby_id, spot_index, expires_at)    │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ TimerManagementNotifier                   │
│  1. Start client-side timer               │
│  2. Subscribe to server timer updates     │
│  3. Update spotTimerStates map            │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ TimerService                              │
│  1. Create Timer.periodic (1s intervals)  │
│  2. Update UI countdown                   │
│  3. Persist to SQLite                     │
│  4. Trigger callback on expiration        │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ Server pg_cron (every 30s)                │
│  1. Run process_expired_timers()          │
│  2. Find expired records                  │
│  3. Free spot if timer elapsed            │
│  4. Assign to peacock queue if present    │
│  5. Send notification                     │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ Supabase Realtime                         │
│  1. Broadcast spot change                 │
│  2. All subscribed clients receive update │
│  3. LobbyNotifier updates state           │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ UI Rebuild (Consumer widgets)             │
│  1. LobbyGrid re-renders spots            │
│  2. Timer displays update countdown       │
│  3. User sees new state                   │
└───────────────────────────────────────────┘
```

### Game Selection Flow
```
[User Opens Game Selection]
        ↓
[GameSelectionWidget]
        ↓
[gameNotifier.loadPopularGames()]
        ↓
┌───────────────────────────────────────────┐
│ GameNotifier                              │
│  1. Check if games already loaded         │
│  2. Call repository.getPopularGames()     │
│  3. Cache results in state                │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ GameRepository                            │
│  1. Try IGDB API                          │
│  2. Fallback to SQLite cache              │
│  3. Final fallback to local JSON          │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ GameRemoteDataSource (IGDB)              │
│  1. Authenticate with IGDB                │
│  2. POST to /v4/games endpoint            │
│  3. Parse response via Game.fromIgdb()    │
│  4. Cache in Hive (7-day TTL)             │
└───────────┬───────────────────────────────┘
            ↓
[User Selects Game]
        ↓
[gameNotifier.setCurrentGame(game)]
        ↓
┌───────────────────────────────────────────┐
│ GameStateNotifier                         │
│  1. Update currentGame in state           │
│  2. Add to game history                   │
│  3. Sync with LobbyNotifier               │
└───────────┬───────────────────────────────┘
            ↓
┌───────────────────────────────────────────┐
│ GameThemeController                       │
│  1. Extract dominant color from cover     │
│  2. Update app theme seed color           │
│  3. Trigger Material 3 theme rebuild      │
└───────────┬───────────────────────────────┘
            ↓
[UI Rebuilds with New Theme]
```

---

## Key Workflows

### 1. Create Lobby from Chat Group
```dart
// Entry: Chat screen "Create Lobby" button
final lobbyId = await ref.read(lobbyNotifierProvider.notifier).createLobby(
  chatGroupId: currentChatGroupId,
  gameName: selectedGame['name'],
  maxSpots: 4,
  isPublic: false,
);

// Result:
// - Lobby created in DB
// - Chat group members notified
// - User navigated to lobby screen
```

### 2. Claim Spot with Auto-Lobby Creation
```dart
// Entry: Discovery screen "Join Game" button (no lobby selected)
await lobbyNotifier.claimSpot('Apex Legends', spotIndex: 0);

// Flow:
// 1. Check if lobby selected → None
// 2. Create new lobby for 'Apex Legends'
// 3. Claim spot 0 in new lobby
// 4. Start 5-minute timer
// 5. Show lobby screen
```

### 3. Peacock Queue Assignment
```dart
// Scenario: User in peacock queue, spot becomes available

// Server (pg_cron every 30s):
process_expired_timers() {
  // 1. Find expired timer
  // 2. Free spot
  // 3. Get next in peacock queue
  // 4. Assign spot with '_calling' suffix
  // 5. Create new timer (5 mins)
  // 6. Insert peacock_notification
  // 7. Remove from queue
}

// Client:
// 1. Realtime subscription receives spot update
// 2. LobbyNotifier rebuilds state
// 3. NotificationService receives push notification
// 4. User taps notification
// 5. Deep link opens lobby screen with game context
// 6. User sees claimed spot with timer
```

### 4. Record Match Result
```dart
// Entry: Lobby screen "Record Win" button
await lobbyNotifier.recordWin(lobbyId);

// Database:
INSERT INTO match_history (lobby_id, game_name, result, player_uids, created_by)
VALUES (?, ?, 'win', ARRAY[...current_spots...], current_user_id);

// Updates:
// - Match history count
// - Win/loss ratio
// - Lobby last_activity timestamp
```

---

## Known Issues & Technical Debt

### Critical Issues

#### 1. Timer Sync Lag
**Problem**: Client timers can drift from server by up to 30 seconds
**Cause**: pg_cron runs every 30s, client runs every 1s
**Impact**: User sees timer expire locally but spot doesn't free immediately
**Workaround**: Show "Processing..." state when timer reaches 0
**Fix Needed**: Reduce pg_cron interval to 10s OR implement WebSocket for instant updates

#### 2. Race Condition on Spot Claims
**Problem**: Two users can claim same spot simultaneously
**Cause**: No database-level locking during claim operation
**Impact**: Rare, but causes one user's claim to be overwritten
**Workaround**: Optimistic locking with version field
**Fix Needed**: Add `version` column to `squad_spots`, increment on update, reject stale updates

#### 3. Memory Leak in Timer Service
**Problem**: Timers not properly disposed when app backgrounded
**Cause**: `Timer` instances not cancelled in `dispose()`
**Impact**: Battery drain, memory usage grows
**Fix Needed**: Implement proper lifecycle management in `TimerService`

### Performance Issues

#### 4. Display Name Fetching Bottleneck
**Problem**: Fetches display names one-by-one for each UID
**Cause**: Loop with individual Supabase queries
**Impact**: Slow lobby rendering with many members (>10)
**Fix Needed**: Batch query with `WHERE uid IN (...)`

```dart
// Current (slow):
for (final uid in memberUids) {
  final name = await supabase.from('users').select('display_name').eq('uid', uid).single();
}

// Improved:
final names = await supabase.from('users').select('uid, display_name').in_('uid', memberUids);
```

#### 5. IGDB Rate Limiting
**Problem**: Hitting 4 req/sec limit during game search
**Cause**: Debounce delay too short (300ms)
**Impact**: Search results fail with 429 errors
**Fix Needed**: Increase debounce to 500ms, implement request queue

### UI/UX Issues

#### 6. No Loading State for Spot Claims
**Problem**: No visual feedback between tap and spot assignment
**Cause**: Missing loading indicator
**Impact**: User confused, taps multiple times
**Fix Needed**: Show spinner on spot card during claim

#### 7. Peacock Queue Position Not Updated
**Problem**: User's queue position doesn't decrement when others leave
**Cause**: Position calculated on insert, not recalculated
**Fix Needed**: Trigger function to update positions on queue delete

### Data Inconsistencies

#### 8. Orphaned Timers in Database
**Problem**: Timer records persist after spot manually removed
**Cause**: No ON DELETE CASCADE between squad_spots and squad_timers
**Impact**: Expired timer processor tries to free already-free spots
**Fix Needed**: Add foreign key constraint with CASCADE

#### 9. Game-Scoped Data Duplication
**Problem**: Same lobby data stored per-game (gameLobbySpots, gameSpotTimers)
**Cause**: Originally designed for single-game lobbies, expanded to multi-game
**Impact**: State size grows with game count, sync complexity increases
**Refactor Needed**: Normalize schema to game_lobby_spots table with compound key

---

## Improvement Opportunities

### High Priority

#### 1. Real-time Timer Sync via WebSockets
**Goal**: Eliminate 30-second lag in timer expiration
**Implementation**:
- Switch from pg_cron polling to Supabase Realtime channels
- Broadcast timer events immediately
- Client subscribes to `timer_expired` events
- Server still authoritative via pg_cron as backup

**Benefits**:
- Instant spot freeing
- Better UX for users
- Reduced confusion

#### 2. Optimistic UI Updates
**Goal**: Make UI feel instant, reconcile later
**Implementation**:
```dart
Future<void> claimSpot(String gameName, int spotIndex) async {
  // 1. Update local state immediately
  _updateLocalState(gameName, spotIndex, userId);
  
  try {
    // 2. Send to server
    await _repository.assignSpot(lobbyId, spotIndex, userId);
  } catch (e) {
    // 3. Rollback on failure
    _revertLocalState(gameName, spotIndex);
    _showError('Spot already taken!');
  }
}
```

**Benefits**:
- Feels instant to user
- Network lag hidden
- Graceful error handling

#### 3. Batch Operations for Display Names
**Goal**: Reduce database queries by 90%
**Implementation**:
```dart
Future<Map<String, String>> fetchDisplayNamesForUids(List<String> uids) async {
  final response = await supabase
      .from('users')
      .select('uid, display_name')
      .in_('uid', uids);
  
  return Map.fromEntries(
    response.map((row) => MapEntry(row['uid'], row['display_name']))
  );
}
```

**Benefits**:
- 10x faster lobby loading
- Reduced API costs
- Better scalability

### Medium Priority

#### 4. Game Recommendation Engine
**Goal**: Suggest games based on user history and friends
**Implementation**:
- Track game_history table
- Calculate similarity scores (collaborative filtering)
- Show "Friends are playing..." section
- IGDB genres for content-based recommendations

#### 5. Lobby Templates
**Goal**: Pre-configured lobbies for common scenarios
**Templates**:
- "Quick Match" (2 spots, 2-min timers)
- "Ranked Squad" (4 spots, 10-min timers, voice required)
- "Casual Hangout" (8 spots, no timers, open queue)

#### 6. Advanced Queue System
**Features**:
- **Preferred Games**: Auto-join queue for favorite games
- **Skill-Based Matching**: Queue with similar-rank players
- **Time Slots**: Reserve spot for specific times
- **Group Queue**: Join queue as a party

### Low Priority

#### 7. Lobby Statistics Dashboard
**Metrics**:
- Win/loss ratio per game
- Most played games
- Average match duration
- Peak activity times
- Member contribution scores

#### 8. Spectator Mode
**Features**:
- Watch lobby without joining
- Real-time spot updates
- Chat as viewer
- Join button when spot opens

#### 9. Custom Timer Durations
**Options**:
- 2 minutes (quick matches)
- 5 minutes (default)
- 10 minutes (ranked)
- No timer (casual)

---

## Testing Recommendations

### Unit Tests Needed
```dart
// LobbyNotifier
test('claimSpot creates lobby if none selected', () async {
  final notifier = LobbyNotifier();
  await notifier.claimSpot('Fortnite', 0);
  
  expect(notifier.state.value.selectedLobbyId, isNotNull);
  expect(notifier.state.value.gameLobbySpots['Fortnite'], isNotEmpty);
});

// TimerManagementNotifier
test('expired timer frees spot and assigns to peacock queue', () async {
  // Setup: Timer expires
  // Assert: Spot freed, queue member assigned
});

// GameNotifier
test('IGDB fallback to SQLite cache when API fails', () async {
  // Mock IGDB error
  // Assert: Returns cached games
});
```

### Integration Tests Needed
```dart
testWidgets('full lobby workflow: create -> join -> claim -> lock', (tester) async {
  // 1. Create lobby
  // 2. Join as second user
  // 3. Claim spot
  // 4. Lock spot
  // Assert: Spot marked as 'Ready', timer stopped
});
```

---

## Performance Metrics

### Current Baselines
- **Lobby Creation**: ~500ms (includes DB write + notifications)
- **Spot Claim**: ~300ms (DB update + timer start)
- **Game Search**: ~1-2s (IGDB API), ~50ms (cached)
- **Display Name Fetch**: ~100ms per user (needs optimization)
- **Timer Expiration Lag**: 0-30s (pg_cron interval)

### Target Improvements
- Lobby Creation: 300ms (batch notifications)
- Spot Claim: 100ms (optimistic UI)
- Display Name Fetch: 100ms total (batch query)
- Timer Expiration Lag: <1s (WebSocket events)

---

## Conclusion

This document provides a complete reference for understanding and improving SquadSync's lobby and game systems. Key areas for AI-assisted enhancement:

1. **Real-time timer synchronization** (eliminate 30s lag)
2. **Optimistic UI updates** (instant feedback)
3. **Batch database operations** (10x performance boost)
4. **Race condition handling** (prevent duplicate claims)
5. **Memory leak fixes** (timer disposal)
6. **Enhanced game discovery** (recommendations, filters)
7. **Advanced queue features** (skill-based, group queues)

All code follows Flutter/Dart best practices with Riverpod 3.0 state management, Freezed immutability, and clean architecture principles.
