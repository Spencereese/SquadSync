# Quick Reference: Game Notifier with Dio, Twitch & Caching

## 🚀 Quick Start

### 1. Environment Setup
```bash
# .env file - add these credentials
TWITCH_CLIENT_ID=your_twitch_client_id
TWITCH_CLIENT_SECRET=your_twitch_client_secret
```

### 2. Install Dependencies
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Test Dio Caching
```dart
// First call hits IGDB API
await gameNotifier.searchGames('Warzone');

// Second call uses cached response
await gameNotifier.searchGames('Warzone'); // Instant from cache
```

## 📦 Key Components

### Dio Configuration
```dart
// lib/core/injection.dart
getIt.registerSingleton<Dio>(Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 30),
)));
```

### Cache Settings
```dart
// lib/data/datasources/game_remote_datasource.dart
CacheOptions(
  store: HiveCacheStore(cacheDir.path),
  policy: CachePolicy.refreshForceCache,
  maxStale: const Duration(days: 7),
  hitCacheOnErrorExcept: [401, 403],
)
```

### Twitch Service Usage
```dart
// Initialize (done automatically in GameNotifier.build())
_twitchService = TwitchService(di.getIt<Dio>());
await _twitchService?.initialize();

// Fetch game clips
await gameNotifier.fetchTwitchClips(
  gameName: 'Call of Duty',
  limit: 20,
  period: 'week', // day, week, month, all
);

// Fetch trending clips
await gameNotifier.fetchTrendingClips(
  limit: 20,
  period: 'day',
);
```

## 🔄 Fallback Chain

```
User searches "Warzone"
       ↓
   Try IGDB API
       ↓
   Success? → Return results
       ↓ No
   Try SQLite Cache
       ↓
   Found? → Return cached results
       ↓ No
   Try Local JSON (assets/popular_games.json)
       ↓
   Return filtered results or error
```

## 🎮 ClipsScreen Features

### Toggle Views
```dart
// Squad clips (default)
_showTwitchClips = false;

// Twitch trending clips
_showTwitchClips = true;
```

### Access Twitch Clips
```dart
final gameState = ref.watch(gameNotifierProvider).value;
final clips = gameState?.twitchClips ?? [];

for (final clip in clips) {
  print('${clip['title']} - ${clip['viewCount']} views');
  print('Thumbnail: ${clip['thumbnailUrl']}');
  print('Duration: ${clip['duration']}s');
}
```

## 📊 Performance Monitoring

### Flutter DevTools Commands
```bash
# Run in profile mode
flutter run --profile

# Launch DevTools
flutter pub global activate devtools
flutter pub global run devtools

# With performance overlay
flutter run --profile --trace-skia
```

### What to Monitor
1. **Network Tab**: Check cache hit rate (should be >80% for repeated queries)
2. **Performance Tab**: Frame rendering should stay <16ms
3. **Memory Tab**: Hive cache size (should stabilize <50MB)
4. **Widget Rebuilds**: ClipsTab should maintain state with AutomaticKeepAliveClientMixin

## 🧪 Testing Offline Mode

```bash
# 1. Run app normally
flutter run

# 2. Search for games (populates cache)
# Search "Warzone", "Battlefield", "Apex"

# 3. Enable airplane mode or disable network

# 4. Search again - should return cached/local results
```

## 🐛 Troubleshooting

### Cache Not Working
```dart
// Check cache directory
final cacheDir = await getTemporaryDirectory();
print('Cache path: ${cacheDir.path}');

// Clear cache if needed
await Directory('${cacheDir.path}/dio_cache').delete(recursive: true);
```

### Twitch API Fails
```dart
// Check initialization
print('Twitch initialized: ${_twitchService?.isInitialized}');

// Verify credentials
print('Client ID: ${dotenv.env['TWITCH_CLIENT_ID']}');
```

### IGDB Fallback Not Triggered
```dart
// Add logging in searchGames()
_logger.w('IGDB search failed, falling back to cache/local: $e');
```

## 📈 Performance Benchmarks

### Expected Metrics
- **First IGDB call**: 500-1500ms (network dependent)
- **Cached IGDB call**: <50ms (disk read)
- **Local JSON fallback**: <100ms (asset load + filter)
- **Twitch API call**: 300-800ms (OAuth + clip fetch)
- **Clips scroll**: 60fps (with lazy loading at 300px threshold)

## 🔐 Security Notes

### DO NOT Commit
```gitignore
# Add to .gitignore
.env
*.env
backend/.env
```

### Environment Variables
```bash
# Use environment variables for all secrets
TWITCH_CLIENT_ID=abc123...
TWITCH_CLIENT_SECRET=xyz789...
IGDB_CLIENT_ID=igdb123...
IGDB_CLIENT_SECRET=igdb789...
```

## 📝 Code Snippets

### Custom Dio Interceptor
```dart
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('REQUEST[${options.method}] => PATH: ${options.path}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    print('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
    super.onResponse(response, handler);
  }
}

// Add to Dio instance
dio.interceptors.add(LoggingInterceptor());
```

### Pagination with Twitch
```dart
Future<void> loadMoreTwitchClips() async {
  final currentClips = state.value?.twitchClips ?? [];
  final newClips = await _twitchService!.getTrendingClips(
    limit: 20,
    period: 'week',
  );
  
  state = AsyncValue.data(
    state.value!.copyWith(
      twitchClips: [...currentClips, ...newClips],
    ),
  );
}
```

## 🎯 Next Steps

1. **Profile the app** with Flutter DevTools
2. **Test offline behavior** thoroughly
3. **Add Twitch OAuth** for user-specific clips
4. **Implement clip playback** in-app
5. **Add analytics** for cache performance
6. **Set up CI/CD** with cache warmup

## 📚 References

- Dio: https://pub.dev/packages/dio
- Dio Cache: https://pub.dev/packages/dio_cache_interceptor
- Twitch API: https://dev.twitch.tv/docs/api/
- Flutter DevTools: https://docs.flutter.dev/tools/devtools
- Riverpod: https://riverpod.dev/
