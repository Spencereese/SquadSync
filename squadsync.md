# SquadSync App Summary

## Overview
SquadSync is a Flutter-based squad gaming app that facilitates real-time coordination for gaming squads. It features hybrid data architecture with Firebase Firestore for real-time chat and local SQLite for offline caching. The app uses Riverpod for state management and integrates xAI's Grok AI for smart replies and chat assistance.

## Architecture

### Frontend
- **Framework**: Flutter 3.38.3 (latest stable)
- **State Management**: Riverpod with StateNotifier for reactive UI updates
- **Key Notifiers**:
  - `SquadNotifier`: Manages squad data, spots, timers, and alerts
  - `GameNotifier`: Handles game selection, IGDB integration, and available games
  - `ChatNotifier`: Manages chat messages and real-time updates
  - `UserNotifier`: User profiles, pinned games, and preferences
  - `SystemNotifier`: App-wide settings and theme

### Data Layer
- **Real-time Chat**: Firestore streams with StreamBuilder for live updates
- **Offline Caching**: SQLite for message history and offline access
- **Media Handling**: Firebase Storage with backend-generated signed URLs
- **External APIs**: IGDB for game data, Google Cloud Storage for media, xAI Grok API for AI assistance

### Backend
- **Server**: Node.js/Express with PostgreSQL for analytics
- **Cloud Functions**: Firebase Functions for server-side timer processing
- **Authentication**: Firebase Auth with UID-based user system
- **AI Integration**: xAI Grok API (model: grok-4.1-fast-latest) for smart replies and chat responses

## Key Files and Structure
- `lib/main.dart`: App initialization with Firebase and deep linking
- `lib/presentation/notifiers/`: Riverpod notifiers for state management
- `lib/squad_tab/`: Squad management UI components
- `lib/chat/`: Chat UI and services with Grok AI integration
- `lib/services/grok_service.dart`: xAI Grok AI integration service
- `lib/screens/`: Screen-level widgets and navigation
- `backend/server.js`: Express server with Grok API endpoints

## Development Workflows

### Building & Running
```bash
# Flutter app
flutter pub get
flutter run  # Auto-detects platform

# Backend
cd backend && npm install
npm start  # Runs on port 8080
```

### Testing
- Unit tests: `flutter test`
- Integration tests: Manual testing across platforms

### Firebase Cloud Functions Deployment
**Critical for server-side timers** - timers only work when functions are deployed:
```bash
# Deploy timer functions (required for background timer processing)
firebase deploy --only functions
```

## Key Patterns
- **UID-Based Users**: Firebase UIDs as source of truth, cached display names
- **Hybrid Chat Storage**: Firestore for real-time, SQLite for offline
- **Manager Pattern**: Dedicated notifiers for focused functionality
- **Async Error Handling**: Try-catch with SnackBar feedback
- **Haptic Feedback**: `HapticFeedback.lightImpact()` for interactions
- **Stream Cleanup**: Dispose subscriptions in `dispose()` methods
- **AI Integration**: Grok AI for smart replies and contextual responses

## Security
- Never commit credentials; use environment variables
- xAI API key stored securely in backend environment

## Current State
- ✅ Migrated to Riverpod notifiers, build successful
- ✅ Flutter updated to 3.38.3 (latest stable)
- ✅ Grok AI integration with grok-4.1-fast-latest model
- ✅ Smart replies endpoint implemented in backend
- ✅ Voice room temporarily disabled due to unmigrated provider
- ✅ Ready for iOS deployment with manual dSYM inclusion for Agora SDK
- ✅ Latest changes committed and pushed to main branch (master)