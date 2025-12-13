# Grok AI Enhancements Documentation

## Overview
This document describes the AI-powered features integrated into SquadSync using xAI's Grok API.

## Features

### 1. Smart Replies with Sentiment Analysis
Enhanced smart reply suggestions that analyze conversation sentiment and provide contextual emoji recommendations.

#### Implementation
**Backend** (`backend/server.js`):
- Endpoint: `POST /smart-replies`
- Model: `grok-4.1-fast-latest`
- Returns: `{replies: string[], sentiment: string, emojis: string[]}`

**Frontend** (`lib/services/grok_service.dart`):
```dart
final grokService = GrokService();
final response = await grokService.getSmartRepliesWithSentiment(lastFiveMessages);

print(response.sentiment); // 'positive', 'negative', 'neutral', 'excited', 'questioning'
print(response.replies);   // ['Count me in!', 'Let's do this!', 'Sounds good!']
print(response.emojis);    // ['😊', '🎮', '🔥']
```

**UI Component** (`lib/chat/widgets/smart_reply_bottom_sheet.dart`):
- Displays sentiment indicator with color-coded icon
- Shows suggested emojis for quick reactions
- Animated reply suggestions with smooth transitions

#### Features
- **Sentiment Analysis**: Detects emotional tone (positive, negative, neutral, excited, questioning)
- **Contextual Emojis**: Suggests 3 relevant emojis based on conversation context
- **Smart Suggestions**: 2-3 concise reply options (under 50 characters each)
- **Caching**: 1-minute TTL to reduce API calls for similar contexts
- **Fallback**: Local fallback responses when API is unavailable

### 2. AI Matchmaking for Lobby Discovery
Intelligent lobby recommendations based on user's pinned games and preferences.

#### Implementation
**Backend** (`backend/server.js`):
- Endpoint: `POST /ai-matchmaking`
- Analyzes: Pinned games, user preferences, available lobbies
- Returns: `{recommendations: [{lobbyId, score, reason}], insights: string}`

**Frontend** (`lib/presentation/notifiers/discovery_notifier.dart`):
```dart
// Use the provider with parameters
final matchmaking = ref.watch(aiMatchmakingProvider({
  'pinnedGames': [
    {'name': 'Call of Duty: Warzone'},
    {'name': 'Apex Legends'},
  ],
  'userPreferences': {
    'playstyle': 'competitive',
    'skill_level': 'intermediate',
  },
}));

matchmaking.when(
  data: (response) {
    for (var rec in response.recommendations) {
      print('${rec.lobbyId}: ${rec.score} - ${rec.reason}');
    }
    print('Insights: ${response.insights}');
  },
  loading: () => showLoadingIndicator(),
  error: (e, s) => showError(e),
);
```

#### Features
- **Personalized Matching**: Considers pinned games and user preferences
- **Scored Recommendations**: Each recommendation includes a relevance score (0-1)
- **Explanations**: AI provides reasoning for each recommendation
- **Overall Insights**: General matchmaking advice and observations
- **Fallback**: Graceful degradation when API is unavailable

### 3. Rate Limiting & Retry Logic
Robust error handling with exponential backoff using the `retry` package.

#### Implementation
**GrokService** (`lib/services/grok_service.dart`):
```dart
Future<T> _callWithBackoff<T>(Future<T> Function() call) async {
  final retryOptions = RetryOptions(
    maxAttempts: 3,
    delayFactor: Duration(milliseconds: 1000),
    randomizationFactor: 0.25, // Jitter to avoid thundering herd
    maxDelay: const Duration(seconds: 10),
  );
  
  return retryOptions.retry(
    call,
    retryIf: (e) => e is RateLimitException || e is http.ClientException,
    onRetry: (e) => _logger.w('Retrying API call after error: $e'),
  );
}
```

#### Features
- **Exponential Backoff**: 1s → 2s → 4s delays between retries
- **Jitter**: 25% randomization to prevent synchronized retries
- **Max Retries**: 3 attempts before giving up
- **Retry Conditions**: Rate limits (429) and network errors
- **Logging**: Automatic retry logging for debugging

## Configuration

### Backend Environment Variables
Required in `backend/.env`:

```env
# xAI Grok API Key
# Get your API key from: https://console.x.ai/
# Used for: Smart replies with sentiment analysis, AI matchmaking, and chat assistance
# Rate limits: Handled automatically with exponential backoff (3 retries, 1s base delay)
# Model: grok-4.1-fast-latest (optimized for low latency)
XAI_API_KEY=your_xai_api_key_here

# Optional: Rate limiting configuration (defaults shown)
# RATE_LIMIT_WINDOW_MS=60000  # 1 minute window
# RATE_LIMIT_MAX_REQUESTS=100  # Max requests per window
```

### Frontend Configuration
Default backend URL in `lib/services/grok_service.dart`:
```dart
static const String _backendUrl = String.fromEnvironment('BACKEND_URL',
    defaultValue: 'https://lobbiesync-backend-756172684661.us-central1.run.app');
```

Override with: `flutter run --dart-define=BACKEND_URL=http://localhost:8080`

## API Reference

### Smart Replies Endpoint
**POST** `/smart-replies`

**Request:**
```json
{
  "messages": [
    "Hey, anyone up for Warzone?",
    "I'm down!",
    "What time?",
    "In 10 minutes?",
    "Perfect!"
  ]
}
```

**Response:**
```json
{
  "replies": [
    "Count me in!",
    "Let's do this!",
    "See you there!"
  ],
  "sentiment": "excited",
  "emojis": ["🎮", "🔥", "💪"]
}
```

### AI Matchmaking Endpoint
**POST** `/ai-matchmaking`

**Request:**
```json
{
  "pinnedGames": [
    {"name": "Call of Duty: Warzone"},
    {"name": "Apex Legends"}
  ],
  "userPreferences": {
    "playstyle": "competitive",
    "skill_level": "intermediate"
  },
  "availableLobbies": [
    {
      "id": "lobby123",
      "gameName": "Call of Duty: Warzone",
      "name": "Competitive Squad",
      "spotsOpen": 2,
      "memberCount": 3
    }
  ]
}
```

**Response:**
```json
{
  "recommendations": [
    {
      "lobbyId": "lobby123",
      "score": 0.95,
      "reason": "Perfect match! Competitive Warzone lobby with 2 open spots matches your pinned games and competitive playstyle."
    }
  ],
  "insights": "Your pinned games suggest you enjoy battle royale FPS games. The recommended lobbies are active and looking for skilled players.",
  "success": true
}
```

## Usage Examples

### Example 1: Smart Reply Widget
```dart
// In chat screen
IconButton(
  icon: Icon(Icons.smart_toy),
  onPressed: () {
    final lastMessages = messages.take(5).map((m) => m.text).toList();
    showModalBottomSheet(
      context: context,
      builder: (context) => SmartReplyBottomSheet(
        lastFiveMessages: lastMessages,
        onReplySelected: (reply) {
          // Send the selected reply
          messageController.text = reply;
        },
      ),
    );
  },
)
```

### Example 2: Discovery Tab with AI Matching
```dart
// In discovery/lobbies tab
Consumer(
  builder: (context, ref, child) {
    final filter = ref.watch(discoveryFilterProvider);
    
    if (filter == 'ai-match') {
      final pinnedGames = ref.watch(pinnedGamesProvider);
      final matchmaking = ref.watch(aiMatchmakingProvider({
        'pinnedGames': pinnedGames,
      }));
      
      return matchmaking.when(
        data: (response) => AiMatchmakingView(response: response),
        loading: () => LoadingIndicator(),
        error: (e, s) => ErrorView(error: e),
      );
    }
    
    // Regular lobby list
    return LobbyListView();
  },
)
```

### Example 3: Manual AI Matchmaking
```dart
final grokService = GrokService();

// Get AI recommendations
final response = await grokService.getAiMatchmaking(
  pinnedGames: [
    {'name': 'Apex Legends'},
    {'name': 'Valorant'},
  ],
  userPreferences: {
    'playstyle': 'casual',
    'preferred_time': 'evening',
  },
  availableLobbies: lobbies.map((l) => l.toJson()).toList(),
);

// Display recommendations
for (var rec in response.recommendations) {
  print('Lobby: ${rec.lobbyId}');
  print('Match Score: ${(rec.score * 100).toInt()}%');
  print('Reason: ${rec.reason}');
}
```

## Performance Considerations

### Caching Strategy
- **Smart Replies**: 1-minute TTL with message hash as key
- **Benefits**: Reduces API calls for repeated contexts
- **Invalidation**: Automatic based on timestamp

### Rate Limiting
- **Backend**: Configure via environment variables
- **Frontend**: Built-in exponential backoff
- **Recommendation**: Start with 100 req/min window

### Error Handling
All methods include:
1. Try-catch blocks
2. Fallback responses
3. User-friendly error messages
4. Automatic retry logic
5. Comprehensive logging

## Best Practices

### 1. Smart Replies
- Trigger on user interaction (button press), not automatically
- Show loading indicator during API calls
- Cache results to improve responsiveness
- Provide fallback options when API fails

### 2. AI Matchmaking
- Update recommendations when pinned games change
- Include user preferences for better results
- Show reasoning to build user trust
- Allow users to refresh recommendations

### 3. Rate Limiting
- Monitor retry logs in production
- Adjust retry parameters based on API limits
- Implement user feedback for rate limit errors
- Consider request queuing for high-traffic scenarios

## Troubleshooting

### Issue: "Grok API key not configured"
**Solution**: Set `XAI_API_KEY` in `backend/.env`

### Issue: Rate limit errors (429)
**Solution**: 
- Verify rate limit configuration
- Check retry logic is working
- Consider implementing request throttling

### Issue: Slow response times
**Solution**:
- Enable caching (already implemented)
- Use `grok-4.1-fast-latest` model (default)
- Consider edge caching for backend

### Issue: Inaccurate matchmaking
**Solution**:
- Provide more detailed user preferences
- Include lobby activity metrics
- Tune AI prompt in backend

## Future Enhancements

### Planned Features
1. **User Feedback Loop**: Learn from user selections to improve recommendations
2. **Advanced Filters**: Time zone matching, skill level verification
3. **Group Recommendations**: Suggest multiple compatible users for party formation
4. **Conversation Summaries**: AI-generated chat summaries for catch-up
5. **Toxicity Detection**: Real-time moderation assistance

### Optimization Opportunities
1. Edge caching for frequently accessed data
2. WebSocket integration for real-time AI suggestions
3. Batch API calls to reduce latency
4. Client-side ML models for instant fallbacks

## Related Documentation
- [Splash Screen Setup](splash_screen_setup.md)
- [Dynamic Theme System](dynamic_theme_system.md)
- [Null Safety Guide](null_safety_guide.md)
- [Agora Setup](agora_setup.md)

## Support
For issues or questions:
- GitHub Issues: https://github.com/Spencereese/SquadSync/issues
- Backend logs: Check Cloud Run logs
- Frontend logs: Use Logger package output
