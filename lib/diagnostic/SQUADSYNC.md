# SquadSync — App Architecture Reference

**Last Updated**: December 15, 2025  
**Purpose**: Current architecture documentation and technical reference for SquadSync codebase  
**Version**: 1.2.2+1 (Production Ready)

## Executive Overview

SquadSync is a Flutter-based lobby gaming coordination app with **Clean Architecture + Riverpod state management**. Features **Supabase PostgreSQL as primary database** with SQLite offline caching for high-performance real-time features. Includes xAI Grok AI integration for smart replies and IGDB game data integration.

**Current Statistics** (December 15, 2025):
- **Total Dart Files**: 233 active source files (excluding generated .freezed/.g files)
- **Total Lines of Code**: ~70,245 LOC (active code only, excludes generated files)
- **Architecture**: Clean - Notifiers → Repositories → DataSources → Services
- **State Management**: Riverpod (12 notifiers total: 9 core + 3 specialized)
- **Database**: Supabase PostgreSQL (25 tables, 92 RLS policies) + SQLite offline cache
- **Services**: 31 service files in lib/services/ (APIs, utilities, infrastructure)
- **Error Handling**: Centralized ErrorHandlingService with retry logic & performance monitoring
- **Components**: Modular component-based architecture with unified game selection system
- **Recent Updates**: Chat group discovery & invite code system (Dec 15), ErrorHandlingService integration, Firebase cleanup (Dec 12, 2025)

## Architecture

### Overview

**Pattern**: Clean Architecture with Riverpod State Management  
**Layers**: 4-tier architecture (Presentation → Domain → Data → Services)  
**Database Strategy**: Supabase PostgreSQL Primary + SQLite Offline Cache  
**State Management**: Riverpod (AutoDisposeAsyncNotifier + AsyncNotifier)  
**Migration Status**: ✅ Firebase Core & Firestore REMOVED (Dec 2025)  
**Firebase Usage**: Analytics & Push Notifications ONLY (firebase_analytics, firebase_messaging)

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│  Riverpod Notifiers (12 total) | UI Widgets | Screens      │
│        ~4,200 lines total across notifiers                  │
└─────────────────────┬───────────────────────────────────────┘
                      │ calls
┌─────────────────────▼───────────────────────────────────────┐
│                      DOMAIN LAYER                           │
│  Repository Interfaces (5) | Entities (Freezed, 21 files)  │
│        ~2,500 lines entities (excludes generated)           │
└─────────────────────┬───────────────────────────────────────┘
                      │ implements
┌─────────────────────▼───────────────────────────────────────┐
│                       DATA LAYER                            │
│  Repository Implementations (5) | DataSources (Local+Remote)│
│        ~4,285 lines (repos + datasources)                   │
└─────────────────────┬───────────────────────────────────────┘
                      │ uses
┌─────────────────────▼───────────────────────────────────────┐
│                     SERVICES LAYER                          │
│  External APIs | Utilities | Infrastructure (30+ services) │
│        ~15,000 lines total across services                  │
└─────────────────────────────────────────────────────────────┘
```

### Frontend
- **Framework**: Flutter 3.38.x with Dart SDK >=3.3.0
- **State Management**: Riverpod with `AutoDisposeAsyncNotifier` and `AsyncNotifier` for reactive state
- **UI Design**: Material 3 with dynamic theming (palette_generator from IGDB covers), glassmorphic effects, neon glow accents
- **Navigation**: GoRouter with route-based navigation (/, /squad, /chat, /profile, /clips)

#### Riverpod Notifiers (12 Total: 9 Core + 3 Specialized)

**Core State Notifiers** (AutoDisposeAsyncNotifier/AsyncNotifier):

| Notifier | File | Lines | Responsibility | Database | Dependencies |
|----------|------|-------|----------------|----------|--------------|
| **ChatNotifier** | `chat_notifier.dart` | ~573+ | Chat UI orchestration, group management, group discovery, invite code system, presence tracking | Supabase Realtime + SQLite | ChatRepository, UserNotifier, GameNotifier, LobbyNotifier |
| **LobbyNotifier** | `lobby_notifier.dart` | 760 | Lobby spots, timers, peacock queue, member status | Supabase | LobbyRepository + TimerServiceNotifier |
| **UserNotifier** | `user_notifier.dart` | 435 | User profiles, friends, pinned games, blocks/bans | Supabase | UserRepository + FriendsService |
| **CurrentLobbyNotifier** | `current_lobby_notifier.dart` | 343 | Real-time active lobby tracking with Supabase Realtime | Supabase Realtime | SupabaseClient direct |
| **ClipNotifier** | `clip_notifier.dart` | 305 | Clips feed, Clip of the Day, video content management | Supabase | SupabaseService |
| **GameNotifier** | `game_notifier.dart` | 150 | Game selection, IGDB integration, game lobbies | IGDB API + Cache | 4 use cases + GameLocalDataSource |
| **UserLobbysNotifier** | `user_squads_notifier.dart` | 104 | User squad memberships with real-time updates | Supabase Realtime | SupabaseClient direct |
| **SystemNotifier** | `system_notifier.dart` | 95 | Theme, notifications, analytics, bans, availability | Supabase + SharedPrefs | 9 use cases |
| **DiscoveryNotifier** | `discovery_notifier.dart` | 64 | Lobby discovery, filters (hot/new/game), popular games | Supabase Realtime | SupabaseClient direct |

**Specialized Controllers**:

| Controller | Type | Lines | Purpose |
|------------|------|-------|---------|
| **GameThemeController** | StateNotifier | 421 | Dynamic theme color extraction from IGDB game covers |
| **OnboardingNotifier** | AutoDisposeAsyncNotifier | ~150 | Onboarding flow state (callsign, avatar, games, preferences) |
| **ChatStateNotifier** | StateNotifier | 207 | Chat UI ephemeral state (typing, recording) |

**Total Notifier Lines**: ~4,200 lines across 12 notifiers

### Data Layer

**Architecture**: Repository Pattern with Local + Remote DataSources

#### Database Strategy

**Primary**: Supabase PostgreSQL ✅ Production
- Real-time subscriptions via Supabase Realtime for chat, lobbies, presence
- Row Level Security (RLS): 25 public tables with 92 policies (schema validated Dec 12, 2025)
- Supabase Auth (Apple Sign-In ✅, Email/Password ✅, Google planned)
- Supabase Storage: 5 buckets (avatars, clips, media, chat_backgrounds, squadsync-media) with 20 storage policies
- PostgreSQL functions: 15+ functions (`accept_friend_request()`, `remove_friendship()`, etc.)
- Full-text search capabilities for user/game search
- Views: `chat_groups_with_stats` (computed member_count, last_message)
- Database triggers: 15 total (timestamp auto-update, message handling)
- Indexes: 97 total (89 BTREE, 8 GIN) for query optimization

**Offline Cache**: SQLite
- Message history caching via sqflite
- Game data caching (IGDB results)
- Offline-first message queue via ConnectivityNotifier
- Timer state persistence
- Background sync with BackgroundSyncService

**Migration Complete**: Firebase Removed ✅ (December 2025)
- **Status**: ✅ Firebase Core & Cloud Firestore packages REMOVED from pubspec.yaml
- **Remaining**: firebase_analytics, firebase_messaging (analytics & push notifications only)
- **Legacy cleanup**: Migration tools and old references removed
- **BACKUP files**: All removed, no auth_service_BACKUP.dart found
- **Production status**: 100% Supabase for database operations

#### Database Operations Flow

```
Write Path (Chat Example):
User Input → ChatNotifier → SendMessage UseCase → ChatRepository 
  → ChatRemoteDataSource (Supabase primary)
  → ChatLocalDataSource (SQLite cache)

Read Path (Chat Example):
ChatScreen → ChatNotifier.loadMessages()
  → LoadMessages UseCase → ChatRepository
  → Try: ChatRemoteDataSource (Supabase)
  → Fallback: ChatLocalDataSource (SQLite)

Real-time Path:
Supabase Realtime Stream → CurrentLobbyNotifier
  → UI updates automatically via Riverpod
```

#### Data Layer Components

**Repositories** (5 implementations, 1,176 total lines):

| Repository | File | Lines | Interfaces | Databases Used |
|------------|------|-------|------------|----------------|
| **ChatRepositoryImpl** | `chat_repository_impl.dart` | 413+ | `ChatRepository` | Supabase (primary) + SQLite (cache) |
| **UserRepositoryImpl** | `user_repository_impl.dart` | 269 | `UserRepository` | Supabase |
| **SystemRepositoryImpl** | `system_repository_impl.dart` | 218 | `SystemRepository` | Supabase + SharedPreferences |
| **LobbyRepositoryImpl** | `lobby_repository_impl.dart` | 201 | `LobbyRepository` | Supabase |
| **GameRepositoryImpl** | `game_repository_impl.dart` | 131 | `GameRepository` | IGDB API + SQLite |

**DataSources** (15 files):

**Remote DataSources** (6 active):
- `chat_remote_datasource_impl.dart` - Supabase Realtime chat operations (701+ lines with group discovery and invite code support)
- `user_remote_datasource.dart` - Supabase user operations
- `lobby_remote_datasource.dart` - Supabase lobby operations (formerly squad_remote_datasource.dart)
- `system_remote_datasource.dart` - Supabase system operations  
- `game_remote_datasource.dart` - IGDB API integration
- `supabase_service.dart` - Supabase client initialization

**Local DataSources** (6 active):
- `chat_local_datasource_impl.dart` - SQLite message cache (516 lines)
- `user_local_datasource.dart` - SQLite/SharedPreferences user cache
- `lobby_local_datasource.dart` - SQLite lobby cache (formerly squad_local_datasource.dart)
- `system_local_datasource.dart` - SharedPreferences system settings
- `game_local_datasource.dart` - SQLite game cache
- `sqlite_helper.dart` - SQLite database management

**Legacy/BACKUP** (1 file found - cleanup incomplete):
- `auth_service_BACKUP.dart` - Firebase Auth backup still present

**Total DataSource Lines**: ~3,500 lines (excluding BACKUP files)

### Domain Layer

**Purpose**: Business logic, entity definitions, repository interfaces (Clean Architecture core)

**Components**: 65 total files

#### Entities (21 files - Freezed Immutable)

**Primary State Entities** (with code generation):

| Entity | File | Purpose | Fields | Serialization |
|--------|------|---------|--------|---------------|
| **LobbyState** | `squad_state.dart` + .freezed + .g | Lobby state with game-scoped data | `gameLobbySpots`, `gameSpotTimers`, `peacockQueues`, `currentGame` | ✅ JSON |
| **ChatState** | `chat_state.dart` + .freezed | Chat UI and message state | `messages`, `groups`, `typingUsers`, `onlineUsers` | ❌ No JSON |
| **AppUser** | `app_user.dart` + .freezed + .g | User profile entity | `uid`, `displayName`, `profileImage`, `pinnedGames`, `friends` | ✅ JSON |
| **Lobby** | `squad.dart` + .freezed + .g | Lobby entity | `spots[]`, `spotTimers[]`, `viewers`, `statuses`, `isActive` | ✅ JSON |
| **Game** | `game.dart` + .freezed + .g | Game entity from IGDB | `id`, `name`, `cover`, `maxSpots`, `modes` | ✅ JSON |
| **Message** | `message.dart` + .freezed | Chat message entity | `id`, `content`, `senderId`, `timestamp`, `mediaUrl`, `reactions` | ❌ No JSON |
| **ChatGroup** | `chat_group.dart` + .freezed + .g | Chat group entity | `id`, `name`, `memberUids`, `isPublic`, `memberCount`, `createdBy`, `createdAt`, `inviteCode`, `admins`, `moderators` | ✅ JSON |
| **SystemState** | `system_state.dart` + .freezed + .g | System settings entity | `themeMode`, `notificationSettings`, `lastSync` | ✅ JSON |

**Total Entity Lines**: ~2,500 lines (active code) + ~8,000 lines (generated .freezed.dart + .g.dart files)

#### Repository Interfaces (5 files)

| Interface | File | Methods | Purpose |
|-----------|------|---------|---------|
| **LobbyRepository** | `lobby_repository.dart` | ~12 methods | Lobby CRUD, spot management, timers |
| **ChatRepository** | `chat_repository.dart` | ~16 methods | Messages, group CRUD (create/join/leave), group discovery, invite codes, media, polls, typing indicators |
| **UserRepository** | `user_repository.dart` | ~10 methods | User profiles, friends, blocks |
| **SystemRepository** | `system_repository.dart` | ~8 methods | System settings, notifications |
| **GameRepository** | `game_repository.dart` | ~6 methods | IGDB integration, game search |

**Call Flow**:
```
UI → Notifier → Repository → DataSource → Database/API
```

**Example**:
```dart
// Notifiers now call repositories directly
class UserNotifier extends AutoDisposeAsyncNotifier<AppUser?> {
  late final UserRepository _repository;
  
  @override
  Future<AppUser?> build() async {
    _repository = ref.read(userRepositoryProvider);
    return await _repository.getCurrentUser();
  }
  
  Future<void> updateDisplayName(String name) async {
    await _repository.updateDisplayName(name);
    ref.invalidateSelf();
  }
}
```

### Services Layer (33 Files)

**Purpose**: External API integration, utilities, cross-cutting concerns, centralized error handling

**Total Lines**: ~15,400+ lines across 31 .dart services + 2 .md docs

#### Primary Services (Current State)

| Service | File | Lines | Responsibility | Database/API |
|---------|------|-------|----------------|--------------|
| **VideoService** | `video_service.dart` | 1,212 | Agora video SDK, screen sharing, beauty filters | Supabase + Agora SDK |
| **VoiceService** | `voice_service.dart` | 887 | Agora voice SDK, spatial audio, room management | Supabase + Agora SDK |
| **ChatUIManager** | `chat_ui_manager.dart` | 767 | Chat UI coordination, scrolling, message selection | N/A (UI state) |
| **MessageService** | `message_service.dart` | 677 | Message CRUD, AI integration, realtime subscriptions, typing indicators | Supabase + SQLite |
| **FriendsService** | `friends_service.dart` | 489 | Friend requests, friend list, DMs, game muting | Supabase |
| **TimerService** | `timer_service.dart` | 466 | Timer orchestration, spot timers, peacock timers | SQLite + Supabase + Firebase (legacy TODOs) |
| **BackgroundService** | `background_service.dart` | 461 | Background sync, notifications, WorkManager | N/A |
| **ClipService** | `clip_service.dart` | 370 | Video compression (ffmpeg_kit), Supabase upload | Supabase Storage |
| **IGDBService** | `igdb_service.dart` | 355 | IGDB API integration for game data | IGDB API |
| **MediaService** | `media_service.dart` | 276 | Media upload to Supabase Storage | Supabase Storage |
| **ErrorHandlingService** | `error_handling_service.dart` | 380 | Centralized error handling, retry logic, performance monitoring | Firebase Analytics + Logger |
| **GrokService** | `grok_service.dart` | 242 | xAI Grok API integration for smart replies | xAI Grok API |
| **AuthServiceSupabase** | `auth_service_supabase.dart` | 228 | Supabase Auth (email, Google, Apple Sign-In) | Supabase Auth |

**Chat Subsystem Services** (8 files in `lib/chat/services/`):
- `chat_typing_manager.dart` (~100 lines) - Typing indicators
- `chat_online_status_manager.dart` (~90 lines) - Presence tracking
- `chat_initialization_service.dart` (137 lines) - Chat setup
- `chat_scroll_controller.dart` (~120 lines) - Scroll behavior
- `chat_media_handler.dart` (~150 lines) - Media attachments
- `reaction_service.dart` (~80 lines) - Reaction management
- `chat_message_search_delegate.dart` (~50 lines) - Search functionality

#### Service Categories

**External API Services** (6):
- IGDBService (355 lines) - Game data
- GrokService (242 lines) - AI chat assistance  
- IGDBAuthService (~100 lines) - IGDB token management
- AIService (~150 lines) - AI integration wrapper

**Real-Time Communication** (2):
- VideoService (1,212 lines) - Agora video SDK
- VoiceService (887 lines) - Agora voice SDK  

**Media Processing** (3):
- ClipService (370 lines) - Video compression + upload
- MediaService (276 lines) - General media uploads
- AudioService (~200 lines) - Audio recording/playback

**Authentication** (3):
- AuthServiceSupabase (228 lines) - Primary auth
- AuthService (158 lines) - Wrapper (redundant)
- AuthSyncService (~150 lines) - Auth state synchronization

**Infrastructure** (12):
- BackgroundService (461 lines) - Background tasks
- TimerService (466 lines) - Timer management with Firebase TODOs
- **ErrorHandlingService** (380 lines) - Centralized error handling, retry logic, performance monitoring
- CacheService (~100 lines) - State caching with TTL
- SupabaseService (~200 lines) - Supabase client init
- NotificationService (~250 lines) - Push notifications
- SessionDebugHelper (~100 lines) - Session debugging
- LobbyAutoSelectService - Auto-select squads
- AgoraConfigService - Agora RTC configuration
- VoiceRoomService - Voice room management
- NavigationService - Navigation analytics
- OnboardingStateService - Onboarding flow state

### Error Handling & Monitoring ✨ NEW (Dec 12, 2025)

**ErrorHandlingService** - Centralized error handling with observability

**Location**: `lib/services/error_handling_service.dart` (380 lines)  
**Documentation**: `lib/services/ERROR_HANDLING_QUICK_REFERENCE.md`

**Features**:
- 👥 **User-Facing Messages**: Converts technical errors to friendly SnackBar messages
- 🔄 **Automatic Retry**: Retries transient failures (network, timeouts, 5xx) with exponential backoff (max 3 attempts)
- ⚡ **Performance Monitoring**: Logs slow operations (>500ms) to Firebase Analytics
- 📊 **Analytics Integration**: Tracks error patterns (`error_occurred`, `slow_operation` events)
- 📝 **Comprehensive Logging**: Uses `logger` package with pretty formatting and stack traces

**Usage Pattern**:
```dart
// In notifiers - inject via GetIt
class LobbyNotifier extends AsyncNotifier<LobbyState> {
  late final ErrorHandlingService _errorHandler;
  
  @override
  Future<LobbyState> build() async {
    _errorHandler = ref.read(errorHandlingServiceProvider);
    return await _loadState();
  }
  
  Future<LobbyState> _loadState() async {
    try {
      // Load with retry + performance monitoring
      return await _errorHandler.withRetryAndMonitoring(
        operation: () => _repository.loadLobbyState(),
        operationName: 'loadLobbyState',
        maxAttempts: 2,
        slowThreshold: Duration(milliseconds: 500),
      );
    } catch (e, stackTrace) {
      await _errorHandler.handleError(
        error: e,
        operation: 'loadLobbyState',
        stackTrace: stackTrace,
        showSnackBar: false,
      );
      return LobbyState.initial();
    }
  }
}
```

**Integrated Notifiers** (Dec 12, 2025):
- ✅ LobbyNotifier - Lobby operations with retry and performance monitoring
- ✅ ChatNotifier - Chat initialization error handling
- ✅ UserNotifier - User profile loading error handling

**Retry Strategy**:
- Retries: Network errors, timeouts, rate limiting (429), server errors (5xx)
- Does NOT retry: Client errors (4xx), permission errors, validation errors
- Backoff: Exponential with 25% randomization (1s → 2s → 4s, max 10s)

**Analytics Events**:
1. `error_occurred`: Tracks error type, message, operation, timestamp
2. `slow_operation`: Tracks duration_ms, threshold_ms, operation name

### Backend & Infrastructure

- **Server**: Node.js/Express with PostgreSQL for analytics
- **Timer Processing**: 
  - **Supabase pg_cron** (Primary): Server-side timer processing (runs every 30 seconds)
    - `process_expired_timers()` - Frees spots, assigns to peacock queue
    - `process_expired_queue()` - Cleans peacock entries, rebalances
  - Firebase Cloud Functions (Legacy backup) - Runs `updateTimers` every 1 minute
- **Authentication**: 
  - **Supabase Auth** (Primary): Apple Sign-In, Email/Password, Google (planned)
  - Firebase Auth for backward compatibility (being phased out)
- **AI Integration**: xAI Grok API (grok-4.1-fast-latest) for smart replies and chat responses
- **Dependency Injection**: GetIt for service location and dependency management

### Database Migration Status

**Supabase Primary Database: Fully Operational** ✅

| Component | Status | Database | Notes |
|-----------|--------|----------|-------|
| **Auth** | ✅ Production | Supabase Auth | Apple Sign-In, Email/Password active |
| **Chat Messages** | ✅ Production | Supabase (chat_messages table) | Real-time streams, 10 RLS policies |
| **User Profiles** | ✅ Production | Supabase (users table) | 7 RLS policies, friends system active |
| **Lobbies** | ✅ Production | Supabase (lobbies table) | 4 RLS policies, game_focus column |
| **Chat Groups** | ✅ Production | Supabase (chat_groups + view) | 1 policy, with_stats view for computed fields |
| **Friends System** | ✅ Production | Supabase (friends, friend_requests, direct_messages) | PostgreSQL functions active |
| **Clips** | ✅ Production | Supabase (clips table) | Storage bucket configured |
| **Media Storage** | ✅ Production | Supabase Storage | 5 buckets with policies (Dec 11 fixes) |
| **RLS Policies** | ✅ Complete | 22 tables with 60+ policies | Full security coverage |
| **Realtime** | ✅ Active | Supabase Realtime | Chat, lobbies, presence streaming |

**Schema Documentation**: See `SUPABASE_FUNCTIONS_INVENTORY.md` for complete schema reference

## Codebase Statistics (December 12, 2025)

### File Distribution

**Total Active Dart Files**: 231 source files (excludes generated code)  
**Total Active LOC**: ~69,400 lines of Dart code  
**Generated Code**: ~30,000 LOC (.freezed.dart, .g.dart files)  
**Total Project Files**: ~410+ files (includes assets, configs, docs)

| Directory | Files | Purpose | Notes |
|-----------|-------|---------|-------|
| **presentation/** | 30+ | Notifiers (12), controllers, hooks, onboarding | Core state management |
| **chat/** | 60+ | Chat system (screens, widgets, services, dialogs) | Complete chat subsystem |
| **services/** | 31+ | External APIs, utilities, error handling | MessageService, ErrorHandlingService, etc. |
| **lobbies_tab/** | 20+ | Lobby management UI (dialogs, widgets) | Formerly squad_tab |
| **screens/** | 14 | Main screens (discovery, clips, profile, etc.) | Top-level navigation |
| **data/** | 20 | Repositories (5), datasources (12) | Data layer implementations |
| **domain/** | 19 | Entities (21 files), repositories (5 interfaces) | Business logic layer |
| **widgets/** | 12 | Shared widgets (AsyncValueWidget, etc.) | Reusable components |
| **diagnostic/** | 3 | Schema audit, storage policy fixes, analysis | Database tools |
| **core/** | 3 | App config, theme, dependency injection | Infrastructure |
| **models/** | 7 | Legacy models | Minimal duplicates |
| **managers/** | 1 | Notification manager | Legacy pattern |

### Top 10 Largest Files

| File | Lines | Purpose | Notes |
|------|-------|---------|-------|
| `chat/screens/chat_info_screen.dart` | 2,389 | Chat info/settings coordinator with 8 component files | Component-based architecture |
| `profile_tab.dart` | 1,653 | Profile tab with settings | Large but manageable |
| `chat/chat_screen.dart` | 1,571 | Main chat UI | Core feature - size justified |
| `domain/entities/chat_state.freezed.dart` | 1,439 | Generated freezed code | ✅ Auto-generated |
| `domain/entities/squad_state.freezed.dart` | 1,285 | Generated freezed code | ✅ Auto-generated |
| `chat/widgets/clip_player_screen.dart` | 1,218 | Full-screen clip player | Feature-rich video player |
| `services/video_service.dart` | 1,212 | Agora video SDK integration | Complex RTC logic |
| `chat/message_bubble.dart` | 1,172 | Message bubble component | ⚠️ Large - extract message types |
| `screens/video_room_screen.dart` | 1,133 | Video room UI | Complex RTC UI |
| `chat/dialogs/group_actions_dialog.dart` | 1,097 | Group management dialog | Feature-rich dialog |

### Code Composition (Accurate Counts - Dec 12, 2025)

| Category | Lines | Files | Notes |
|----------|-------|-------|-------|
| **Active Dart Source** | ~68,600 | 230 files | Excludes generated .freezed/.g files; -400 LOC from game selection refactor |
| **Generated Code** (.freezed, .g) | Est. ~30,000 | ~80 files | Auto-generated by build_runner |
| **Test Code** | ~3,000 | ~25 files | Unit & integration tests |
| **Documentation** (.md) | ~15,000 | ~30 files | Architecture docs, guides |
| **Configuration** (yaml, json, sql) | ~3,000 | ~50 files | pubspec, schemas, migrations |
| **Total Project** | ~119,600 | ~410+ files | Complete codebase |

### Layer-by-Layer Breakdown

| Layer | Files | Lines | Percentage | Key Components |
|-------|-------|-------|------------|----------------|
| **Presentation** | 40 | ~4,800 | 11% | 13 notifiers, screens, onboarding | **-400 lines (game selection refactor)**
| **Domain** | 31 | ~10,480 | 24% | 21 entities (~10,500 generated), repositories only | **-920 lines (use cases removed)**
| **Data** | 20 | ~4,285 | 10% | 5 repositories, 12 datasources | **-391 lines, -3 BACKUP files**
| **Services** | 32 | ~15,000 | 32% | External APIs, utilities, chat services (30 .dart + 2 .md) |
| **UI/Widgets** | 109 | ~35,000 | 25% | Screens, widgets, dialogs, chat UI | **+3 files (unified game components)**
| **Diagnostic** | 3 | ~500 | <1% | Schema audit, storage policy fixes, analysis | **NEW**

### State Management Distribution

| Type | Files | Lines | Purpose |
|------|-------|-------|---------|
| **Riverpod Notifiers** | 13 | 3,930 | Primary state management (call repositories directly) |
| **Freezed Entities** | 21 | ~10,500 | Immutable state entities (with generated code) |
| **Repositories** | 5 | 1,176 | Data access layer (direct from notifiers) |

### Database Code Distribution

| Database | Files | Lines | Purpose | Status |
|----------|-------|-------|---------|--------|
| **Supabase** | ~30 | ~8,000 | Primary database operations | ✅ Production (25 tables, 92 policies) |
| **SQLite** | ~10 | ~2,500 | Offline caching & sync | ✅ Active (offline-first) |
| **Firebase** | 2 | Minimal | Analytics & push notifications only | ✅ Core packages removed |
| **BACKUP Files** | 0 | 0 | All removed | ✅ Cleanup complete |

### Test Coverage

| Type | Files | Lines | Status |
|------|-------|-------|--------|
| **Unit Tests** | 3 | ~490 | Limited coverage, needs expansion |
| **Integration Tests** | 1 driver | N/A | test_driver/integration_test.dart |

**Test Files**:
- `test/chat/screens/components/chat_info_components_test.dart` (390 lines, 19 tests)
- `test/chat/` subdirectory (basic tests)
- `test_driver/integration_test.dart` (integration driver)

**Note**: Test coverage is minimal and requires significant expansion for production readiness.

### Dependencies Summary

**Key Package Categories**:

**State Management**:
- `riverpod` + `flutter_riverpod` + `hooks_riverpod`
- `freezed` + `freezed_annotation` (code generation)
- `json_serializable` (serialization)

**Database & Backend**:
- `supabase_flutter` (primary database - all auth, real-time, storage)
- `sqflite` (offline cache)
- `shared_preferences` (settings)
- `firebase_analytics` (analytics only)
- `firebase_messaging` (push notifications only)

**UI & Design**:
- `flutter_animate` (micro-interactions)
- `google_fonts` (Orbitron, Inter)
- `palette_generator` (theme color extraction)
- `flutter_svg`, `cached_network_image`

**Media & RTC**:
- `agora_rtc_engine` (video/voice)
- `video_compress`, `ffmpeg_kit_flutter` (video processing)
- `image_picker`, `file_picker`
- `audioplayers`, `record`

**External APIs**:
- `http`, `dio` (networking)
- Custom IGDB API integration
- Custom xAI Grok API integration

**Utilities**:
- `get_it` (dependency injection)
- `logger` (logging)
- `url_launcher`, `uni_links` (deep linking)
- `workmanager` (background tasks)

## Folder Structure & Purpose

```
lib/
├── main.dart                          # App entry point, Firebase init, deep linking
├── app_theme.dart                     # Theme definitions (dark/light)
├── firebase_options.dart              # Firebase configuration
├── utils.dart                         # Utility functions and helpers
├── notification_service.dart          # Push notification handling
├── migration.dart                     # Data migration utilities
├── squad_state_notifier.dart         # Legacy state (being phased out)
├── setup_screen.dart                  # Initial setup and auth
├── join_squad_screen.dart             # Join squad by code
├── main_navigation_screen.dart        # Main navigation container (4 tabs: Lobby, Chat, Clips, Profile)
├── profile_tab.dart                   # User profile tab with notification settings
│
├── presentation/
│   ├── notifiers/                     # Riverpod state notifiers
│   │   ├── lobby_notifier.dart        # Lobby state (spots, timers, members) - formerly squad_notifier.dart
│   │   ├── game_notifier.dart         # Game selection and IGDB data
│   │   ├── chat_notifier.dart         # Chat messages, group discovery, invite codes, UI state (573+ lines)
│   │   ├── clip_notifier.dart         # Clips feed with pagination
│   │   ├── user_notifier.dart         # User profiles and preferences
│   │   ├── system_notifier.dart       # App settings and theme
│   │   ├── current_lobby_notifier.dart # Active lobby context - formerly current_squad_notifier.dart
│   │   ├── user_squads_notifier.dart  # User squad memberships
│   │   └── discovery_notifier.dart    # Lobby discovery
│   ├── controllers/
│   │   └── game_theme_controller.dart # Dynamic theme color extraction
│   ├── widgets/
│   │   ├── animated_theme_wrapper.dart # Smooth theme transitions
│   │   └── group_create_sheet.dart    # Quick group creation modal (490 lines) with confetti, member suggestions
│   └── hooks/
│       └── game_theme_sync.dart       # Auto-sync theme with game changes
│
├── domain/                            # Domain layer (clean architecture)
│   ├── entities/                      # Freezed immutable entities (21 files)
│   │   ├── squad_state.dart           # Lobby state entity (UI state, not DB entity)
│   │   ├── chat_state.dart            # Chat state entity
│   │   ├── app_user.dart              # User entity
│   │   ├── lobby.dart                 # Lobby entity (database entity, distinct from LobbyState)
│   │   ├── game.dart                  # Game entity
│   │   ├── message.dart               # Message entity
│   │   ├── chat_group.dart            # Chat group entity
│   │   └── system_state.dart          # System state entity
│   └── repositories/                  # Repository interfaces (4 files)
│       ├── lobby_repository.dart      # Lobby operations (formerly LobbyRepository)
│       ├── chat_repository.dart       # Chat operations
│       ├── user_repository.dart       # User profile operations
│       └── game_repository.dart       # Game data operations
│   # ✅ Use case layer removed (Dec 11) - notifiers call repositories directly
│
├── data/                              # Data layer implementations
│   ├── datasources/                   # Local/remote data sources
│   │   ├── *_local_datasource.dart
│   │   └── *_remote_datasource.dart
│   └── repositories/                  # Repository implementations
│
├── services/                          # Service layer
│   ├── supabase_service.dart          # Supabase client initialization
│   ├── dual_database_service.dart     # Dual-mode database operations (1,153 lines)
│   ├── firestore_to_supabase_migrator.dart # Migration tool (400 lines)
│   ├── SUPABASE_SCHEMA.sql            # PostgreSQL schema with RLS policies
│   ├── SUPABASE_TIMER_CRON.sql        # pg_cron timer processor
│   ├── grok_service.dart              # xAI Grok AI integration
│   ├── igdb_service.dart              # IGDB game data
│   ├── firestore_service.dart         # Firestore operations (legacy)
│   ├── auth_service.dart              # Firebase Auth (legacy)
│   ├── media_service.dart             # Dual-mode media upload (Supabase + Firebase)
│   ├── timer_service.dart             # Timer management
│   ├── poll_service.dart              # Poll creation/voting
│   ├── clip_service.dart              # Video compression and upload
│   ├── cache_service.dart             # State caching
│   └── ... (14 more services)
│
├── chat/                              # Chat system
│   ├── chat_screen.dart               # Main chat UI
│   ├── chat_service.dart              # Chat business logic
│   ├── chat_input_bar.dart            # Message input with clip support
│   ├── message_bubble.dart            # Message display
│   ├── sqlite_helper.dart             # SQLite offline cache
│   ├── link_preview.dart              # URL previews and inline video
│   ├── peacock_modal.dart             # Peacock queue modal
│   ├── game_selection_sheet.dart      # Lobby creation sheet (50 lines, refactored)
│   ├── poll_*.dart                    # Poll components (3 files)
│   ├── dialogs/                       # Chat dialogs (6 files)
│   ├── services/                      # Chat services (7 files)
│   ├── models/                        # Chat data models
│   └── widgets/                       # Chat UI widgets (17 files, game_selection_card removed)
│       ├── clip_message_bubble.dart   # Glassmorphic clip bubble
│       └── clip_player_screen.dart    # Full-screen clip player
│
├── lobbies_tab/                       # Lobby management UI (formerly squad_tab/)
│   ├── lobbies_tab.dart               # Main lobbies tab
│   ├── lobby_queue_page.dart          # Lobby queue interface
│   ├── spot_widgets.dart              # Spot management UI
│   ├── peacock_widgets.dart           # Peacock UI components
│   ├── member_widgets.dart            # Member display widgets
│   ├── dialogs/                       # Lobby dialogs (14 files)
│   ├── widgets/                       # Lobby widgets (10 files)
│   │   ├── clips_tab.dart             # Clips feed widget (used in ClipsScreen)
│   │   ├── clip_feed_item.dart        # Large clip card for feed
│   │   └── game_selector.dart         # Game display and selection (120 lines, refactored)
│   │   └── ... (7 more)
│   ├── managers/                      # Page navigation
│   └── mixins/                        # Keyboard handler mixin
│
├── screens/                           # Screen components
│   ├── add_game_screen.dart           # Add/manage games
│   ├── clips_screen.dart              # Clips feed screen (main nav tab)
│   ├── discovery_screen.dart          # Discover squads
│   ├── discovery_swipe_screen.dart    # Tinder-style squad discovery
│   ├── voice_room_screen.dart         # Spatial audio voice room with visualizations
│   ├── squad_detail_screen.dart       # Lobby details
│   ├── profile_editing_screen.dart    # Edit profile
│   ├── availability_settings_screen.dart
│   ├── notifications_screen.dart.bak  # Archived (notifications now in ProfileTab)
│   ├── performance_stats_screen.dart
│   ├── splash_screen.dart
│   └── onboarding/                    # Complete onboarding system
│       ├── onboarding_flow.dart       # Main 4-page PageView coordinator
│       ├── onboarding_notifier.dart   # Riverpod state management
│       └── widgets/
│           ├── game_selection_screen.dart    # Page 3: Game selector (380 lines, refactored)
│           ├── preferences_screen.dart       # Page 4: 2x2 preferences grid
│           ├── avatar_selection_widget.dart  # Avatar picker with 8 presets
│           ├── matrix_rain_background.dart   # Animated particle background
│           ├── glass_card.dart               # Glassmorphic container
│           └── neon_button.dart              # Animated glowing button
│
├── widgets/                           # Shared widgets
│   ├── async_value_widget.dart        # Async state display
│   ├── game_selection_widget.dart     # Unified game selector (540 lines, single source of truth)
│   ├── game_tile.dart                 # Unified game display component (630 lines, 4 tile styles)
│   ├── game_search_delegate.dart      # Unified IGDB search functionality (400 lines)
│   ├── group_preview_card.dart        # Group preview card (182 lines) with masked invite code, member count
│   ├── rating_widgets.dart            # Rating UI
│   ├── glass_squad_card.dart          # Glassmorphic squad card for discovery
│   ├── theme_preview_card.dart        # Live theme color preview
│   ├── game_theme_examples.dart       # Theme system usage examples
│   └── ... (5 more widgets)
│
├── managers/                          # Legacy managers
│   └── notification_manager.dart
│
├── models/                            # Legacy models
│   └── poll.dart, squad.dart
│
├── core/                              # Core infrastructure
│   ├── injection.dart                 # Dependency injection
│   └── app_theme.dart                 # Material 3 theme system with dynamic colors
│
├── diagnostic/                        # NEW: Schema audit and policy fixes
│   ├── storage_policy_fixes.sql       # Comprehensive storage policy cleanup
│   ├── supabase_schema_audit.sql      # 20 queries for complete schema analysis
│   └── CODE_REDUNDANCY_ANALYSIS.md    # Comprehensive codebase audit
│
└── examples/                          # Example code
    └── video_service_example.dart

doc/
├── agora_setup.md                     # Agora RTC setup guide
├── null_safety_guide.md               # Null safety migration guide
└── dynamic_theme_system.md            # Dynamic theme documentation

backend/
├── server.js                          # Express server with Grok endpoints
├── package.json
└── .env.example                       # Environment variable template

backend/
├── server.js                          # Express server with Grok endpoints
├── package.json
└── .env.example                       # Environment variable template

functions/
├── index.js                           # Firebase Cloud Functions (timers)
├── package.json
└── README.md

assets/
├── popular_games.json                 # Preloaded popular games
├── images/                            # App icons and images (100+ files)
├── sounds/                            # Audio assets
└── fonts/                             # Custom fonts

test/
├── chat_service_test.dart
├── agora_config_test.dart
├── peacock_modal_test.dart
└── ... (20+ test files)

integration_test/
├── game_search_flow_test.dart
├── onboarding_flow_test.dart
└── squad_join_flow_test.dart
```

## Key Files & What They Do

### Core App Files
- **`lib/main.dart`**: App initialization, **Supabase + Firebase** setup, deep link handling, SharedPreferences for theme
- **`lib/core/app_theme.dart`**: Material 3 theme with dynamic color seeds, glassmorphic extensions, neon glow
- **`lib/utils.dart`**: Helper functions, safe null handling, formatters
- **`lib/presentation/controllers/game_theme_controller.dart`**: Dynamic theme color extraction from IGDB covers
- **`lib/presentation/widgets/animated_theme_wrapper.dart`**: 600ms animated theme transitions
- **`lib/setup_screen.dart`**: **Supabase Auth** setup (Apple Sign-In, Email/Password) with secure nonce generation

### Database Services & Schema
- **`SUPABASE_FUNCTIONS_INVENTORY.md`**: Complete schema documentation (22 tables, 60+ policies, functions)
- **`lib/diagnostic/storage_policy_fixes.sql`**: Storage policy cleanup SQL (Dec 11)
- **`lib/diagnostic/supabase_schema_audit.sql`**: 20 schema audit queries (Dec 11)
- **`lib/services/supabase_service.dart`**: Supabase client initialization and helper methods
- **`lib/services/dual_database_service.dart`**: Legacy dual-mode service (deprecated, kept for reference)
- **`lib/services/media_service.dart`**: Media uploads to Supabase Storage (primary)

### State Management (Riverpod)
- **`lib/presentation/notifiers/lobby_notifier.dart`**: Lobby spots, timers, game-specific data, peacock queue (760 lines)
- **`lib/presentation/notifiers/game_notifier.dart`**: Game selection, IGDB integration, available games
- **`lib/presentation/notifiers/chat_notifier.dart`**: **Supabase Realtime** chat (messages, typing, presence) - 899 lines, Firebase references being migrated
- **`lib/presentation/notifiers/user_notifier.dart`**: User profiles, pinned games, blocks/bans
- **`lib/presentation/notifiers/system_notifier.dart`**: Theme, notifications, app settings
- **`lib/presentation/onboarding/onboarding_notifier.dart`**: Onboarding flow state (callsign, avatar, games, preferences)

### Onboarding System (NEW)
- **`lib/presentation/onboarding/onboarding_flow.dart`**: 4-page PageView with SmoothPageIndicator (sign-in, callsign/avatar, games, preferences)
- **`lib/presentation/onboarding/widgets/game_selection_screen.dart`**: Live IGDB search, popular games, 3-column grid, max 6 selections
- **`lib/presentation/onboarding/widgets/preferences_screen.dart`**: 2x2 grid (Voice Ready, Mic Always On, Late Night, Competitive/Chill slider)
- **`lib/presentation/onboarding/widgets/avatar_selection_widget.dart`**: 8 cyber presets with neon glow, upload capability
- **`lib/presentation/onboarding/widgets/matrix_rain_background.dart`**: Animated particle background for onboarding
- **`lib/presentation/onboarding/widgets/glass_card.dart`**: Reusable glassmorphic container component
- **`lib/presentation/onboarding/widgets/neon_button.dart`**: Animated button with pulsing glow effect

### Domain Entities (Freezed)
- **`lib/domain/entities/squad_state.dart`**: Immutable squad state with game-scoped data
- **`lib/domain/entities/chat_state.dart`**: Chat UI and message state
- **`lib/domain/entities/app_user.dart`**: User profile entity
- **`lib/domain/entities/message.dart`**: Chat message entity

### Chat System
- **`lib/chat/chat_screen.dart`**: Main chat UI with **Supabase Realtime** streams (primary), legacy Firestore references exist
- **`lib/chat/chat_groups_screen.dart`**: Chat groups list with TabBar (My Groups/Discover), invite code input with UUID validation, discover functionality
- **`lib/chat/chat_service.dart`**: Chat business logic, Supabase primary with SQLite offline cache (Firebase migration incomplete)
- **`lib/chat/sqlite_helper.dart`**: SQLite database for offline message caching
- **`lib/chat/link_preview.dart`**: URL detection, previews, inline video playback
- **`lib/chat/peacock_modal.dart`**: Peacock lobby notification system
- **`lib/chat/widgets/smart_reply_bottom_sheet.dart`**: AI-powered smart replies
- **`lib/chat/widgets/modern_message_bubble.dart`**: 2025-2026 message design with reactions, swipe-to-reply
- **`lib/chat/widgets/clip_message_bubble.dart`**: Glassmorphic clip bubble with pulsing play button
- **`lib/chat/widgets/clip_player_screen.dart`**: Full-screen clip player with custom controls, hype button, comments
- **`lib/presentation/widgets/group_create_sheet.dart`**: DraggableScrollableSheet for quick group creation (490 lines) with confetti, member suggestions, lobby presets
- **`lib/widgets/group_preview_card.dart`**: Group preview card component (182 lines) with masked invite code, member count, game icon, activity time

### Clips System (NEW)
- **`lib/presentation/notifiers/clip_notifier.dart`**: Clips feed state with pagination and Clip of the Day
- **`lib/screens/clips_screen.dart`**: Main clips screen in navigation (wraps ClipsTab)
- **`lib/squad_tab/widgets/clips_tab.dart`**: Vertical infinite scroll feed widget with pull-to-refresh
- **`lib/squad_tab/widgets/clip_feed_item.dart`**: Large 16:9 clip card with stats (views, hype)
- **`lib/services/clip_service.dart`**: Video compression via video_compress, Firebase Storage upload

### Services
- **`lib/services/grok_service.dart`**: xAI Grok API integration for smart replies
- **`lib/services/igdb_service.dart`**: IGDB API for game data
- **`lib/services/firestore_service.dart`**: Firestore CRUD operations (legacy, being migrated)
- **`lib/services/auth_service.dart`**: Firebase Auth wrapper (legacy, Supabase Auth is primary)
- **`lib/services/auth_service_BACKUP.dart`**: Firebase Auth backup file (needs deletion)
- **`lib/services/timer_service.dart`**: Client-side timer management
- **`lib/services/clip_service.dart`**: Video compression and Firebase Storage upload
- **`lib/services/cache_service.dart`**: State caching with TTL

### Backend
- **`backend/server.js`**: Express server with PostgreSQL, `/grok` and `/smart-replies` endpoints
- **`functions/index.js`**: Firebase Cloud Functions for server-side timer processing (legacy backup, Supabase pg_cron is primary)
- **`functions_archived_2025-12-06/`**: Archived Firebase functions backup

## Development Workflows

### Building & Running
```bash
# Flutter app
flutter pub get
flutter run

# Backend server
cd backend
npm install
npm start  # Port 8080

# Firebase Cloud Functions (required for timers)
cd functions
npm install
firebase deploy --only functions
```

## Build & Deployment
- **Android**: `flutter build apk` or `flutter build appbundle`
- **iOS**: `flutter build ipa` (requires manual dSYM inclusion for Agora SDK)
- **Web**: `flutter build web`
- **Functions**: `firebase deploy --only functions` (critical for timers)

## Key Patterns
- **UID-Based Users**: Firebase UIDs as source of truth, cached display names
- **Hybrid Chat Storage**: Firestore for real-time, SQLite for offline
- **Manager Pattern**: Dedicated notifiers for focused functionality
- **Async Error Handling**: Try-catch with SnackBar feedback
- **Haptic Feedback**: `HapticFeedback.lightImpact()` for interactions
- **Stream Cleanup**: Dispose subscriptions in `dispose()` methods
- **AI Integration**: Grok AI for smart replies and contextual responses

## Timer Management

### Dual Timer Processing
**Supabase pg_cron (Primary)**:
- Server-side PostgreSQL cron jobs run every 30 seconds
- `process_expired_timers()`: Frees spots, assigns to peacock queue, creates new timers
- `process_expired_queue()`: Cleans up expired peacock entries, rebalances positions
- Tables: `squad_timers`, `peacock_queue`, `squad_spots`
- Zero client-side processing required - fully automatic

**Firebase Cloud Functions (Backup)**:
- Runs `updateTimers` every 1 minute for legacy support
- Client-side timer state tracked in `LobbyState.spotTimerStates`

### Implementation
- **Supabase**: `lib/services/SUPABASE_TIMER_CRON.sql` (pg_cron setup)
- **Firebase**: `functions/index.js` scheduled function
- **Use Cases**: `process_timers.dart`, `start_spot_timer.dart`, `manage_peacock_queue.dart`
- **Critical**: Deploy both systems during transition period

## Key Features

### Chat Group Discovery & Invite System (NEW - December 2025)

**Overview**: Comprehensive group discovery and invite code functionality for chat groups.

#### Group Discovery UI
- **Location**: `lib/chat/chat_groups_screen.dart` with TabBar interface
- **Tabs**: 
  - "My Groups": User's joined groups
  - "Discover": Public groups with filtering
- **Features**:
  - Invite code input with neon border and UUID validation
  - Game-based filtering for discovered groups
  - Real-time group preview with member counts
  - Direct join with confirmation dialogs

#### GroupCreateSheet Widget
- **File**: `lib/presentation/widgets/group_create_sheet.dart` (490 lines)
- **Design**: DraggableScrollableSheet with BackdropFilter blur
- **Features**:
  - Group name TextField with neon cyan border
  - Friend suggestions from UserNotifier (top 3 friends)
  - GameTile display for game selection
  - "From Lobby" button for creating groups from current lobby members
  - Confetti celebration on successful creation
  - Error handling via ErrorHandlingService
- **State Management**: Watches userNotifierProvider, gameNotifierProvider, lobbyNotifierProvider
- **Theme**: Material 3 with dynamic neon accents

#### GroupPreviewCard Widget
- **File**: `lib/widgets/group_preview_card.dart` (182 lines)
- **Design**: Card with BackdropFilter glassmorphic effect
- **Display Elements**:
  - CircleAvatar with member count or game icon
  - Group name in Orbitron font
  - 3-line subtitle:
    1. Public/Private status and game name
    2. Activity time (relative "Active 2h ago" or formatted date)
    3. Masked invite code (shows last 4 characters: "••••-••••-••••-abc1")
  - Join button with neon glow
- **Animation**: `.animate().slideY()` entrance effect
- **Dependencies**: flutter_animate, google_fonts, intl

#### ChatNotifier Extensions
- **File**: `lib/presentation/notifiers/chat_notifier.dart` (573+ lines)
- **New Methods**:
  1. **`discoverGroups({String? gameFilter})`**:
     - Fetches public groups from ChatRepository
     - Sorts by memberCount DESC
     - Returns `List<ChatGroup>`
     - Optional game filtering
  
  2. **`joinGroupWithConfirmation(BuildContext context, String groupId)`**:
     - Shows AlertDialog with group details (name, member count, invite code)
     - Calls `_repository.joinGroup(groupId)`
     - Invalidates state with `ref.invalidateSelf()`
     - Error handling with SnackBar messages
  
  3. **`joinByInviteCode(BuildContext context, String code)`**:
     - Validates UUID format using regex: `r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'`
     - Fetches group via `_repository.getGroupByInviteCode(code)`
     - Shows error SnackBar if invalid or not found
     - Calls `joinGroupWithConfirmation` on success
  
  4. **`createPresetGroup({required String preset, required BuildContext context})`**:
     - Loads lobby member UIDs from LobbyNotifier
     - Auto-generates group name: "${gameName ?? 'Squad'} Chat"
     - Creates group with preset members
     - Updates state with `copyWith`

#### Repository Layer
- **Interface**: `lib/domain/repositories/chat_repository.dart`
  - Added `Future<ChatGroup?> getGroupByInviteCode(String code)`
  - Added `Future<List<ChatGroup>> discoverGroups({String? gameFilter})`
  - Added `Future<void> joinGroup(String groupId)`

- **Implementation**: `lib/data/repositories/chat_repository_impl.dart` (413+ lines)
  - **discoverGroups**: Calls remote datasource, caches locally via `_localDataSource.updateChatGroup`, offline fallback searches cached public groups sorted by memberCount
  - **getGroupByInviteCode**: Calls remote datasource, caches result, offline fallback searches local cache by inviteCode or id
  - **joinGroup**: Uses AuthServiceSupabase to get current user, calls remote datasource with user ID, comprehensive try-catch with error logging

#### Remote DataSource Layer
- **Interface**: `lib/data/datasources/chat_remote_datasource.dart`
  - Added `Future<ChatGroup?> getGroupByInviteCode(String code)`
  - Updated method signatures to include invite code support

- **Implementation**: `lib/data/datasources/chat_remote_datasource_impl.dart` (701+ lines)
  - **discoverGroups**: 
    ```dart
    SELECT *, invite_code, member_count:member_uids
    FROM chat_groups
    WHERE is_public = true
    ORDER BY member_count DESC
    LIMIT 20
    ```
    - Filters by game_name in metadata
    - Calculates member_count from array length
  
  - **getGroupByInviteCode**:
    ```dart
    SELECT *, invite_code
    FROM chat_groups
    WHERE invite_code = :code
    .maybeSingle()
    ```
    - Uses `.maybeSingle()` for safe nullable returns
    - Returns null if not found
  
  - **joinGroup**: 
    ```dart
    _supabase.rpc('append_group_member', {
      'group_id': groupId,
      'user_id': userId
    })
    ```
    - Fallback to manual array append if RPC fails
    - Comprehensive error handling with debugPrint

#### ChatGroup Entity Update
- **File**: `lib/domain/entities/chat_group.dart`
- **New Field**: `String? inviteCode` (line 18)
- **Serialization**: ✅ JSON serialization enabled
- **Code Generation**: build_runner executed to regenerate .freezed.dart and .g.dart files

#### Invite Code Security
- **Format**: UUID v4 (36 characters: 8-4-4-4-12 hexadecimal)
- **Display**: Masked to show only last 4 characters ("••••-••••-••••-abc1")
- **Validation**: Regex pattern enforces strict UUID format
- **Database**: Full code stored in Supabase with RLS policies
- **UI Safety**: `_getMaskedInviteCode()` helper in GroupPreviewCard

#### Offline-First Architecture
- **Pattern**: Try remote datasource → Fallback to local cache
- **Local Caching**: All groups cached via ChatLocalDataSource
- **Sync Strategy**: BackgroundSyncService handles offline operations
- **Realtime**: Supabase Realtime subscriptions for live updates

#### Integration Points
- **Navigation**: FloatingActionButton in ChatGroupsScreen opens GroupCreateSheet
- **State**: Riverpod providers for reactive UI updates
- **Error Handling**: ErrorHandlingService with user-friendly messages
- **Analytics**: Firebase Analytics events for group actions
- **Haptic Feedback**: `HapticFeedback.lightImpact()` on interactions

#### Usage Pattern Example
```dart
// Discover public groups
final groups = await ref.read(chatNotifierProvider.notifier).discoverGroups();

// Join by invite code
await ref.read(chatNotifierProvider.notifier).joinByInviteCode(context, 'abc-123-def');

// Create from lobby
await ref.read(chatNotifierProvider.notifier).createPresetGroup(
  preset: 'lobby',
  context: context
);
```

### Onboarding System (NEW - 2026 NEON VOID Theme)
- **4-Page Flow**: Sign-in → Callsign/Avatar → Game Selection → Preferences
- **Page 1 - Sign-In**: **Supabase Auth** - Apple Sign-In (secure nonce), Email/Password, pulsing neon buttons
- **Page 2 - Callsign/Avatar**: Text input + AvatarSelectionWidget with 8 cyber presets, upload capability, dynamic accent colors
- **Page 3 - Game Selection**: 
  - Glass search bar with neon cyan glow, live IGDB search (300ms debounce)
  - Horizontal scroll "Popular Now" row (15-20 games from assets + IGDB trending)
  - 3-column GridView with glassmorphic cards, game covers, Orbitron font
  - Selected chips bar at bottom (max 6), first selected auto-becomes primary (⭐)
  - Long-press chip to set as primary game
  - Saves to UserNotifier.pinnedGames and OnboardingNotifier
- **Page 4 - Preferences**: 2x2 grid (Voice Ready, Mic Always On, Late Night, Competitive/Chill slider), glitching "Enter the Void" button
- **Visual Style**: Matrix rain background, glassmorphic UI, neon cyan/magenta accents, Orbitron headings
- **State Management**: Riverpod OnboardingNotifier with Freezed immutable state, saves to **Supabase + Firestore** on completion
- **Navigation**: SmoothPageIndicator with WormEffect, skip button, deferred deep link handling

### Dynamic Theme System (NEW)
- **Color Extraction**: Automatically extracts dominant, vibrant, and accent colors from IGDB game cover art
- **Palette Generator**: Uses `palette_generator` package for image analysis
- **Instant Presets**: Fallback colors for 10+ popular games (Warzone green, Valorant red, Fortnite blue, etc.)
- **Smooth Transitions**: 600ms animated theme changes with cubic easing
- **Persistence**: Theme saved to SharedPreferences across app restarts
- **Auto-Sync**: Theme updates automatically when user selects a game
- **Color Enhancement**: Ensures vibrancy (saturation ≥0.5, lightness 0.4-0.7)
- **Performance**: 300ms debouncing, cached colors, async extraction
- **Material 3**: ColorScheme.fromSeed() generates harmonious palettes

### Modern UI Design (2025-2026)
- **Glassmorphic Effects**: BackdropFilter blur with subtle transparency
- **Neon Glow**: Dynamic glow effects matching game theme colors
- **Sharp Corners**: 10-16px border radius for modern aesthetic
- **Tinder-Style Discovery**: Card stack with swipe gestures and parallax
- **Spatial Audio UI**: Voice room with floating orbs and waveform visualizations
- **Modern Messages**: Sharp bubbles, swipe-to-reply, inline reactions
- **Google Fonts**: Orbitron (headings), Inter (body text)

### Lobby Management
- Multi-game support with game-scoped squad spots
- Dynamic spot allocation based on game max players
- Peacock queue system for lobby notifications
- Member blocks, bans, and daily vote system
- User ratings (daily and all-time) per squad member
- **Clips Tab**: Vertical feed with infinite scroll, Clip of the Day, auto-view tracking

### Chat System
- Real-time messaging via Supabase Realtime with offline SQLite caching
- **Chat Groups**: Create public/private groups via ChatNotifier.createGroup() → ChatRepository → Supabase
- **Group Management**: Join/leave groups, discover public groups, update settings, invite code system
- **Group Discovery**: TabBar UI with "My Groups" and "Discover" tabs, public group browsing with game filtering
- **Invite Codes**: UUID-based invite system with masked display (shows last 4 characters), direct join capability
- **Quick Group Creation**: DraggableScrollableSheet modal with confetti celebrations, member suggestions, lobby presets
- Rich media support: images, videos, audio messages, **gaming clips**
- iMessage-style reactions on messages
- Message pinning and media history viewer
- Typing indicators and online status
- Link previews with inline video playback
- Polls with voting and history
- **Clip Recording**: Video picker integration with compression and upload
- **Clip Player**: Full-screen player with hype reactions, threaded comments, share, auto-play next

### AI Integration
- xAI Grok-powered smart reply suggestions
- Context-aware chat assistance
- Backend endpoint at `/smart-replies` and `/grok`

### Game Integration
- IGDB API for game data and search
- Popular games preloaded from `assets/popular_games.json`
- Game pinning and availability scheduling
- Preferred modes and game-specific lobbies

### User Features
- Firebase Auth with UID-based system
- Profile images and display names
- Pinned games management
- Availability settings and scheduled times
- Deep linking (`codsquadapp://` scheme)
- Push notifications via FCM
- **Notification Settings**: Push controls, sound/vibration, quiet hours, alert types, game-specific muting (in ProfileTab)

### UI/UX
- Material 3 with dynamic theme colors extracted from game art
- Glassmorphic UI elements with blur and transparency
- Neon glow effects synchronized with game theme
- Smooth 600ms animated theme transitions
- Haptic feedback on interactions
- Platform-specific icons and assets (100+ PNG files)
- Onboarding flow for new users
- flutter_animate for micro-interactions

## Code Patterns & Best Practices

### UID-Based User System
- Firebase UIDs as source of truth for user identification
- Display names cached in `memberDisplayNames` map to avoid repeated lookups
- Helper functions: `getDisplayNameForUid(uid)` and `getUidForDisplayName(displayName)`
- Format: `uid_calling` for users claiming spots with timers

### Supabase Realtime + SQLite Offline Pattern
```dart
// Real-time from Supabase (Primary)
final stream = supabase
  .from('chat_messages')
  .stream(primaryKey: ['id'])
  .eq('chat_group_id', chatGroupId)
  .order('created_at', ascending: false)
  .limit(100);

// Offline caching to SQLite
await sqliteHelper.insertMessage(message.toMap());

// Pattern: Supabase Realtime (production) → SQLite (offline cache)
// Note: Firebase migration complete (Dec 2025)
// Firebase retained ONLY for analytics (firebase_analytics) and push notifications (firebase_messaging)
// All database operations (auth, real-time, storage) use Supabase PostgreSQL
```

### State Management with Riverpod
```dart
// Read state
final squadState = ref.watch(squadNotifierProvider);

// Update state (in notifier)
state = AsyncValue.data(squadState.copyWith(displayName: newName));

// Listen to changes (in widget)
ref.listen(squadNotifierProvider, (previous, next) {
  // React to state changes
});
```

### Error Handling
- Try-catch blocks with user-facing SnackBar messages
- `mounted` checks before `setState` in async operations
- StreamSubscription cleanup in `dispose()` methods
- Null safety with helper functions in `utils.dart`

### Performance Optimization
- State caching via `CacheService` with TTL (100ms default)
- Game-scoped data structures for multi-game support
- Lazy loading of media and message history
- Efficient Firestore queries with pagination

## App Flow

### Application Launch Sequence
1. **Initialization** (`main.dart`):
   - Load environment variables via flutter_dotenv
   - Initialize SharedPreferences for theme persistence
   - Initialize BackgroundSyncService for offline-first operations
   - Initialize Firebase (for analytics & messaging only)
   - Initialize Supabase with SupabaseService
   - Setup dependency injection via GetIt
   - Store IGDB and Grok API credentials (first run)
   
2. **Authentication Check** (`AuthWrapper` widget):
   - Watch Supabase auth state stream via `authStateProvider`
   - Show splash screen for minimum 1500ms
   - If user authenticated → sync to Supabase users table → proceed to OnboardingWrapper
   - If not authenticated → show `SetupScreen` (login/signup)

3. **Onboarding Check** (`OnboardingWrapper` widget):
   - Load UserNotifier and LobbyNotifier state
   - Show splash screen until both loaded (500ms transition delay)
   - Check if `userState.pinnedGames.isEmpty`
   - If empty → show `OnboardingFlow` (4 pages)
   - If has games → navigate to `/` (ChatGroupsScreen) via router

### Onboarding Flow (First-Time Users)
**4-Page PageView** with smooth animations:
- **Page 1**: Sign-in (Supabase Auth - Apple Sign-In, Email/Password)
- **Page 2**: Callsign input + AvatarSelectionWidget (8 cyber presets + upload)
- **Page 3**: GameSelectionScreen (IGDB search, popular games, max 6 selections, ⭐ primary game)
- **Page 4**: PreferencesScreen (Voice Ready, Mic Always On, Late Night, Competitive/Chill slider)
- **On completion**: Saves to Supabase users table → Navigate to `/` (ChatGroupsScreen)

### Main Navigation (GoRouter)
**Route-based navigation** (no bottom tabs, router handles all navigation):

| Route | Screen | Purpose |
|-------|--------|----------|
| `/` | `ChatGroupsScreen` | Default home - chat groups list |
| `/setup` | `SetupScreen` | Login/signup (Supabase Auth) |
| `/squad` | `LobbyTabScreen` | Lobby management with spots/timers |
| `/squad/:gameName` | `LobbyTabScreen` | Game-specific lobby |
| `/chat` | `ChatGroupsScreen` | Chat groups (same as `/`) |
| `/profile` | `ProfileTab` | User profile & settings |
| `/clips` | `ClipsScreen` | Clips feed |
| `/join` | `JoinLobbyScreen` | Join lobby by code (query param) |
| `/join/:code` | `JoinLobbyScreen` | Join lobby by code (path param) |

### Deep Linking
- **URI scheme**: `codsquadapp://`
- **Patterns**: Various routes (chat, join/{code}, squad/{gameName})
- **Implementation**: `AppLinks` package in `_SquadSyncAppState`
- **Handler**: `DeepLinkRouter.handleDeepLink()` with go_router integration
- **Authentication check**: Requires Supabase user session
- **Deferred navigation**: Uses `WidgetsBinding.instance.addPostFrameCallback` to avoid `_debugLocked` assertions
- **Initial link**: Handled via `_appLinks.getInitialLink()`
- **Streaming links**: `_appLinks.uriLinkStream` for runtime deep links

### Siri Shortcuts Integration
- **Method channel**: `com.example.codSquadApp/siri`
- **Supported action**: `sendMessage` - navigates to `/chat` if authenticated
- **Handler**: Platform channel in `_SquadSyncAppState.initState()`

## Data Architecture

### Game-Scoped Data
- `gameLobbySpots[gameName]`: List of UIDs claiming spots per game
- `gameSpotTimers[gameName]`: Timer data for each spot
- `gameStatuses[gameName]`: Per-game user statuses
- `globalStatuses`: User statuses across all games (Walking, Ready, etc.)
- Dynamic spot allocation based on `currentGame['maxSpots']`

### Supabase Tables (Primary - 25 Total)
**See `SUPABASE_FUNCTIONS_INVENTORY.md` for complete schema (updated Dec 12, 2025)**

Core Tables:
- **`users`**: User profiles with game preferences and friends
- **`lobbies`**: Gaming lobbies (formerly squads) with game_focus
- **`chat_groups`**: Chat groups with computed stats via `chat_groups_with_stats` view
- **`chat_messages`**: Chat messages with 10 RLS policies
- **`direct_messages`**: Direct messaging between friends
- **`friends`**: Friend relationships (bidirectional)
- **`friend_requests`**: Pending friend requests
- **`clips`**: Video clips with view/hype tracking
- **`user_settings`**: Per-user app settings
- **`blocks`**: User blocking system

Supporting Tables:
- **`chat_backgrounds`**: Custom chat backgrounds
- **`typing_status`**: Real-time typing indicators
- **`user_ratings`**: Ratings and reviews
- **`bans`**: Banned users
- **`lobby_spots`**: Current spot assignments
- **`peacock_queue`**: Lobby notifications

**RLS Policies**: 92 policies ensuring data security across 25 tables (see SUPABASE_FUNCTIONS_INVENTORY.md Dec 12 update)
**Views**: `chat_groups_with_stats` for computed message counts and last message times
**Functions**: 15+ PostgreSQL functions for friends, ratings, game data

### SQLite Tables (Offline Cache)
- **`messages`**: Cached chat messages for offline access
- **`groups_cache`**: Cached group data
- **`timers`**: Client-side timer state persistence

## Security & Environment

### Environment Variables (Backend)
```bash
# Supabase (Primary - Production Database)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=***  # Server-side admin access
SUPABASE_ANON_KEY=***          # Client-side public access

# PostgreSQL (Analytics)
DB_USER=postgres
DB_HOST=localhost
DB_NAME=squadsync
DB_PASSWORD=***
DB_PORT=5432

# xAI Grok API
XAI_API_KEY=***

# Agora (optional, voice disabled)
AGORA_APP_ID=***
AGORA_APP_CERTIFICATE=***
```

### Security Rules
- **Never commit credentials to version control**
- Use `backend/.env.example` as template
- **Supabase RLS policies**: 92 Row-Level Security policies enforced on 25 tables
  - Users can only read/write their own data
  - Lobby members can access lobby chat/data
  - Public read access for users table (display names)
  - Storage policies for media buckets (Dec 11 fixes)
- **Storage Buckets**: 5 buckets (avatars, backgrounds, clips, media, profile_images)
- **Backend auth**: Validates Supabase JWT tokens for protected endpoints
- **Schema Audit**: Use `lib/diagnostic/supabase_schema_audit.sql` for security verification

## Recent Refactoring

### Game Selection Component Consolidation (Dec 12, 2025)

**Objective**: Eliminate ~400 lines of duplicated game selection logic across 5 files following DRY principle.

**New Unified Components**:

1. **`lib/widgets/game_tile.dart`** (630 lines)
   - **Purpose**: Single source of truth for game display components
   - **Features**: 4 tile styles (grid, list, card, chip) via `GameTileStyle` enum
   - **Visual**: CachedNetworkImage, selection/primary state indicators, haptic feedback
   - **Replaces**: `lib/chat/widgets/game_selection_card.dart` (removed)

2. **`lib/widgets/game_search_delegate.dart`** (400 lines)
   - **Purpose**: Unified IGDB search functionality
   - **Features**: SearchDelegate implementation, 300ms debouncing, pinned games, popular games
   - **Integration**: GameNotifier for IGDB API, handles single/multi-select modes
   - **Consolidates**: Search logic from game_selector.dart, game_selection_screen.dart

3. **`lib/widgets/game_selection_widget.dart`** (540 lines, enhanced from 153)
   - **Purpose**: Configurable game selection UI for all contexts
   - **Configuration**: `isOnboarding`, `allowMultipleSelect`, `maxSelections`, `showMaxSpotSelector`, `tileStyle`
   - **Data Sources**: popular_games.json asset, IGDB trending games
   - **Callbacks**: `onGameSelected`, `onGamesSelected`, `onGameWithSpotsSelected`

**Refactored Delegate Files**:

4. **`lib/chat/game_selection_sheet.dart`** (50 lines, down from 341)
   - **Reduction**: 85% reduction
   - **Pattern**: Bottom sheet wrapper delegating to GameSelectionWidget
   - **Config**: `showMaxSpotSelector: true`, `tileStyle: GameTileStyle.list`

5. **`lib/lobbies_tab/widgets/game_selector.dart`** (120 lines, down from 495)
   - **Reduction**: 76% reduction
   - **Pattern**: Game logo display + GameSearchDelegate integration
   - **Preserved**: `getAssetName()` method for 200+ game asset mappings (backward compatibility)

6. **`lib/presentation/onboarding/widgets/game_selection_screen.dart`** (380 lines, down from 985)
   - **Reduction**: 61% reduction
   - **Pattern**: GameSelectionWidget with AI recommendations and bottom bar
   - **Config**: `isOnboarding: true`, `maxSelections: 6`, `tileStyle: GameTileStyle.card`
   - **Preserved**: AI recommendations A/B test, selected game chips, primary game designation

**Results**:
- **Net savings**: ~400 lines of code eliminated
- **Maintainability**: Single source of truth reduces future maintenance burden
- **Consistency**: Unified UI/UX across all game selection contexts
- **Flexibility**: Configuration-based approach supports new contexts without duplication

**Technical Details**:
- **State Management**: Riverpod with GameNotifier, UserNotifier, LobbyNotifier, OnboardingProvider
- **Entity**: Freezed `Game` model with IGDB fields (igdbId, coverUrl, summary, genres, platforms, maxSpots)
- **Caching**: GameLocalDataSource for IGDB results, popular_games.json for fallback
- **Theming**: Material 3 with AnimatedContainer transitions, haptic feedback
- **Type Safety**: Proper List<Object> → List<String> conversions for pinnedGames
- **Zero Errors**: All 6 files compile without errors after refactoring

## Testing

**Unit Tests**: `test/` directory with widget tests and component tests  
**Integration Tests**: `integration_test/` directory covering critical flows:
- Authentication (auth_test.dart)
- Lobby operations (lobby_test.dart)
- Chat messaging (chat_test.dart)
- Game selection (game_selection_test.dart)

**Mocks**: `test/mocks/integration_test_mocks.dart` (Mockito-generated)

## Current Development Status

### Active Work
- Voice room Agora RTC Engine integration
- iOS deployment with dSYM inclusion for Agora SDK
- Test coverage expansion