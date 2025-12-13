# Grok AI Features - Quick Reference

## Smart Replies with Sentiment Analysis

### Basic Usage
```dart
import 'package:squad_sync/services/grok_service.dart';

final grokService = GrokService();
final response = await grokService.getSmartRepliesWithSentiment(
  ['Hey, anyone up for Warzone?', 'I\'m down!', 'Let\'s go!']
);

print(response.sentiment); // 'excited'
print(response.replies);   // ['Count me in!', 'Let\'s do this!']
print(response.emojis);    // ['🎮', '🔥', '💪']
```

### Show in UI
```dart
showModalBottomSheet(
  context: context,
  builder: (context) => SmartReplyBottomSheet(
    lastFiveMessages: messages.take(5).map((m) => m.text).toList(),
    onReplySelected: (reply) {
      messageController.text = reply;
      Navigator.pop(context);
    },
  ),
);
```

### Sentiment Colors
- 🟢 **Green**: positive, excited
- 🔴 **Red**: negative
- 🔵 **Blue**: questioning, curious
- ⚪ **Grey**: neutral

---

## AI Matchmaking

### Basic Usage
```dart
import 'package:squad_sync/services/grok_service.dart';

final grokService = GrokService();
final response = await grokService.getAiMatchmaking(
  pinnedGames: [
    {'name': 'Apex Legends'},
    {'name': 'Valorant'},
  ],
  userPreferences: {'playstyle': 'competitive'},
  availableLobbies: lobbies.map((l) => l.toJson()).toList(),
);

for (var rec in response.recommendations) {
  print('${rec.lobbyId}: ${rec.score} - ${rec.reason}');
}
```

### With Riverpod Provider
```dart
final matchmaking = ref.watch(aiMatchmakingProvider({
  'pinnedGames': pinnedGames,
  'userPreferences': {'playstyle': 'competitive'},
}));

matchmaking.when(
  data: (response) => AiMatchmakingView(response: response),
  loading: () => CircularProgressIndicator(),
  error: (e, s) => ErrorView(error: e),
);
```

---

## Rate Limiting

### Automatic Retry
All Grok API calls automatically retry with exponential backoff:
- **Max Attempts**: 3
- **Delays**: 1s → 2s → 4s
- **Jitter**: ±25% to prevent thundering herd

### Custom Retry Options
```dart
// Already configured in GrokService._callWithBackoff()
final retryOptions = RetryOptions(
  maxAttempts: 3,
  delayFactor: Duration(milliseconds: 1000),
  randomizationFactor: 0.25,
  maxDelay: const Duration(seconds: 10),
);
```

---

## Configuration

### Backend (.env)
```env
XAI_API_KEY=your_xai_api_key_here
BACKEND_URL=https://your-backend-url.com
```

### Frontend Override
```bash
flutter run --dart-define=BACKEND_URL=http://localhost:8080
```

---

## Error Handling

### All methods include fallbacks
```dart
try {
  final response = await grokService.getSmartRepliesWithSentiment(messages);
  // Use response.replies, response.sentiment, response.emojis
} catch (e) {
  // Fallback responses are automatically provided
  // Check logs for details
}
```

### Check Logs
```dart
import 'package:logger/logger.dart';

final logger = Logger(level: Level.debug);
// Look for: "Retrying API call after error"
```

---

## Caching

### Smart Replies Cache
- **TTL**: 1 minute
- **Key**: Hash of message list
- **Automatic**: No action needed

### Invalidation
```dart
// Cache automatically invalidates after 1 minute
// Or when message list changes
```

---

## Common Patterns

### Pattern 1: Chat Input with Smart Replies
```dart
Row(
  children: [
    Expanded(child: TextField(...)),
    IconButton(
      icon: Icon(Icons.smart_toy),
      onPressed: () => _showSmartReplies(),
    ),
    IconButton(
      icon: Icon(Icons.send),
      onPressed: () => _sendMessage(),
    ),
  ],
)
```

### Pattern 2: Discovery Filter
```dart
SegmentedButton(
  segments: [
    ButtonSegment(value: 'hot', label: Text('Hot')),
    ButtonSegment(value: 'new', label: Text('New')),
    ButtonSegment(value: 'ai-match', label: Text('AI Match')),
  ],
  selected: {ref.watch(discoveryFilterProvider)},
  onSelectionChanged: (set) {
    ref.read(discoveryFilterProvider.notifier).state = set.first;
  },
)
```

### Pattern 3: Emoji Quick Reply
```dart
// Already implemented in SmartReplyBottomSheet
InkWell(
  onTap: () {
    if (widget.onReplySelected != null) {
      widget.onReplySelected!(emoji);
    }
    Navigator.pop(context);
  },
  child: Text(emoji, style: TextStyle(fontSize: 20)),
)
```

---

## Testing

### Mock Smart Replies
```dart
final mockResponse = SmartReplyResponse(
  replies: ['Nice!', 'Sounds good!', 'Let\'s go!'],
  sentiment: 'positive',
  emojis: ['😊', '👍', '🎮'],
);
```

### Mock AI Matchmaking
```dart
final mockResponse = AiMatchmakingResponse(
  recommendations: [
    LobbyRecommendation(
      lobbyId: 'lobby123',
      score: 0.95,
      reason: 'Perfect match for your playstyle',
    ),
  ],
  insights: 'Your pinned games suggest competitive FPS preference',
);
```

---

## Performance Tips

1. **Use Caching**: Enabled by default for smart replies
2. **Batch Requests**: Combine multiple operations when possible
3. **Async Loading**: Show loading indicators during API calls
4. **Fallback UI**: Always provide offline-friendly defaults
5. **Monitor Logs**: Watch for retry patterns and optimize

---

## Troubleshooting

### Issue: "Grok API key not configured"
```bash
# Set in backend/.env
XAI_API_KEY=your_key_here
```

### Issue: Rate limit errors (429)
```dart
// Automatic retry is enabled
// Check logs: "Retrying API call after error"
// Wait for exponential backoff to complete
```

### Issue: Slow responses
```dart
// Check cache is working (look for cache hits in logs)
// Consider increasing cache TTL
// Verify backend URL is correct (not localhost in prod)
```

---

## API Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/smart-replies` | POST | Get sentiment + replies + emojis |
| `/ai-matchmaking` | POST | Get lobby recommendations |
| `/grok` | POST | General Grok queries |

---

## Security Checklist

- ✅ XAI_API_KEY in environment variables (not code)
- ✅ Backend-only API key access
- ✅ Rate limiting enabled
- ✅ Exponential backoff prevents abuse
- ✅ No sensitive data in API calls

---

## Links

- 📖 [Full Documentation](doc/grok_ai_enhancements.md)
- 📋 [Implementation Summary](GROK_IMPLEMENTATION_SUMMARY.md)
- 🏗️ [Architecture Guide](.github/copilot-instructions.md)
- 🐛 [Report Issues](https://github.com/Spencereese/SquadSync/issues)
