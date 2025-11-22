# Refactored FirestoreService with Riverpod

This document describes the refactored FirestoreService that optimizes suggested groups queries for the SquadSync Flutter app.

## Overview

The refactored FirestoreService provides:
- **Optimized queries** with composite indexes for chat_groups collection
- **Pagination** using `.limit(20).startAfter()`
- **Query builder** for flexible filtering (isPublic, gameName, memberCount > min)
- **SQLite caching** with 5-minute TTL for offline/fast access
- **Real-time syncing** via streams
- **Error handling** with AsyncValue.guard()
- **Riverpod integration** for reactive state management

## Architecture

### Core Components

1. **FirestoreService**: Main service class with Riverpod integration
2. **OptimizedGroupQueryBuilder**: Handles query building and optimization
3. **SuggestedGroupsNotifier**: Riverpod StateNotifier for managing group state
4. **GroupQueryFilters**: Data class for query parameters

### Database Indexes Required

Create these Firestore composite indexes for optimal performance:

```javascript
// Index 1: isPublic asc, memberCount desc, gameName asc
{
  "collectionGroup": "chat_groups",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "isPublic", "order": "ASCENDING"},
    {"fieldPath": "memberCount", "order": "DESCENDING"},
    {"fieldPath": "gameName", "order": "ASCENDING"}
  ]
}

// Index 2: isPublic asc, memberCount desc, lastMessageTime desc
{
  "collectionGroup": "chat_groups",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "isPublic", "order": "ASCENDING"},
    {"fieldPath": "memberCount", "order": "DESCENDING"},
    {"fieldPath": "lastMessageTime", "order": "DESCENDING"}
  ]
}
```

## Usage

### Basic Query

```dart
// Get public groups with semantic search
final filters = GroupQueryFilters(
  isPublic: true,
  searchTerm: 'Warzone clans',
);

// Load groups using Riverpod
ref.read(suggestedGroupsNotifierProvider.notifier)
    .loadSuggestedGroups(filters);
```

### Watching State

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsState = ref.watch(suggestedGroupsNotifierProvider);

    return groupsState.suggestedGroups.when(
      data: (groups) => GroupsList(groups: groups),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### Advanced Filtering

```dart
// Filter by game and minimum members
final filters = GroupQueryFilters(
  isPublic: true,
  gameName: 'Warzone',
  minMemberCount: 10,
  searchTerm: 'competitive',
);

// Load with pagination
ref.read(suggestedGroupsNotifierProvider.notifier)
    .loadSuggestedGroups(filters);
```

### Pagination

```dart
// Load next page (requires storing last document)
final lastDoc = groups.last; // From previous result
ref.read(suggestedGroupsNotifierProvider.notifier)
    .loadNextPage(lastDoc);
```

## Caching Strategy

- **TTL**: 5 minutes for cached results
- **Storage**: SQLite with automatic cleanup
- **Keys**: Generated from filter combination
- **Sync**: Real-time updates bypass cache for fresh data

## Error Handling

All operations use `AsyncValue.guard()` for consistent error handling:

```dart
// Automatic error wrapping
final result = await AsyncValue.guard(() async {
  return await firestore.collection('groups').get();
});

// Handle in UI
result.when(
  data: (data) => /* success */,
  loading: () => /* loading */,
  error: (error, stack) => /* error */,
);
```

## Migration from Old Service

Replace old FirestoreService usage:

```dart
// Old way
final service = FirestoreService();
final stream = service.queryBuilder.buildSuggestedGroupsQuery(
  searchTerm, gameName, grokService, notificationManager, sqliteHelper
);

// New way
final filters = GroupQueryFilters(
  isPublic: true,
  searchTerm: searchTerm,
  gameName: gameName,
);
ref.read(suggestedGroupsNotifierProvider.notifier)
    .loadSuggestedGroups(filters);
```

## Performance Optimizations

1. **Composite Indexes**: Optimized for common query patterns
2. **Pagination**: Limits data transfer and improves UX
3. **Caching**: Reduces Firestore reads and enables offline access
4. **Semantic Filtering**: AI-powered relevance scoring
5. **Stream Updates**: Real-time sync without full requeries

## Testing

The service includes comprehensive error handling and can be tested with mock providers:

```dart
test('loads suggested groups', () async {
  final container = ProviderContainer(overrides: [
    firestoreServiceRefactoredProvider.overrideWithValue(mockService),
  ]);

  // Test implementation
});
```

## Integration with DiscoveryScreen

The refactored service integrates seamlessly with the existing DiscoveryScreen pattern, providing enhanced group discovery with AI-powered search and efficient caching.