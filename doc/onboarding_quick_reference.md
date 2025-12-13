# Onboarding Flow - Quick Reference

## For Developers

### Using the Onboarding Notifier

```dart
// Access onboarding state
final state = ref.watch(onboardingProvider);
final notifier = ref.read(onboardingProvider.notifier);

// Navigation
notifier.nextPage();           // Go to next page
notifier.previousPage();       // Go back
notifier.skipToEnd();          // Skip to last page
notifier.setPage(2);           // Jump to specific page

// Progress
notifier.progressPercentage;   // Returns 0.0 to 1.0

// Game Selection
notifier.toggleGame(gameId);   // Add/remove game
notifier.setGames(['game1', 'game2']); // Set all at once

// AI Recommendations (Variant B only)
await notifier.fetchGameRecommendations('''
Callsign: PlayerX
Already selected: Call of Duty, Fortnite
Looking for: Similar competitive shooters
''');

// Access recommendations
state.aiRecommendedGames;      // List<String>
state.isLoadingRecommendations; // bool

// Preferences
notifier.togglePreference('voice_ready', true);
notifier.togglePreference('mic_always_on', true);
notifier.togglePreference('late_night', false);
notifier.togglePreference('competitive', true);

// Validation
notifier.validatePreferences(); // Returns bool

// Completion
await notifier.completeOnboarding();
```

### State Access

```dart
// Current state fields
state.currentPage;              // int: 0-3
state.totalPages;               // int: 4
state.isLoading;                // bool
state.hasSkipped;               // bool
state.callsign;                 // String?
state.avatarPath;               // String?
state.selectedGames;            // List<String>
state.aiRecommendedGames;       // List<String>
state.isLoadingRecommendations; // bool
state.preferences;              // Map<String, bool>
state.abTestVariant;            // 'A' or 'B'
state.error;                    // String?
```

### Adding Analytics Events

```dart
// The notifier automatically tracks all events
// But you can add custom events too:

FirebaseAnalytics.instance.logEvent(
  name: 'custom_onboarding_event',
  parameters: {
    'ab_variant': state.abTestVariant,
    'custom_param': 'value',
  },
);
```

## For UI Components

### Show/Hide Based on Variant

```dart
// Only show AI features in variant B
if (onboardingState.abTestVariant == 'B') {
  IconButton(
    icon: const Icon(Icons.auto_awesome),
    onPressed: _requestAIRecommendations,
  )
}
```

### Display Progress

```dart
LinearProgressIndicator(
  value: notifier.progressPercentage,
)

Text('${state.currentPage + 1}/${state.totalPages}')
```

### Handle Errors

```dart
if (state.error != null) {
  // Show error UI
  Text(state.error!, style: TextStyle(color: Colors.red))
}
```

### Loading States

```dart
if (state.isLoading) {
  CircularProgressIndicator()
}

if (state.isLoadingRecommendations) {
  CircularProgressIndicator()
}
```

## Common Patterns

### Page Validation Before Navigation

```dart
void _navigateNext() {
  if (notifier.canProceedFromPage(state.currentPage)) {
    notifier.nextPage();
    _pageController.nextPage(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  } else {
    // Show error
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Please complete this step first')),
    );
  }
}
```

### Saving Draft State

The notifier automatically handles state persistence. No manual saving needed.

### Testing Variants Locally

To force a specific variant during development:

```dart
// In onboarding_notifier.dart, modify _initializeABTest():
void _initializeABTest() async {
  final variant = 'B'; // Force variant B for testing
  state = state.copyWith(abTestVariant: variant);
  // ...
}
```

## Preference Validation Rules

| Preference | Dependencies | Validation |
|------------|-------------|------------|
| `voice_ready` | None | Always valid |
| `mic_always_on` | Requires `voice_ready` | Fails if voice_ready is false |
| `late_night` | None | Always valid |
| `competitive` | None | Always valid |

### Adding New Validations

```dart
bool validatePreferences() {
  final prefs = state.preferences;
  
  // Add your custom validation
  if (prefs['my_pref'] == true && prefs['required_pref'] == false) {
    state = state.copyWith(
      error: 'Custom validation message',
    );
    return false;
  }
  
  // ... existing validations
  return true;
}
```

## Backend Requirements

### Grok API Endpoint

The backend must expose `/grok` endpoint:

```javascript
app.post('/grok', async (req, res) => {
  const { message, context, recentMessages } = req.body;
  
  // Call xAI Grok API
  const response = await axios.post('https://api.x.ai/v1/chat/completions', {
    model: 'grok-4.1-fast-latest',
    messages: [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: message }
    ]
  }, {
    headers: {
      'Authorization': `Bearer ${process.env.XAI_API_KEY}`
    }
  });
  
  res.json({ response: response.data.choices[0].message.content });
});
```

### Supabase users Table Schema

Required columns:
```sql
CREATE TABLE users (
  uid TEXT PRIMARY KEY,
  display_name TEXT,
  photo_url TEXT,
  pinned_games TEXT[],
  preferences JSONB,
  onboarding_complete BOOLEAN,
  onboarding_skipped BOOLEAN,
  ab_variant TEXT,
  ai_recommendations_used BOOLEAN,
  updated_at TIMESTAMP
);
```

## Troubleshooting

### AI Recommendations Not Working
1. Check backend is running and XAI_API_KEY is set
2. Verify user is in variant B: `state.abTestVariant == 'B'`
3. Check network requests in dev tools
4. Look for errors in `state.error`

### Analytics Not Appearing
1. Wait 24 hours for Firebase to process events
2. Check Firebase Console > Analytics > DebugView for real-time events
3. Enable debug mode: `adb shell setprop debug.firebase.analytics.app com.example.app`

### Validation Always Failing
1. Check preference values: `state.preferences`
2. Verify validation logic in `validatePreferences()`
3. Look for error message in `state.error`

### State Not Persisting
1. Freezed files regenerated? Run `flutter pub run build_runner build --delete-conflicting-outputs`
2. Check for runtime errors in console
3. Verify provider is properly configured

## Migration Guide

If updating from old onboarding:

1. **Replace old state management**:
   ```dart
   // Old
   final onboardingService = ref.watch(onboardingServiceProvider);
   
   // New
   final onboardingState = ref.watch(onboardingProvider);
   ```

2. **Update completion callback**:
   ```dart
   // Old
   await onboardingService.completeOnboarding();
   
   // New
   await ref.read(onboardingProvider.notifier).completeOnboarding();
   ```

3. **Add analytics dependency** to `pubspec.yaml`:
   ```yaml
   dependencies:
     firebase_analytics: ^12.0.2
   ```

4. **Regenerate code**:
   ```bash
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
