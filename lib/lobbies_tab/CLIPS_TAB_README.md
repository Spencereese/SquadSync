# Clips Tab Feature

## Overview
The **Clips Tab** adds a vertical infinite-scroll feed of clips to the SquadTabScreen, displayed alongside the existing Squad tab using a TabBar interface.

## Architecture

### Components

#### 1. **ClipNotifier** (`lib/presentation/notifiers/clip_notifier.dart`)
Manages clips state with Riverpod `AutoDisposeAsyncNotifier`:
- **Real-time streaming** from Firestore `squads/{squadId}/clips` collection
- **Pagination** with 10 clips per page
- **Clip of the Day** logic (manual or most hyped in last 24h)
- **View tracking** - increments view count when clip appears

```dart
final clipNotifierProvider = AutoDisposeAsyncNotifierProvider<ClipNotifier, ClipState>(...);
```

**Key Methods:**
- `initializeClipsStream(squadId)` - Start real-time clip feed
- `loadMoreClips()` - Paginate next page
- `refreshClips()` - Pull to refresh
- `markClipAsViewed(clipMessageId)` - Increment view count
- `setClipOfTheDay(clipMessageId)` - Manually pin clip of the day

#### 2. **ClipFeedItem** (`lib/squad_tab/widgets/clip_feed_item.dart`)
Large feed item widget for clips (similar to ClipMessageBubble but optimized for feed):
- **16:9 aspect ratio** with cached thumbnail
- **Glassmorphic overlay** with gradient
- **Pulsing play button** (NEON VOID style)
- **Author info** at bottom with name, timestamp
- **Stats row**: Hype button (🔥) + view count (👁️)
- **Auto-view tracking** - calls `onView()` callback on appear
- Opens **ClipPlayerScreen** on tap with full squad clips for auto-play

#### 3. **ClipsTab** (`lib/squad_tab/widgets/clips_tab.dart`)
Main feed UI with infinite scroll:
- **RefreshIndicator** for pull-to-refresh
- **Pinned "Clip of the Day"** section at top (bordered with game color)
- **CustomScrollView** with SliverList for clips
- **Empty state**: "No clips yet... drop the first one 🔥" (neon text)
- **Loading indicator** at bottom during pagination
- **End of list** message when no more clips

#### 4. **SquadTab Integration** (`lib/squad_tab/squad_tab.dart`)
Added TabBar with Squad and Clips tabs:
- **TabController** manages 2 tabs
- **Neon-styled TabBar** with game color highlights
- **TabBarView** with:
  - Tab 0: Existing squad management UI
  - Tab 1: New ClipsTab feed
- Keeps existing FloatingActionButton for spot claiming

## Usage

### Viewing Clips Feed
1. Navigate to any squad with a game selected
2. Tap the **"Clips"** tab at the top
3. Scroll vertically through clips
4. Pull down to refresh
5. Tap any clip to open full-screen player

### Clip of the Day
- **Automatic**: Most hyped clip in last 24 hours
- **Manual**: Admin can set via Firestore:
  ```dart
  await FirebaseFirestore.instance
    .collection('squads')
    .doc(squadId)
    .update({'clipOfTheDayId': messageId});
  ```

### View Tracking
Views are automatically tracked when a clip appears on screen:
```dart
ClipFeedItem(
  messageData: clip,
  onView: () {
    ref.read(clipNotifierProvider.notifier).markClipAsViewed(clip.id);
  },
)
```

## Firestore Structure

### Clips Collection
```
squads/{squadId}/clips/{clipId}
  ├── clipData:
  │   ├── videoUrl: string
  │   ├── thumbnailUrl: string
  │   ├── durationSec: number
  │   ├── views: number  // Incremented on appear
  │   ├── hypeReactions: string[]  // Array of UIDs
  │   ├── clipId: string
  │   ├── width: number
  │   └── height: number
  ├── sender: string
  ├── senderUid: string
  ├── timestamp: Timestamp
  └── type: "clip"
```

### Squad Document
```
squads/{squadId}
  └── clipOfTheDayId: string  // Optional manual pin
```

## Features

✅ **Infinite scroll** with pagination
✅ **Pull to refresh**
✅ **Real-time updates** via Firestore streams
✅ **Clip of the Day** pinned section
✅ **View count** auto-increment on appear
✅ **Hype reactions** with haptic feedback
✅ **Empty state** with neon text
✅ **Loading states** with game-colored spinners
✅ **Auto-play next** - passes all clips to player
✅ **NEON VOID design** - glassmorphism, pulsing animations
✅ **Responsive** - adapts to game color theming

## Next Steps

### Integration Testing
```bash
flutter test integration_test/clips_tab_flow_test.dart
```

### Dynamic Game Color
Extract game color from `squadState.currentGame`:
```dart
Color _getGameColor() {
  final squadState = ref.read(sn.squadNotifierProvider).value;
  return Color(squadState?.currentGame?['primaryColor'] ?? 0xFF00FFFF);
}
```

### Firebase Indexes
Deploy required compound indexes:
```bash
firebase deploy --only firestore:indexes
```

**Required index** (in `firestore.indexes.json`):
```json
{
  "collectionGroup": "clips",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "timestamp", "order": "DESCENDING"}
  ]
}
```

### Security Rules
```javascript
match /squads/{squadId}/clips/{clipId} {
  allow read: if request.auth != null;
  allow write: if request.auth != null && 
    request.auth.uid == resource.data.senderUid;
  allow update: if request.auth != null && (
    // Allow view count increments
    request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['clipData.views']) ||
    // Allow hype reactions
    request.resource.data.diff(resource.data).affectedKeys()
      .hasOnly(['clipData.hypeReactions'])
  );
}
```

## Performance Notes

- **AutoDisposeAsyncNotifier** automatically cleans up streams when tab is disposed
- **AutomaticKeepAliveClientMixin** on ClipsTab prevents rebuild when switching tabs
- **Pagination** limits initial load to 10 clips
- **CachedNetworkImage** caches thumbnails for smooth scrolling
- **View tracking** is fire-and-forget (doesn't block UI)

## Example Flow

1. User opens squad → sees Squad tab by default
2. Taps "Clips" tab → ClipNotifier initializes stream
3. ClipsTab loads 10 most recent clips + Clip of the Day
4. User scrolls down → triggers `loadMoreClips()` at 200px before end
5. User taps clip → opens ClipPlayerScreen with auto-play
6. User pulls down → refreshes entire feed
7. User switches back to Squad tab → ClipsTab state preserved (KeepAlive)
8. User leaves squad → AutoDispose cleans up Firestore subscription
