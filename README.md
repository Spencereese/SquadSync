# SquadSync - Squad Gaming App

A Flutter-based squad gaming app with real-time chat, spot management, and server-side timer functionality.

## Features

- **Real-time Chat**: Firebase-powered messaging with offline caching
- **Spot Management**: Claim and manage gaming spots with automatic timers
- **Peacock Queue**: Fair queue system for spot assignments
- **Server-side Timers**: Timers continue running even when the app is closed
- **Cross-platform**: Android, iOS, Web, Desktop support

## Architecture

- **Frontend**: Flutter with Provider state management
- **Backend**: Firebase (Auth, Firestore, Storage, Cloud Functions)
- **Local Storage**: SQLite for offline message caching
- **Server-side Timers**: Firebase Cloud Functions handle timer logic 24/7

## Server-side Timers

Timers now run continuously via Firebase Cloud Functions:

1. **Spot Timers**: Automatically free up claimed spots when time expires
2. **Peacock Timers**: Remove players from queue when their time runs out
3. **Background Processing**: Functions run every minute regardless of app state

### Deploying Timer Functions

```bash
# Run the deployment script
deploy_functions.bat

# Or manually:
cd functions
npm install
firebase deploy --only functions
```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
