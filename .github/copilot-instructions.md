# SquadSync AI Coding Guidelines

## Security Requirements
**CRITICAL**: Never commit credentials to version control. Use environment variables for all secrets:
- Firebase service account credentials: `GOOGLE_CLOUD_CREDENTIALS` environment variable
- Database credentials: `DB_USER`, `DB_HOST`, `DB_NAME`, `DB_PASSWORD`, `DB_PORT`
- Reference `backend/.env.example` for required environment variables

## Architecture Overview
SquadSync is a Flutter-based lobby gaming app with clean architecture:
- **Frontend**: Flutter app using Riverpod for state management with `AutoDisposeAsyncNotifier` and `AsyncNotifier`
- **Data Layer**: Supabase PostgreSQL for real-time data + SQLite for offline caching
- **Backend**: Node.js/Express with PostgreSQL for analytics, xAI Grok API integration for smart replies
- **State Management**: Riverpod notifiers (12 total) with freezed entities and repository pattern

## Key Patterns & Conventions

### State Management
- **Riverpod Notifiers**: All state managed via `AutoDisposeAsyncNotifier<T>` or `AsyncNotifier<T>`
  - `LobbyNotifier`: Lobby spots, timers, game-specific statuses, peacock queue
  - `GameNotifier`: Game selection, IGDB integration, available games
  - `ChatNotifier`: Chat messages, typing indicators, media handling
  - `UserNotifier`: User profiles, pinned games, blocks, bans
  - `SystemNotifier`: Theme, notifications, app settings
  - `CurrentLobbyNotifier`: Active lobby context
- **State Entities**: Freezed immutable entities (`LobbyState`, `ChatState`, `AppUser`, `Squad`, `Game`, `Message`, `SystemState`)
- **Repository Pattern**: Domain layer with use cases, repositories interface in `lib/domain/`, implementations in `lib/data/`
- **Reactive UI**: Consumers and providers for reactive updates

### Data Flow
- **Real-time data**: Supabase Realtime streams for live updates (chat, lobbies, presence)
- **Offline storage**: SQLite (`lib/chat/sqlite_helper.dart`) caches messages for offline access
- **State persistence**: SharedPreferences for user settings and app state
- **Media handling**: Supabase Storage with RLS policies

### Supabase Integration
- **Auth**: Supabase Auth with Apple Sign-In, Email/Password (`AuthServiceSupabase`)
- **Database**: 25 tables with 92 Row Level Security policies
- **Realtime**: Live subscriptions for chat, lobbies, typing indicators, presence
- **Storage**: 5 buckets (avatars, clips, media, chat_backgrounds, squadsync-media) with 20 storage policies
- **Functions**: 15+ PostgreSQL functions for friends, ratings, game data
- **Triggers**: 15 database triggers for timestamp updates, message handling
- **pg_cron**: Server-side timer processing every 30 seconds

### Firebase (Analytics Only)
- **firebase_analytics**: User analytics and event tracking
- **firebase_messaging**: Push notifications (FCM)

### External API Integration
- **IGDB API**: Game data via `GameNotifier`
- **xAI Grok API**: Smart replies and chat assistance (grok-4.1-fast-latest model)
- **PostgreSQL**: Analytics backend
- **App Links**: Deep linking (`codsquadapp://` scheme)

### UID-Based User System
- **Always use UIDs internally**: Supabase Auth UIDs are the source of truth for user identification
- **Display name caching**: Cache display names in `_memberDisplayNames` to avoid repeated lookups
- **UID conversion**: Use `getDisplayNameForUid(uid)` and `getUidForDisplayName(displayName)` for conversions
- **Calling UIDs**: Format `uid_calling` for users claiming spots with timers

### Manager Pattern with ChangeNotifier
- **Direct manager access**: Use `Provider.of<UserManager>(context, listen: false)` for immediate operations
- **Consumer widgets**: Wrap UI sections with `Consumer<UserManager>` for reactive updates
- **notifyListeners()**: Always call after state changes to trigger UI rebuilds
- **Async operations**: Handle async manager methods with proper error handling and mounted checks

### File Structure
- `lib/chat/`: Chat UI components and services
- `lib/chat/link_preview.dart`: URL detection, link previews, and inline video playback
- `lib/`: Main app screens (lobby_tab, settings_tab, etc.)
- `lib/managers/`: Dedicated manager classes for state management
- `lib/screens/`: Screen-level widgets and navigation
- `lib/lobby_tab/`: Lobby management UI components
- `backend/`: Node.js server with Express routes
- `functions/`: Firebase Cloud Functions for server-side timers
- `assets/`: Extensive icon set (100+ PNG files) referenced in pubspec.yaml
- `test/`: Comprehensive test suite with integration tests

### Common Patterns
- **Error handling**: Try-catch with `ScaffoldMessenger` snackbars for user feedback
- **Loading states**: `CircularProgressIndicator` during async operations
- **Haptic feedback**: `HapticFeedback.lightImpact()` for user interactions
- **Deep linking**: App Links integration for external message sending
- **Text cleaning**: `_cleanText()` method in ChatScreen for emoji/garbled text fixes
- **Link previews**: Automatic detection and preview of URLs in messages using `LinkDetector` and `LinkPreviewWidget`
- **Inline video playback**: Videos play directly in chat with custom controls using `VideoLinkPreview`
- **Mounted checks**: Always check `mounted` before setState in async operations
- **Stream cleanup**: Dispose StreamSubscriptions in `dispose()` methods
- **Null safety enforced with safe helpers in utils.dart (e.g., safeDisplayName ?? 'Unknown') to prevent String? errors**

## Development Workflows

### Building & Running
```bash
# Flutter app
flutter pub get
flutter run  # Auto-detects platform

# Backend
cd backend && npm install
npm start  # Runs on port 8080

# Docker deployment
docker build -t squadsync-backend backend/
docker run -p 8080:8080 squadsync-backend
```

### Database Timer Setup (Supabase pg_cron)
**Server-side timers run automatically** - no deployment needed:
- Supabase pg_cron configured in `lib/services/SUPABASE_TIMER_CRON.sql`
- Runs `process_expired_timers()` and `process_expired_queue()` every 30 seconds
- Fully automatic - no client-side timer management required
- See SUPABASE_FUNCTIONS_INVENTORY.md for complete timer documentation

### Testing
- Unit tests: `flutter test` (basic test suite available in `test/chat_service_test.dart`)
- Integration: Manual testing across platforms (Android/iOS/Web/Desktop)
- Firebase emulator for local development
- **Test file naming**: Use descriptive names like `peacock_modal_test.dart`, `chat_service_test.dart`
- **Widget testing**: Extensive use of `testWidgets()` for UI component testing
- **Mock dependencies**: Use `mockito` for Firebase and external service mocking

### Android Build Troubleshooting
- **AGP Version Conflicts**: Update `android/settings.gradle.kts` and `android/build.gradle` to AGP 8.9.1+
- **Gradle Version**: Ensure `gradle/wrapper/gradle-wrapper.properties` uses Gradle 8.11.1+
- **Desugar JDK Libs**: Update to version 2.1.4+ in `android/app/build.gradle.kts`
- **Clean Build**: Run `flutter clean` before building after version updates

### Deep Link Handling
- **App Links setup**: Initialize in `main.dart` with authentication/squad checks
- **URI patterns**: `codsquadapp://chat`, `codsquadapp://join/{code}`
- **Navigation guards**: Check `FirebaseAuth.instance.currentUser` and `squadState.selectedSquadId`
- **Deferred navigation**: Use `WidgetsBinding.instance.addPostFrameCallback` to avoid `_debugLocked` assertion

### Hybrid Chat Storage Pattern
```dart
// Real-time from Supabase
final stream = supabase
  .from('chat_messages')
  .stream(primaryKey: ['id'])
  .eq('chat_group_id', chatGroupId)
  .order('created_at', ascending: false)
  .limit(100);

// Offline caching to SQLite
Future<void> _cacheMessageToSQLite(Message message) async {
  await _sqliteHelper.insertMessage(message.toMap());
}

// Sync pattern: Supabase for real-time, SQLite for offline access
// Always check SQLite cache first, then sync with Supabase
```

### Server-Side Timer Functions
- **Primary**: Supabase pg_cron runs every 30 seconds (automatic, server-side)
- **Background processing**: PostgreSQL functions handle timer expiration
- **Spot expiration**: `process_expired_timers()` frees claimed spots, assigns to peacock queue
- **Peacock cleanup**: `process_expired_queue()` removes expired peacock entries
- **Zero client work**: Fully automatic server-side processing

### State Caching Optimization
```dart
// Cache with 100ms validity to avoid expensive recalculations
List<String?> get squadSpots {
  return cacheService.getOrCompute('squadSpots', () {
    final gameName = currentGame?['name'] ?? '';
    final rawSpots = gameSquadSpots[gameName] ?? [];
    return rawSpots
        .map((uid) => uid != null ? getDisplayNameForUid(uid) : null)
        .toList();
  });
}
```

## Code Style Notes
- Extensive use of `mounted` checks before setState in async operations
- Provider listeners disposed in `dispose()` methods
- Firebase streams properly managed with StreamSubscription cleanup
- **Theme System**: Material 3 with dynamic color seeds in `lib/core/app_theme.dart`
  - Always use `Theme.of(context).colorScheme` for colors
  - Semantic helpers: `AppTheme.success()`, `AppTheme.warning()`, `AppTheme.info()`
  - Glassmorphic widgets with `theme.glassyCard()` extension
  - Neon glow effects with `color.neonGlow()` extension
  - **NEVER hardcode colors** - always reference theme
- UID-to-display-name caching for performance
- Game-scoped data structures for multi-game support
- **Async error handling**: Always wrap async operations in try-catch with user feedback
- **Haptic feedback**: Use `HapticFeedback.lightImpact()` for user interactions
- **SnackBar messaging**: Use `ScaffoldMessenger.of(context).showSnackBar()` for user notifications
- **StreamBuilder patterns**: Extensive use for real-time Firebase data updates

## Key Files to Reference
- `lib/main.dart`: App initialization with Supabase and deep linking
- `lib/core/app_theme.dart`: Material 3 theme system with dynamic colors and extensions
- `lib/presentation/controllers/game_theme_controller.dart`: Dynamic theme from game covers
- `lib/presentation/widgets/animated_theme_wrapper.dart`: Smooth theme transitions
- `lib/presentation/notifiers/`: 12 Riverpod notifiers for state management
  - `message_notifier.dart`: Core messaging with real-time Supabase streams
  - `media_notifier.dart`: Media uploads, polls, clips
  - `lobby_notifier.dart`: Lobby state, spots, timers
  - `connectivity_notifier.dart`: Offline-first sync coordination
- `lib/chat/chat_screen.dart`: Main chat UI with Supabase Realtime
- `lib/data/repositories/`: Repository implementations
- `lib/diagnostic/SUPABASE_FUNCTIONS_INVENTORY.md`: Complete database schema reference
- `backend/server.js`: Express routes for Grok AI and analytics
- `pubspec.yaml`: Dependencies and asset declarations
- `test/`: Test suite (needs expansion)</content>
<parameter name="filePath">c:\Users\PC\cod_squad_app\.github\copilot-instructions.md