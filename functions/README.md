# Firebase Cloud Functions for SquadSync

This directory contains Firebase Cloud Functions that handle server-side timer functionality for the SquadSync app.

## Setup

1. Install dependencies:
   ```bash
   cd functions
   npm install
   ```

2. Deploy functions:
   ```bash
   firebase deploy --only functions
   ```

## Functions

### updateTimers
- **Trigger**: Scheduled to run every 1 minute
- **Purpose**: Updates spot timers and peacock timers server-side
- **Behavior**:
  - Checks all active timers in Firestore
  - Removes expired spot timers and frees up spots
  - Removes expired peacock timers
  - Updates the squad state document with cleaned timer data

## How It Works

Previously, timers only ran when the Flutter app was active. Now:

1. **Client-side**: App displays timer UI and syncs with server state
2. **Server-side**: Cloud Functions run every minute to update timer state in Firestore
3. **Real-time sync**: All clients receive updates via Firestore listeners

This ensures timers continue running even when no users have the app open.

## Configuration

- **Schedule**: Every 1 minute via Pub/Sub
- **Runtime**: Node.js 18
- **Dependencies**: firebase-admin, firebase-functions