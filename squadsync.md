# SquadSync — App Intelligence Summary

## Overview
SquadSync is a Flutter-based squad gaming app for real-time coordination. Hybrid data architecture with Firebase Firestore for real-time chat and SQLite for offline caching. Riverpod-based state management with xAI Grok AI integration for smart replies.

## Architecture

### Frontend
- **Framework**: Flutter 3.x with Dart SDK >=3.3.0
- **State Management**: Riverpod with `AutoDisposeAsyncNotifier` and `AsyncNotifier` for reactive state
- **Key Notifiers**:
  - `SquadNotifier`: Squad data, spots, timers, alerts
  - `GameNotifier`: Game selection, IGDB integration, available games
  - `ChatNotifier`: Chat messages and real-time updates
  - `UserNotifier`: User profiles, pinned games, preferences
  - `SystemNotifier`: App-wide settings, theme
  - `CurrentSquadNotifier`: Current squad context
  - `UserSquadsNotifier`: User squad memberships
  - `DiscoveryNotifier`: Squad discovery state

### Data Layer
- **Real-time Chat**: Firestore streams with StreamBuilder
- **Offline Caching**: SQLite via sqflite for message history
- **Media Handling**: Firebase Storage with backend-generated signed URLs
- **External APIs**: IGDB for game data, xAI Grok API for AI assistance

### Backend
- **Server**: Node.js/Express with PostgreSQL for analytics
- **Cloud Functions**: Firebase Functions for server-side timer processing
- **Authentication**: Firebase Auth with UID-based user system
- **AI Integration**: xAI Grok API (grok-4.1-fast-latest) for smart replies and chat responses

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
├── main_navigation_screen.dart        # Main navigation container
├── profile_tab.dart                   # User profile tab
│
├── presentation/notifiers/            # Riverpod state notifiers
│   ├── squad_notifier.dart            # Squad state (spots, timers, members)
│   ├── game_notifier.dart             # Game selection and IGDB data
│   ├── chat_notifier.dart             # Chat messages and UI state
│   ├── user_notifier.dart             # User profiles and preferences
│   ├── system_notifier.dart           # App settings and theme
│   ├── current_squad_notifier.dart    # Active squad context
│   ├── user_squads_notifier.dart      # User squad memberships
│   └── discovery_notifier.dart        # Squad discovery
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
│   ├── grok_service.dart              # xAI Grok AI integration
│   ├── igdb_service.dart              # IGDB game data
│   ├── firestore_service.dart         # Firestore operations
│   ├── auth_service.dart              # Firebase Auth
│   ├── media_service.dart             # Media upload/download
│   ├── timer_service.dart             # Timer management
│   ├── poll_service.dart              # Poll creation/voting
│   ├── cache_service.dart             # State caching
│   └── ... (14 more services)
│
├── chat/                              # Chat system
│   ├── chat_screen.dart               # Main chat UI
│   ├── chat_service.dart              # Chat business logic
│   ├── chat_input_bar.dart            # Message input
│   ├── message_bubble.dart            # Message display
│   ├── sqlite_helper.dart             # SQLite offline cache
│   ├── link_preview.dart              # URL previews and inline video
│   ├── peacock_modal.dart             # Peacock queue modal
│   ├── poll_*.dart                    # Poll components (3 files)
│   ├── dialogs/                       # Chat dialogs (6 files)
│   ├── services/                      # Chat services (7 files)
│   ├── models/                        # Chat data models
│   └── widgets/                       # Chat UI widgets (18 files)
│
├── squad_tab/                         # Squad management UI
│   ├── squad_tab.dart                 # Main squad tab
│   ├── squad_queue_page.dart          # Squad queue interface
│   ├── spot_widgets.dart              # Spot management UI
│   ├── peacock_widgets.dart           # Peacock UI components
│   ├── member_widgets.dart            # Member display widgets
│   ├── dialogs/                       # Squad dialogs (14 files)
│   ├── widgets/                       # Squad widgets (7 files)
│   ├── managers/                      # Page navigation
│   └── mixins/                        # Keyboard handler mixin
│
├── screens/                           # Screen components
│   ├── add_game_screen.dart           # Add/manage games
│   ├── discovery_screen.dart          # Discover squads
│   ├── squad_detail_screen.dart       # Squad details
│   ├── profile_editing_screen.dart    # Edit profile
│   ├── availability_settings_screen.dart
│   ├── notifications_screen.dart
│   ├── performance_stats_screen.dart
│   ├── splash_screen.dart
│   └── onboarding/                    # Onboarding flow (2 files)
│
├── widgets/                           # Shared widgets
│   ├── async_value_widget.dart        # Async state display
│   ├── game_selection_widget.dart     # Game selector
│   ├── rating_widgets.dart            # Rating UI
│   └── ... (5 more widgets)
│
├── managers/                          # Legacy managers
│   └── notification_manager.dart
│
├── models/                            # Legacy models
│   └── poll.dart, squad.dart
│
├── core/                              # Core infrastructure
│   └── injection.dart                 # Dependency injection
│
└── diagnostic/                        # Documentation
    ├── SQUADSYNC.md
    └── TESTING.md

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
- **`lib/main.dart`**: App initialization, Firebase setup, deep link handling, navigation
- **`lib/app_theme.dart`**: Theme system with dark/light mode
- **`lib/utils.dart`**: Helper functions, safe null handling, formatters

### State Management (Riverpod)
- **`lib/presentation/notifiers/squad_notifier.dart`**: Squad spots, timers, game-specific data, peacock queue
- **`lib/presentation/notifiers/game_notifier.dart`**: Game selection, IGDB integration, available games
- **`lib/presentation/notifiers/chat_notifier.dart`**: Chat messages, typing indicators, media handling
- **`lib/presentation/notifiers/user_notifier.dart`**: User profiles, pinned games, blocks/bans
- **`lib/presentation/notifiers/system_notifier.dart`**: Theme, notifications, app settings

### Domain Entities (Freezed)
- **`lib/domain/entities/squad_state.dart`**: Immutable squad state with game-scoped data
- **`lib/domain/entities/chat_state.dart`**: Chat UI and message state
- **`lib/domain/entities/app_user.dart`**: User profile entity
- **`lib/domain/entities/message.dart`**: Chat message entity

### Chat System
- **`lib/chat/chat_screen.dart`**: Main chat UI with StreamBuilder for Firestore
- **`lib/chat/chat_service.dart`**: Chat business logic, Firestore/SQLite hybrid
- **`lib/chat/sqlite_helper.dart`**: SQLite database for offline message caching
- **`lib/chat/link_preview.dart`**: URL detection, previews, inline video playback
- **`lib/chat/peacock_modal.dart`**: Peacock lobby notification system
- **`lib/chat/widgets/smart_reply_bottom_sheet.dart`**: AI-powered smart replies

### Services
- **`lib/services/grok_service.dart`**: xAI Grok API integration for smart replies
- **`lib/services/igdb_service.dart`**: IGDB API for game data
- **`lib/services/firestore_service.dart`**: Firestore CRUD operations
- **`lib/services/auth_service.dart`**: Firebase Auth wrapper
- **`lib/services/timer_service.dart`**: Client-side timer management
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

### Spot Timers
- Game-scoped timers for claimed squad spots stored in `gameSpotTimers[gameName]`
- Firebase Cloud Functions process timers every minute via scheduled function
- Expired timers automatically free spots in Firestore
- Client-side timer state tracked in `SquadState.spotTimerStates`

### Peacock Timers
- Queue-based system for game lobby notifications stored in `peacockTimers`
- Server-side expiration removes entries from peacock queue
- Notifies squad members when lobbies are created
- Client-side timer state in `SquadState.peacockTimerStates`

### Implementation
- **Cloud Functions**: `functions/index.js` runs `updateTimers` every 1 minute
- **Use Cases**: `process_timers.dart`, `start_spot_timer.dart`, `manage_peacock_queue.dart`
- **Critical**: Functions must be deployed for timers to work (`firebase deploy --only functions`)

## Key Features

### Squad Management
- Multi-game support with game-scoped squad spots
- Dynamic spot allocation based on game max players
- Peacock queue system for lobby notifications
- Member blocks, bans, and daily vote system
- User ratings (daily and all-time) per squad member

### Chat System
- Real-time messaging via Firestore with offline SQLite caching
- Rich media support: images, videos, audio messages
- iMessage-style reactions on messages
- Message pinning and media history viewer
- Typing indicators and online status
- Link previews with inline video playback
- Polls with voting and history

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

### UI/UX
- Dark/light theme support
- Haptic feedback on interactions
- Custom app theme in `AppTheme`
- Platform-specific icons and assets
- Onboarding flow for new users

## Code Patterns & Best Practices

### UID-Based User System
- Firebase UIDs as source of truth for user identification
- Display names cached in `memberDisplayNames` map to avoid repeated lookups
- Helper functions: `getDisplayNameForUid(uid)` and `getUidForDisplayName(displayName)`
- Format: `uid_calling` for users claiming spots with timers

### Hybrid Chat Storage
```dart
// Real-time from Firestore
Stream<QuerySnapshot> getChatMessages() {
  return firestore.collection('chat')
    .orderBy('timestamp', descending: true)
    .limit(100)
    .snapshots();
}

// Offline caching to SQLite
await sqliteHelper.insertMessage(message.toMap());

// Pattern: Firestore for real-time, SQLite for offline access
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
3. If not authenticated: `SetupScreen` for login/signup
4. First-time users: `OnboardingFlow` → `ProfileSetupScreen` → `AddGameScreen`

### Main Navigation (Bottom Tabs)
- **Squad Tab**: `SquadTabScreen` → `SquadQueuePage` (spots, timers, peacock)
- **Chat Tab**: `ChatGroupsScreen` → `ChatScreen` (messages, media, reactions)
- **Discovery**: `DiscoveryScreen` (find and join squads)
- **Profile**: `ProfileTab` (settings, games, availability)

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

### Firestore Collections
- **`chat`**: Chat messages with timestamp indexing
- **`users`**: User profiles (UID, display name, profile image, pinned games)
- **`squads`**: Squad data (members, games, settings)
- **`chat_metadata`**: Group metadata (last read, typing indicators)
- **`peacocks`**: Active lobby notifications with expiration

### SQLite Tables
- **`messages`**: Cached chat messages for offline access
- **`groups_cache`**: Cached group data
- **`timers`**: Client-side timer state persistence

## Security & Environment

### Environment Variables (Backend)
```bash
# Firebase
GOOGLE_CLOUD_CREDENTIALS={"type":"service_account",...}

# PostgreSQL
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
- Never commit credentials to version control
- Use `backend/.env.example` as template
- Firebase Storage rules in `storage.rules`
- Firestore security rules in `firestore.rules`
- Backend validates Firebase auth tokens for protected endpoints

## Current Status

### Completed
- ✅ Migrated to Riverpod with `AutoDisposeAsyncNotifier` and `AsyncNotifier`
- ✅ Clean architecture with domain/data/presentation layers
- ✅ xAI Grok AI integration for smart replies (grok-4.1-fast-latest)
- ✅ Hybrid Firestore + SQLite chat storage
- ✅ Firebase Cloud Functions for server-side timers
- ✅ IGDB game data integration
- ✅ Rich media chat (images, videos, audio, reactions, polls)
- ✅ Peacock lobby notification system
- ✅ Deep linking support

### Known Issues
- Voice room feature temporarily disabled (unmigrated Agora provider)
- iOS deployment requires manual dSYM inclusion for Agora SDK
- Legacy `squad_state_notifier.dart` being phased out

### Next Steps
- Complete migration from legacy state management
- Re-enable voice room with Riverpod integration
- Expand test coverage beyond basic unit tests
- Performance profiling and optimization