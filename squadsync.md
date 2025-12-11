# SquadSync — App Architecture Reference

**Last Updated**: December 11, 2025  
**Purpose**: Current architecture documentation and technical reference for SquadSync codebase

## Executive Overview

SquadSync is a Flutter-based squad gaming coordination app with **Clean Architecture + Riverpod state management**. Features **hybrid multi-database architecture** (Supabase primary + SQLite offline cache) for high-performance real-time features. Includes xAI Grok AI integration for smart replies and IGDB game data integration.

**Current Statistics**:
- **Total Dart Files**: 233 files
- **Total Lines of Code**: ~147,200 LOC (includes ~80,000 generated code)
- **Active Code**: ~42,200 LOC
- **Architecture**: Clean Architecture - Presentation → Domain → Data → Services
- **State Management**: Riverpod (10 notifiers, ~3,930 lines total)
- **Services**: 28 service classes for external APIs
- **Test Coverage**: test/ + integration_test/ folders (tests need repository pattern updates)

## Architecture

### Overview

**Pattern**: Clean Architecture with Riverpod State Management  
**Layers**: 4-tier architecture (Presentation → Domain → Data → Services)  
**Database Strategy**: Hybrid Multi-Database (Supabase + Firestore + SQLite)  
**State Management**: Riverpod (AutoDisposeAsyncNotifier + AsyncNotifier)

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│  Riverpod Notifiers (9 core) | UI Widgets | Screens        │
│        3,263 lines total across notifiers                   │
└─────────────────────┬───────────────────────────────────────┘
                      │ calls
┌─────────────────────▼───────────────────────────────────────┐
│                      DOMAIN LAYER                           │
│  Use Cases (46) | Repository Interfaces | Entities (Freezed)│
│        ~920 lines use cases (thin wrappers)                 │
└─────────────────────┬───────────────────────────────────────┘
                      │ implements
┌─────────────────────▼───────────────────────────────────────┐
│                       DATA LAYER                            │
│  Repository Implementations (5) | DataSources (Local+Remote)│
│        1,176 lines repositories                             │
└─────────────────────┬───────────────────────────────────────┘
                      │ uses
┌─────────────────────▼───────────────────────────────────────┐
│                     SERVICES LAYER                          │
│  External APIs | Utilities | Cross-Cutting Concerns (44)   │
│        ~15,000 lines total across services                  │
└─────────────────────────────────────────────────────────────┘
```

### Frontend
- **Framework**: Flutter 3.38.x with Dart SDK >=3.3.0
- **State Management**: Riverpod with `AutoDisposeAsyncNotifier` and `AsyncNotifier` for reactive state
- **UI Design**: Material 3 with dynamic theming, glassmorphic effects, neon glow accents (2025-2026 design)

#### Riverpod Notifiers (9 Core + 4 Specialized)

**Core State Notifiers** (AutoDisposeAsyncNotifier):

| Notifier | File | Lines | Responsibility | Database | Dependencies |
|----------|------|-------|----------------|----------|--------------|
| **ChatNotifier** | `chat_notifier.dart` | 927 | Chat messages, reactions, typing indicators, polls, media uploads | Supabase + Firestore + SQLite | 12 use cases + ChatService + ClipService |
| **SquadNotifier** | `squad_notifier.dart` | 509 | Squad spots, timers, peacock queue, member status | Supabase | 9 use cases + TimerServiceNotifier |
| **UserNotifier** | `user_notifier.dart` | 435 | User profiles, friends, pinned games, blocks/bans | Supabase | 7 use cases + FriendsService |
| **CurrentSquadNotifier** | `current_squad_notifier.dart` | 343 | Real-time active squad tracking with Supabase Realtime | Supabase Realtime | SupabaseClient direct |
| **ClipNotifier** | `clip_notifier.dart` | 305 | Clips feed, Clip of the Day, video content management | Supabase | SupabaseService |
| **GameNotifier** | `game_notifier.dart` | 150 | Game selection, IGDB integration, game lobbies | IGDB API + Cache | 4 use cases + GameLocalDataSource |
| **UserSquadsNotifier** | `user_squads_notifier.dart` | 104 | User squad memberships with real-time updates | Supabase Realtime | SupabaseClient direct |
| **SystemNotifier** | `system_notifier.dart` | 95 | Theme, notifications, analytics, bans, availability | Supabase + SharedPrefs | 9 use cases |
| **DiscoveryNotifier** | `discovery_notifier.dart` | 64 | Squad discovery, filters (hot/new/game), popular games | Supabase Realtime | SupabaseClient direct |

**Specialized Controllers**:

| Controller | Type | Lines | Purpose |
|------------|------|-------|---------|
| **GameThemeController** | StateNotifier | 421 | Dynamic theme color extraction from IGDB game covers |
| **OnboardingNotifier** | AutoDisposeAsyncNotifier | ~150 | Onboarding flow state (callsign, avatar, games, preferences) |
| **ChatStateNotifier** | StateNotifier | 207 | Chat UI ephemeral state (typing, recording) |
| **TimerServiceNotifier** | StateNotifier | 220 | Timer service state management |

**Total Notifier Lines**: 3,930 lines across 13 notifiers

**Current Issues**:
- ⚠️ **ChatNotifier too large** (927 lines) - needs splitting into MessageNotifier + PollNotifier + MediaNotifier
- ⚠️ **Squad state fragmented** - SquadNotifier + CurrentSquadNotifier + UserSquadsNotifier could be better organized
- ⚠️ **Direct DB access** - Some notifiers bypass repository layer (CurrentSquadNotifier, UserSquadsNotifier, DiscoveryNotifier)

**Strengths**:
- ✅ Clean separation of concerns for most notifiers
- ✅ Proper use of AsyncNotifier patterns
- ✅ Good error handling with user feedback

### Data Layer

**Architecture**: Repository Pattern with Local + Remote DataSources

#### Multi-Database Strategy

**Primary**: Supabase PostgreSQL
- Real-time subscriptions for chat, squads, presence
- Row Level Security (RLS) for data protection
- pg_cron for server-side timer processing (30-second intervals)
- Supabase Storage for media files

**Backup/Legacy**: Firebase Firestore
- Currently in transition/phaseout mode
- Some services still have Firestore references (VoiceService, VideoService, TimerService)
- Chat has dual-write capability (Supabase primary, Firestore fallback)
- **Migration Status**: 75% complete

**Offline Cache**: SQLite
- Message history caching via sqflite
- Timer persistence
- Game data caching
- Offline-first message queue

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
Supabase Realtime Stream → CurrentSquadNotifier
  → UI updates automatically via Riverpod
```

#### Data Layer Components

**Repositories** (5 implementations, 1,176 total lines):

| Repository | File | Lines | Interfaces | Databases Used |
|------------|------|-------|------------|----------------|
| **ChatRepositoryImpl** | `chat_repository_impl.dart` | 357 | `ChatRepository` | Supabase (primary) + SQLite (cache) |
| **UserRepositoryImpl** | `user_repository_impl.dart` | 269 | `UserRepository` | Supabase |
| **SystemRepositoryImpl** | `system_repository_impl.dart` | 218 | `SystemRepository` | Supabase + SharedPreferences |
| **SquadRepositoryImpl** | `squad_repository_impl.dart` | 201 | `SquadRepository` | Supabase |
| **GameRepositoryImpl** | `game_repository_impl.dart` | 131 | `GameRepository` | IGDB API + SQLite |

**DataSources** (15 files):

**Remote DataSources** (6 active):
- `chat_remote_datasource_impl.dart` - Supabase Realtime chat operations
- `user_remote_datasource.dart` - Supabase user operations
- `squad_remote_datasource.dart` - Supabase squad operations
- `system_remote_datasource.dart` - Supabase system operations  
- `game_remote_datasource.dart` - IGDB API integration
- `supabase_service.dart` - Supabase client initialization

**Local DataSources** (6 active):
- `chat_local_datasource_impl.dart` - SQLite message cache
- `user_local_datasource.dart` - SQLite/SharedPreferences user cache
- `squad_local_datasource.dart` - SQLite squad cache
- `system_local_datasource.dart` - SharedPreferences system settings
- `game_local_datasource.dart` - SQLite game cache
- `sqlite_helper.dart` - SQLite database management

**Legacy/Backup** (3 Firestore BACKUP files - being phased out):
- `chat_remote_datasource_impl_firestore_BACKUP.dart` (458 lines)
- `squad_remote_datasource_firestore_BACKUP.dart`
- `system_remote_datasource_firestore_BACKUP.dart`

**Total DataSource Lines**: ~3,500 lines (excluding BACKUP files)

### Domain Layer

**Purpose**: Business logic, entity definitions, repository interfaces (Clean Architecture core)

**Components**: 65 total files

#### Entities (21 files - Freezed Immutable)

**Primary State Entities** (with code generation):

| Entity | File | Purpose | Fields | Serialization |
|--------|------|---------|--------|---------------|
| **SquadState** | `squad_state.dart` + .freezed + .g | Squad state with game-scoped data | `gameSquadSpots`, `gameSpotTimers`, `peacockQueues`, `currentGame` | ✅ JSON |
| **ChatState** | `chat_state.dart` + .freezed | Chat UI and message state | `messages`, `groups`, `typingUsers`, `onlineUsers` | ❌ No JSON |
| **AppUser** | `app_user.dart` + .freezed + .g | User profile entity | `uid`, `displayName`, `profileImage`, `pinnedGames`, `friends` | ✅ JSON |
| **Squad** | `squad.dart` + .freezed + .g | Squad entity | `spots[]`, `spotTimers[]`, `viewers`, `statuses`, `isActive` | ✅ JSON |
| **Game** | `game.dart` + .freezed + .g | Game entity from IGDB | `id`, `name`, `cover`, `maxSpots`, `modes` | ✅ JSON |
| **Message** | `message.dart` + .freezed | Chat message entity | `id`, `content`, `senderId`, `timestamp`, `mediaUrl`, `reactions` | ❌ No JSON |
| **ChatGroup** | `chat_group.dart` + .freezed + .g | Chat group entity | `id`, `squadId`, `name`, `members`, `createdAt` | ✅ JSON |
| **SystemState** | `system_state.dart` + .freezed + .g | System settings entity | `themeMode`, `notificationSettings`, `lastSync` | ✅ JSON |

**Total Entity Lines**: ~2,500 lines (active code) + ~8,000 lines (generated .freezed.dart + .g.dart files)

**Current State**:
- ✅ All entities use freezed for immutability
- ✅ JSON serialization via json_serializable
- ⚠️ Some type inconsistencies (Lobby vs PublicSquad) need standardization

#### Repository Interfaces (5 files)

| Interface | File | Methods | Purpose |
|-----------|------|---------|---------|
| **ChatRepository** | `chat_repository.dart` | ~15 methods | Chat operations interface |
| **UserRepository** | `user_repository.dart` | ~10 methods | User operations interface |
| **SquadRepository** | `squad_repository.dart` | ~12 methods | Squad operations interface |
| **SystemRepository** | `system_repository.dart` | ~8 methods | System operations interface |
| **GameRepository** | `game_repository.dart` | ~6 methods | Game operations interface |

**Current Architecture**: Notifiers call repositories directly (Use Case layer removed for simplicity)

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

**Benefits**:
- ✅ Simpler architecture with fewer layers
- ✅ Less boilerplate code
- ✅ Direct repository calls show intent clearly
- ✅ Easier to maintain and understand

### Services Layer (28 Services)

**Purpose**: External API integration, utilities, cross-cutting concerns

**Total Lines**: ~15,000 lines across all services

#### Primary Services (Current State)

| Service | File | Lines | Responsibility | Database/API |
|---------|------|-------|----------------|--------------|
| **VideoService** | `video_service.dart` | 1,212 | Agora video SDK, screen sharing, beauty filters | Supabase + Agora SDK |
| **VoiceService** | `voice_service.dart` | 887 | Agora voice SDK, spatial audio, room management | Supabase + Agora SDK |
| **ChatUIManager** | `chat_ui_manager.dart` | 767 | Chat UI coordination, scrolling, message selection | N/A (UI state) |
| **MessageService** | `message_service.dart` | 677 | Message CRUD, AI integration, realtime subscriptions, typing indicators | Supabase + SQLite |
| **FriendsService** | `friends_service.dart` | 489 | Friend requests, friend list, DMs, game muting | Supabase |
| **TimerService** | `timer_service.dart` | 466 | Timer orchestration, spot timers, peacock timers | SQLite + Supabase |
| **BackgroundService** | `background_service.dart` | 461 | Background sync, notifications, WorkManager | N/A |
| **ClipService** | `clip_service.dart` | 370 | Video compression (ffmpeg_kit), Supabase upload | Supabase Storage |
| **IGDBService** | `igdb_service.dart` | 355 | IGDB API integration for game data | IGDB API |
| **MediaService** | `media_service.dart` | 276 | Media upload to Supabase Storage | Supabase Storage |
| **GrokService** | `grok_service.dart` | 242 | xAI Grok API integration for smart replies | xAI Grok API |
| **AuthServiceSupabase** | `auth_service_supabase.dart` | 228 | Supabase Auth (email, Google, Apple Sign-In) | Supabase Auth |

**Key Services**:
- **MessageService**: Consolidated messaging with realtime subscriptions, typing indicators, offline queue
- **FriendsService**: Complete friends system with DMs, requests, and game muting
- **ClipService**: Gaming clip upload with video compression
- **GrokService**: AI-powered smart replies using xAI Grok
- **AuthServiceSupabase**: Primary authentication (Google, Apple, Email)

**Architecture Notes**:
- Services handle external API integration and complex business logic
- Most services are focused and single-purpose
- Large services (VideoService, VoiceService) handle complex SDK integration

**Chat Subsystem Services** (8 files in `lib/chat/services/`):
- `chat_typing_manager.dart` (~100 lines) - Typing indicators
- `chat_online_status_manager.dart` (~90 lines) - Presence tracking
- `chat_initialization_service.dart` (137 lines) - Chat setup
- `chat_scroll_controller.dart` (~120 lines) - Scroll behavior
- `chat_media_handler.dart` (~150 lines) - Media attachments
- `reaction_service.dart` (~80 lines) - Reaction management
- `chat_message_search_delegate.dart` (~50 lines) - Search functionality

**All actively used** ✅

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

**Infrastructure** (8):
- BackgroundService (461 lines) - Background tasks
- TimerService (466 lines) - Timer management
- CacheService (~100 lines) - State caching with TTL
- SupabaseService (~200 lines) - Supabase client init
- NotificationService (~250 lines) - Push notifications
- SessionDebugHelper (~100 lines) - Session debugging

**Redundant Services** (3 - see CODE_REDUNDANCY_ANALYSIS.md):
- MessageService (507 lines) - Duplicates repository pattern
- SupabasePersistence (503 lines) - Duplicates ChatRemoteDataSource
- ChatService (391 lines) - Overlaps with repository layer

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

### Migration Progress Tracker

**Supabase Migration Status: 75% Complete**

| Component | Supabase | Firebase/Firestore | Status | Action Required |
|-----------|----------|-------------------|--------|-----------------|
| **Auth** | ✅ Primary (AuthServiceSupabase) | ⚠️ Backup compatibility | 75% | Remove Firebase Auth wrapper |
| **Chat Messages** | ✅ Primary (ChatRemoteDataSource) | ⚠️ Dual-write fallback | 80% | Remove Firestore fallback |
| **User Profiles** | ✅ Complete | ❌ None | 100% | ✅ Done |
| **Squads** | ✅ Primary | ⚠️ BACKUP files exist | 90% | Delete BACKUP files |
| **Timers** | ✅ pg_cron implemented | ⚠️ Cloud Functions backup | 75% | Remove Cloud Functions |
| **Media Storage** | ✅ Primary (Supabase Storage) | ⚠️ Firebase Storage refs | 70% | Complete MediaService migration |
| **Video Rooms** | ⚠️ Partial | ⚠️ Firestore room state | 50% | Migrate room state to Supabase |
| **Voice Rooms** | ⚠️ Partial | ⚠️ Firestore room state | 50% | Migrate room state to Supabase |
| **Friends System** | ✅ Complete (PostgreSQL) | ❌ None | 100% | ✅ Done |
| **Analytics** | ✅ PostgreSQL backend | ⚠️ Firebase Analytics | 80% | Optional - keep Firebase Analytics |

**Next Migration Steps**:
1. Complete VideoService/VoiceService migration (remove Firestore room state)
2. Remove Firebase Storage references from MediaService
3. Migrate TimerService fully to pg_cron (remove Cloud Functions)
4. Delete 3 BACKUP datasource files
5. Remove Firebase Auth compatibility layer
6. Update pubspec.yaml to remove unnecessary Firebase dependencies

**Estimated Completion**: 2-3 weeks (as of Dec 8, 2025)

## Codebase Statistics (December 8, 2025)

### File Distribution

**Total Dart Files**: 283 files  
**Total Lines of Code**: ~148,000 LOC (includes generated code)

| Directory | Files | Purpose | Average LOC/File |
|-----------|-------|---------|------------------|
| **chat/** | 60 | Chat system (screens, widgets, services, dialogs) | ~500 |
| **domain/** | 73 | Entities (21), repositories (4), use cases (46) | ~200 |
| **services/** | 32 | External APIs, utilities, cross-cutting concerns | ~470 |
| **squad_tab/** | 30 | Squad management UI (dialogs, widgets) | ~300 |
| **presentation/** | 23 | Notifiers, controllers, hooks, onboarding | ~400 |
| **data/** | 20 | Repositories (5), datasources (15) | ~250 |
| **screens/** | 14 | Main screens (discovery, clips, profile, etc.) | ~600 |
| **widgets/** | 12 | Shared widgets | ~200 |
| **models/** | 7 | Legacy models (includes duplicates) | ~300 |
| **core/** | 3 | App config, theme, dependency injection | ~400 |
| **managers/** | 1 | Notification manager | ~32 |
| **examples/** | 1 | Video service example | ~100 |

### Top 10 Largest Files

| File | Lines | Purpose | Notes |
|------|-------|---------|-------|
| `chat/screens/chat_info_screen.dart` | 3,186 | Chat info/settings screen | ⚠️ Very large - candidate for refactoring |
| `profile_tab.dart` | 1,653 | Profile tab with settings | Large but manageable |
| `chat/chat_screen.dart` | 1,571 | Main chat UI | Core feature - size justified |
| `domain/entities/chat_state.freezed.dart` | 1,439 | Generated freezed code | ✅ Auto-generated |
| `domain/entities/squad_state.freezed.dart` | 1,285 | Generated freezed code | ✅ Auto-generated |
| `chat/widgets/clip_player_screen.dart` | 1,218 | Full-screen clip player | Feature-rich video player |
| `services/video_service.dart` | 1,212 | Agora video SDK integration | Complex RTC logic |
| `chat/message_bubble.dart` | 1,172 | Message bubble component | ⚠️ Large - extract message types |
| `screens/video_room_screen.dart` | 1,133 | Video room UI | Complex RTC UI |
| `chat/dialogs/group_actions_dialog.dart` | 1,097 | Group management dialog | Feature-rich dialog |

### Code Composition

| Category | Lines | Percentage | Files |
|----------|-------|------------|-------|
| **Generated Code** (.freezed, .g) | ~80,000 | 54% | ~80 files |
| **Active Application Code** | ~42,600 | 29% | ~200 files | **-391 lines** (Dec 9) |
| **Test Code** | ~3,000 | 2% | ~25 files |
| **Documentation** (.md) | ~10,000 | 7% | ~30 files |
| **Configuration** (yaml, json, sql) | ~2,000 | 1% | ~50 files |
| **Other** (assets, build files) | ~10,000 | 7% | Various |

### Layer-by-Layer Breakdown

| Layer | Files | Lines | Percentage | Key Components |
|-------|-------|-------|------------|----------------|
| **Presentation** | 40 | ~5,200 | 12% | 13 notifiers, screens, onboarding |
| **Domain** | 73 | ~11,400 | 27% | 21 entities (~10,500 generated), 46 use cases |
| **Data** | 20 | ~4,676 | 11% | 5 repositories, 15 datasources |
| **Services** | 43 | ~14,600 | 34% | External APIs, utilities, chat services | **-1 file, -391 lines** |
| **UI/Widgets** | 106 | ~35,000 | 25% | Screens, widgets, dialogs, chat UI |

### State Management Distribution

| Type | Files | Lines | Purpose |
|------|-------|-------|---------|
| **Riverpod Notifiers** | 13 | 3,930 | Primary state management |
| **Freezed Entities** | 21 | ~10,500 | Immutable state entities (with generated code) |
| **Use Cases** | 46 | ~920 | Business logic wrappers |
| **Repositories** | 5 | 1,176 | Data access layer |

### Database Code Distribution

| Database | Files | Lines | Purpose | Status |
|----------|-------|-------|---------|--------|
| **Supabase** | ~30 | ~8,000 | Primary database operations | ✅ Active |
| **SQLite** | ~10 | ~2,500 | Offline caching | ✅ Active |
| **Firestore** | ~15 | ~5,000 | Backup/legacy operations | ⚠️ Being phased out |
| **BACKUP Files** | 3 | ~1,350 | Firestore legacy implementations | 🔴 Ready for deletion |

### Test Coverage

| Type | Files | Lines | Coverage Status |
|------|-------|-------|-----------------|
| **Unit Tests** | ~15 | ~2,000 | Basic coverage |
| **Integration Tests** | 3 | ~800 | Core flows covered |
| **Widget Tests** | ~7 | ~200 | Minimal coverage |
| **Total** | ~25 | ~3,000 | ⚠️ Needs improvement |

**Key Test Files**:
- `test/squad_notifier_test.dart` (243 lines)
- `test/game_notifier_test.dart` (290 lines)
- `test/user_notifier_test.dart` (149 lines)
- `test/pinned_carousel_test.dart` (103 lines)
- `integration_test/game_search_flow_test.dart`
- `integration_test/onboarding_flow_test.dart`
- `integration_test/squad_join_flow_test.dart`

### Dependencies Summary

**Key Package Categories**:

**State Management**:
- `riverpod` + `flutter_riverpod` + `hooks_riverpod`
- `freezed` + `freezed_annotation` (code generation)
- `json_serializable` (serialization)

**Database & Backend**:
- `supabase_flutter` (primary database)
- `cloud_firestore` (legacy/backup)
- `sqflite` (offline cache)
- `shared_preferences` (settings)

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

### Technical Debt Metrics

| Metric | Value | Assessment |
|--------|-------|------------|
| **Code Redundancy Level** | Medium-High | Chat services overlap with repositories |
| **Migration Completeness** | 75% | Firestore references remain in 4 services |
| **Largest File Size** | 3,186 lines | chat_info_screen.dart - needs refactoring |
| **Average Use Case Size** | 20 lines | Thin wrappers - architectural choice |
| **Duplicate Models** | 1 (Squad) | Critical issue - needs immediate fix |
| **BACKUP Files** | 3 files | Ready for deletion post-migration |
| **TODO Comments** | ~15 | Mostly migration-related |
| **Linter Ignores** | 6 incorrect | Minor code clarity issue |

### Architecture Health Score

| Category | Score | Notes |
|----------|-------|-------|
| **Clean Architecture Compliance** | 9/10 | Excellent layer separation, minor service overlap |
| **State Management Consistency** | 8/10 | Riverpod well-implemented, ChatNotifier too large |
| **Database Strategy** | 7/10 | Solid hybrid approach, migration incomplete |
| **Code Organization** | 8/10 | Well-structured folders, some large files |
| **Dependency Management** | 8/10 | GetIt properly used, some redundant wrappers |
| **Test Coverage** | 5/10 | Basic tests present, needs expansion |
| **Documentation** | 9/10 | Excellent inline and external documentation |
| **Migration Progress** | 7.5/10 | 75% complete, clear path forward |

**Overall Health Score**: 7.7/10 (GOOD with room for improvement)

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
├── main_navigation_screen.dart        # Main navigation container (4 tabs: Squad, Chat, Clips, Profile)
├── profile_tab.dart                   # User profile tab with notification settings
│
├── presentation/
│   ├── notifiers/                     # Riverpod state notifiers
│   │   ├── squad_notifier.dart        # Squad state (spots, timers, members)
│   │   ├── game_notifier.dart         # Game selection and IGDB data
│   │   ├── chat_notifier.dart         # Chat messages and UI state
│   │   ├── clip_notifier.dart         # Clips feed with pagination
│   │   ├── user_notifier.dart         # User profiles and preferences
│   │   ├── system_notifier.dart       # App settings and theme
│   │   ├── current_squad_notifier.dart # Active squad context
│   │   ├── user_squads_notifier.dart  # User squad memberships
│   │   └── discovery_notifier.dart    # Squad discovery
│   ├── controllers/
│   │   └── game_theme_controller.dart # Dynamic theme color extraction
│   ├── widgets/
│   │   └── animated_theme_wrapper.dart # Smooth theme transitions
│   └── hooks/
│       └── game_theme_sync.dart       # Auto-sync theme with game changes
│
├── domain/                            # Domain layer (clean architecture)
│   ├── entities/                      # Freezed immutable entities
│   │   ├── squad_state.dart           # Squad state entity
│   │   ├── chat_state.dart            # Chat state entity
│   │   ├── app_user.dart              # User entity
│   │   ├── squad.dart                 # Squad entity
│   │   ├── game.dart                  # Game entity
│   │   ├── message.dart               # Message entity
│   │   ├── chat_group.dart            # Chat group entity
│   │   └── system_state.dart          # System state entity
│   ├── repositories/                  # Repository interfaces
│   └── usecases/                      # Business logic use cases (43 files)
│       ├── send_message.dart
│       ├── process_timers.dart
│       ├── manage_peacock_queue.dart
│       └── ... (40 more)
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
│   ├── poll_*.dart                    # Poll components (3 files)
│   ├── dialogs/                       # Chat dialogs (6 files)
│   ├── services/                      # Chat services (7 files)
│   ├── models/                        # Chat data models
│   └── widgets/                       # Chat UI widgets (18 files)
│       ├── clip_message_bubble.dart   # Glassmorphic clip bubble
│       └── clip_player_screen.dart    # Full-screen clip player
│
├── squad_tab/                         # Squad management UI
│   ├── squad_tab.dart                 # Main squad tab (single view)
│   ├── squad_queue_page.dart          # Squad queue interface
│   ├── spot_widgets.dart              # Spot management UI
│   ├── peacock_widgets.dart           # Peacock UI components
│   ├── member_widgets.dart            # Member display widgets
│   ├── dialogs/                       # Squad dialogs (14 files)
│   ├── widgets/                       # Squad widgets (10 files)
│   │   ├── clips_tab.dart             # Clips feed widget (used in ClipsScreen)
│   │   ├── clip_feed_item.dart        # Large clip card for feed
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
│   ├── squad_detail_screen.dart       # Squad details
│   ├── profile_editing_screen.dart    # Edit profile
│   ├── availability_settings_screen.dart
│   ├── notifications_screen.dart.bak  # Archived (notifications now in ProfileTab)
│   ├── performance_stats_screen.dart
│   ├── splash_screen.dart
│   └── onboarding/                    # Complete onboarding system
│       ├── onboarding_flow.dart       # Main 4-page PageView coordinator
│       ├── onboarding_notifier.dart   # Riverpod state management
│       └── widgets/
│           ├── game_selection_screen.dart    # Page 3: Game selector with IGDB search
│           ├── preferences_screen.dart       # Page 4: 2x2 preferences grid
│           ├── avatar_selection_widget.dart  # Avatar picker with 8 presets
│           ├── matrix_rain_background.dart   # Animated particle background
│           ├── glass_card.dart               # Glassmorphic container
│           └── neon_button.dart              # Animated glowing button
│
├── widgets/                           # Shared widgets
│   ├── async_value_widget.dart        # Async state display
│   ├── game_selection_widget.dart     # Game selector
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
└── diagnostic/                        # Documentation
    ├── SQUADSYNC.md
    └── TESTING.md

doc/
├── agora_setup.md                     # Agora RTC setup guide
├── null_safety_guide.md               # Null safety migration guide
└── dynamic_theme_system.md            # Dynamic theme documentation

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

### Database Services (Dual-Mode)
- **`lib/services/supabase_service.dart`**: Supabase client initialization and helper methods
- **`lib/services/dual_database_service.dart`**: Complete dual-mode service (1,153 lines)
  - Dual-write: Write to both Supabase and Firebase
  - Supabase-first reads with automatic Firebase fallback
  - 31 methods covering users, squads, messages, typing, backgrounds, ratings
  - Real-time streams via `supabase.stream()` and Firestore snapshots
- **`lib/services/firestore_to_supabase_migrator.dart`**: Data migration tool (400 lines)
- **`lib/services/SUPABASE_SCHEMA.sql`**: PostgreSQL schema (8 tables, indexes, RLS policies, triggers)
- **`lib/services/SUPABASE_TIMER_CRON.sql`**: pg_cron timer processor (30-second intervals)
- **`lib/services/media_service.dart`**: Dual-mode media uploads to Supabase Storage + Firebase Storage

### State Management (Riverpod)
- **`lib/presentation/notifiers/squad_notifier.dart`**: Squad spots, timers, game-specific data, peacock queue
- **`lib/presentation/notifiers/game_notifier.dart`**: Game selection, IGDB integration, available games
- **`lib/presentation/notifiers/chat_notifier.dart`**: **Supabase Realtime** chat (messages, typing, presence) with Firebase fallback
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
- **`lib/chat/chat_screen.dart`**: Main chat UI with **Supabase Realtime** streams (primary) and Firestore fallback
- **`lib/chat/chat_service.dart`**: Chat business logic, **dual-mode** Supabase/Firestore + SQLite hybrid
- **`lib/chat/sqlite_helper.dart`**: SQLite database for offline message caching
- **`lib/chat/link_preview.dart`**: URL detection, previews, inline video playback
- **`lib/chat/peacock_modal.dart`**: Peacock lobby notification system
- **`lib/chat/widgets/smart_reply_bottom_sheet.dart`**: AI-powered smart replies
- **`lib/chat/widgets/modern_message_bubble.dart`**: 2025-2026 message design with reactions, swipe-to-reply
- **`lib/chat/widgets/clip_message_bubble.dart`**: Glassmorphic clip bubble with pulsing play button
- **`lib/chat/widgets/clip_player_screen.dart`**: Full-screen clip player with custom controls, hype button, comments

### Clips System (NEW)
- **`lib/presentation/notifiers/clip_notifier.dart`**: Clips feed state with pagination and Clip of the Day
- **`lib/screens/clips_screen.dart`**: Main clips screen in navigation (wraps ClipsTab)
- **`lib/squad_tab/widgets/clips_tab.dart`**: Vertical infinite scroll feed widget with pull-to-refresh
- **`lib/squad_tab/widgets/clip_feed_item.dart`**: Large 16:9 clip card with stats (views, hype)
- **`lib/services/clip_service.dart`**: Video compression via video_compress, Firebase Storage upload

### Services
- **`lib/services/grok_service.dart`**: xAI Grok API integration for smart replies
- **`lib/services/igdb_service.dart`**: IGDB API for game data
- **`lib/services/firestore_service.dart`**: Firestore CRUD operations
- **`lib/services/auth_service.dart`**: Firebase Auth wrapper
- **`lib/services/timer_service.dart`**: Client-side timer management
- **`lib/services/clip_service.dart`**: Video compression and Firebase Storage upload
- **`lib/services/cache_service.dart`**: State caching with TTL

### Backend
- **`backend/server.js`**: Express server with PostgreSQL, `/grok` and `/smart-replies` endpoints
- **`functions/index.js`**: Firebase Cloud Functions for server-side timer processing (runs every 1 minute)

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

### Testing
```bash
# Unit tests
flutter test

# Integration tests (files in integration_test/)
flutter test integration_test/

# Coverage
flutter test --coverage
```

### Deployment
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
- Client-side timer state tracked in `SquadState.spotTimerStates`

### Implementation
- **Supabase**: `lib/services/SUPABASE_TIMER_CRON.sql` (pg_cron setup)
- **Firebase**: `functions/index.js` scheduled function
- **Use Cases**: `process_timers.dart`, `start_spot_timer.dart`, `manage_peacock_queue.dart`
- **Critical**: Deploy both systems during transition period

## Key Features

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

### Squad Management
- Multi-game support with game-scoped squad spots
- Dynamic spot allocation based on game max players
- Peacock queue system for lobby notifications
- Member blocks, bans, and daily vote system
- User ratings (daily and all-time) per squad member
- **Clips Tab**: Vertical feed with infinite scroll, Clip of the Day, auto-view tracking

### Chat System
- Real-time messaging via Firestore with offline SQLite caching
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

### Hybrid Chat Storage (Dual-Mode + Offline)
```dart
// Real-time from Supabase (Primary)
final stream = supabase.from('messages')
  .stream(primaryKey: ['id'])
  .eq('chat_group_id', chatGroupId)
  .gt('timestamp_ms', lastSyncTimestamp)  // Delta sync
  .order('timestamp_ms', ascending: false)
  .limit(100);

// Fallback to Firestore
Stream<QuerySnapshot> getChatMessages() {
  return firestore.collection('chat')
    .orderBy('timestamp', descending: true)
    .limit(100)
    .snapshots();
}

// Offline caching to SQLite
await sqliteHelper.insertMessage(message.toMap());

// Pattern: Supabase Realtime (primary) → Firestore (fallback) → SQLite (offline)
```

### Dual-Write Pattern
```dart
// Write to both databases during transition
await Future.wait([
  supabase.from('messages').insert(messageData),
  firestore.collection('messages').add(messageData),
]);

// Read: Supabase first, Firebase fallback
final messages = await _trySupabase() ?? await _tryFirebase();
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

## Navigation Flow

### App Launch
1. `main.dart` initializes Firebase and checks auth state
2. If authenticated: `MainNavigationScreen` with bottom tabs
3. If not authenticated: `OnboardingFlow` (4 pages):
   - Page 1: Sign-in (Apple, Email, Google placeholder)
   - Page 2: Callsign input + AvatarSelectionWidget (8 presets + upload)
   - Page 3: GameSelectionScreen (IGDB search, popular games, max 6 selections)
   - Page 4: PreferencesScreen (Voice Ready, Mic Always On, Late Night, Competitive/Chill)
4. On completion: Saves to Firestore → Navigate to `MainNavigationScreen`

### Main Navigation (Bottom Tabs)
- **Squad Tab**: `SquadTabScreen` → `SquadQueuePage` (spots, timers, peacock)
- **Chat Tab**: `ChatGroupsScreen` → `ChatScreen` (messages, media, reactions)
- **Clips Tab**: `ClipsScreen` → Clips feed (infinite scroll, Clip of the Day)
- **Profile Tab**: `ProfileTab` (settings, games, availability, notification preferences)

### Deep Linking
- URI scheme: `codsquadapp://`
- Patterns: `codsquadapp://chat`, `codsquadapp://join/{code}`
- Handled in `main.dart` with authentication guards
- Deferred navigation via `WidgetsBinding.instance.addPostFrameCallback`

## Data Architecture

### Game-Scoped Data
- `gameSquadSpots[gameName]`: List of UIDs claiming spots per game
- `gameSpotTimers[gameName]`: Timer data for each spot
- `gameStatuses[gameName]`: Per-game user statuses
- `globalStatuses`: User statuses across all games (Walking, Ready, etc.)
- Dynamic spot allocation based on `currentGame['maxSpots']`

### Supabase Tables (Primary)
- **`messages`**: Chat messages with timestamp indexing, RLS policies per chat_group_id
- **`users`**: User profiles (Supabase UUID, display name, profile image, pinned games)
- **`squads`**: Squad data (members, games, settings)
- **`chat_groups`**: Chat group metadata (squad_id, name, created_at)
- **`chat_backgrounds`**: Custom chat backgrounds (user_id, background_url)
- **`typing_status`**: Real-time typing indicators (user_id, chat_group_id, is_typing)
- **`user_ratings`**: User ratings and reviews
- **`bans`**: Banned users tracking
- **`squad_timers`**: Spot timer state (spot_index, expires_at, claimed_by)
- **`peacock_queue`**: Peacock lobby queue (user_id, squad_id, expires_at)
- **`squad_spots`**: Current spot assignments per squad

### Firestore Collections (Backup)
- **`chat`**: Chat messages with timestamp indexing (backup)
- **`users`**: User profiles (Firebase UID → Supabase UUID mapping)
- **`squads`**: Squad data (members, games, settings)
- **`squads/{squadId}/clips`**: Clip messages with view/hype tracking
- **`chat_metadata`**: Group metadata (last read, typing indicators)
- **`peacocks`**: Active lobby notifications with expiration

### SQLite Tables (Offline Cache)
- **`messages`**: Cached chat messages for offline access
- **`groups_cache`**: Cached group data
- **`timers`**: Client-side timer state persistence

## Security & Environment

### Environment Variables (Backend)
```bash
# Supabase (Primary)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=***  # Server-side admin access
SUPABASE_ANON_KEY=***          # Client-side public access

# Firebase (Backup)
GOOGLE_CLOUD_CREDENTIALS={"type":"service_account",...}

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
- **Supabase RLS policies**: Row-Level Security enforced on all tables (see `SUPABASE_SCHEMA.sql`)
  - Users can only read/write their own data
  - Squad members can access squad chat/data
  - Public read access for users table (display names)
- **Firebase Storage rules**: `storage.rules` for media access control
- **Firestore security rules**: `firestore.rules` for backup database
- **Backend auth**: Validates Supabase JWT tokens for protected endpoints

## Current Status

### Completed
- ✅ **Supabase Migration**: Complete dual-database architecture (Supabase primary + Firebase backup)
- ✅ **Supabase Schema**: 8 tables with RLS policies, indexes, triggers, realtime publication
- ✅ **pg_cron Timers**: Server-side timer processing (30-second intervals)
- ✅ **Supabase Auth**: Apple Sign-In with secure nonce, email/password authentication
- ✅ **DualDatabaseService**: 1,153 lines, 31 methods for dual-write/Supabase-first reads
- ✅ **Supabase Realtime**: Chat streams with typing indicators and presence tracking
- ✅ Migrated to Riverpod with `AutoDisposeAsyncNotifier` and `AsyncNotifier`
- ✅ Clean architecture with domain/data/presentation layers
- ✅ xAI Grok AI integration for smart replies (grok-4.1-fast-latest)
- ✅ Hybrid Supabase + Firestore + SQLite chat storage
- ✅ Firebase Cloud Functions for backup timer processing
- ✅ IGDB game data integration
- ✅ Rich media chat (images, videos, audio, reactions, polls, **clips**)
- ✅ Peacock lobby notification system
- ✅ Deep linking support
- ✅ Material 3 theme system with dynamic color extraction
- ✅ Glassmorphic UI with neon glow effects (2025-2026 design)
- ✅ Tinder-style squad discovery with card swipes
- ✅ VoiceRoomScreen with spatial audio visualization
- ✅ ModernMessageBubble with swipe-to-reply and reactions
- ✅ GameThemeController with palette_generator integration
- ✅ AnimatedThemeWrapper with 600ms transitions
- ✅ Complete OnboardingFlow with 4 pages (NEON VOID theme 2026)
- ✅ GameSelectionScreen with live IGDB search, popular games, 3-column grid
- ✅ PreferencesScreen with 2x2 grid and glitching button effect
- ✅ AvatarSelectionWidget with 8 cyber presets and upload capability
- ✅ Matrix rain background and glassmorphic onboarding components
- ✅ **Clips System**: ClipService, ClipNotifier, ClipsTab, ClipFeedItem, ClipPlayerScreen
- ✅ **Chat Input Clip Support**: Video picker integration in plus menu
- ✅ **Clip Player**: Full-screen player with custom controls, hype button, threaded comments, share, auto-play
- ✅ **Clips Feed**: Vertical infinite scroll with pagination, pull-to-refresh, Clip of the Day
- ✅ **Navigation Restructure**: Clips moved to main nav (4 tabs), notifications integrated into ProfileTab
- ✅ **Notification Settings**: Comprehensive settings in ProfileTab (push, quiet hours, alert types, game muting)

### In Progress
- 🔄 Testing Supabase Auth login flow (Apple Sign-In + email/password)
- 🔄 Testing dual-database operations (write both, read Supabase-first)
- 🔄 Testing Supabase Realtime chat streams
- 🔄 Testing pg_cron timer processing
- 🔄 Integrating new UI components into main navigation
- 🔄 VoiceRoomScreen Agora RTC Engine integration
- 🔄 Replacing legacy MessageBubble with ModernMessageBubble
- 🔄 Adding DiscoverySwipeScreen to discovery flow

### Known Issues
- Voice room feature ready but requires Agora provider setup
- iOS deployment requires manual dSYM inclusion for Agora SDK
- Legacy `squad_state_notifier.dart` being phased out
- Some deprecation warnings for Flutter Color API (non-breaking)
- Firebase to Supabase data migration pending (see `firestore_to_supabase_migrator.dart`)

### Next Steps
- Test complete Supabase integration (auth, chat, timers)
- Run Firestore → Supabase data migration for existing users
- Monitor dual-database sync and performance
- Complete Material 3 theme branch merge
- Complete Agora RTC integration for voice room
- Expand test coverage for new UI components
- Performance profiling and optimization
- User testing of new discovery swipe interface