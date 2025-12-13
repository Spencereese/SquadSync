# Onboarding Flow Enhancements

## Overview
Enhanced the onboarding flow with skippable pages, progress indicators, AI-powered game recommendations via Grok, Firebase Analytics A/B testing, and preference validation with Supabase integration.

## Key Features

### 1. Progress Indicators & Skip Functionality
**Location**: `lib/presentation/onboarding/onboarding_flow.dart`

- **Linear Progress Bar**: Shows visual progress through onboarding (1/4, 2/4, etc.)
- **Skip Button**: Allows users to skip to the final page from any page except the first
- **Progress Tracking**: `progressPercentage` getter provides 0.0-1.0 progress value
- **Analytics**: Tracks page views, navigation actions, and skip events

**Implementation**:
```dart
// Progress bar in top navigation
LinearProgressIndicator(
  value: notifier.progressPercentage,
  backgroundColor: Colors.cyan.withOpacity(0.1),
  valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan.withOpacity(0.7)),
)

// Skip functionality
notifier.skipToEnd(); // Marks as skipped and jumps to last page
```

### 2. Grok AI Game Recommendations
**Location**: 
- `lib/presentation/onboarding/onboarding_notifier.dart`
- `lib/presentation/onboarding/widgets/game_selection_screen.dart`

**Features**:
- **AI-Powered**: Uses xAI's Grok API (grok-4.1-fast-latest model) via backend
- **Context-Aware**: Sends user callsign and already-selected games for personalized recommendations
- **A/B Testing**: Only visible to users in variant B (50/50 split)
- **Interactive**: Tap recommended game names to search for them
- **Loading States**: Shows spinner while fetching recommendations

**Usage**:
```dart
// Request recommendations
await ref.read(onboardingProvider.notifier).fetchGameRecommendations(userContext);

// Recommendations displayed as chips
onboardingState.aiRecommendedGames // List<String>
```

**Backend Integration**:
The notifier calls the existing `GrokService` which connects to:
- Backend endpoint: `/grok`
- Model: `grok-4.1-fast-latest`
- Prompt: Tailored for game recommendations with user context

### 3. Firebase Analytics A/B Testing
**Location**: `lib/presentation/onboarding/onboarding_notifier.dart`

**Events Tracked**:
- `onboarding_started` - Initial load with variant assignment
- `onboarding_page_view` - Page navigation
- `onboarding_next` / `onboarding_back` - Navigation direction
- `onboarding_skipped` - Skip action with origin page
- `onboarding_games_selected` - Game selection count
- `onboarding_ai_recommendations` - AI feature usage
- `onboarding_preference_changed` - Preference toggles
- `onboarding_completed` - Final completion with all metrics
- `onboarding_validation_failed` / `onboarding_error` - Error tracking

**A/B Test Variants**:
- **Variant A**: Standard onboarding flow
- **Variant B**: Includes AI recommendations button in game selection

**Implementation**:
```dart
// Automatic 50/50 split on initialization
final variant = DateTime.now().millisecond % 2 == 0 ? 'A' : 'B';
state = state.copyWith(abTestVariant: variant);

// All events include variant for segmentation
_analytics.logEvent(
  name: 'event_name',
  parameters: {
    'ab_variant': state.abTestVariant,
    // ... other params
  },
);
```

### 4. Preference Validation
**Location**: 
- `lib/presentation/onboarding/onboarding_notifier.dart`
- `lib/presentation/onboarding/widgets/preferences_screen.dart`

**Validation Rules**:
- **Voice Ready + Mic Always On**: Cannot enable "Mic Always On" without "Voice Ready"
- **Error Display**: Shows validation errors before completion
- **Error State**: Stored in onboarding state for UI feedback

**Preferences Tracked**:
- `voice_ready`: User has microphone ready for voice chat
- `mic_always_on`: Keep microphone active (requires voice_ready)
- `late_night`: Prefer late-night gaming sessions
- `competitive`: Competitive vs chill play style

**Validation Flow**:
```dart
bool validatePreferences() {
  final voiceReady = prefs['voice_ready'] ?? false;
  final micAlwaysOn = prefs['mic_always_on'] ?? false;
  
  if (micAlwaysOn && !voiceReady) {
    state = state.copyWith(
      error: 'Microphone always-on requires Voice Ready to be enabled',
    );
    return false;
  }
  return true;
}
```

### 5. Supabase Integration
**Location**: `lib/presentation/onboarding/onboarding_notifier.dart`

**Data Saved to Supabase `users` Table**:
```dart
{
  'uid': userId,                                      // Firebase Auth UID
  'display_name': callsign,                           // User's callsign
  'photo_url': avatarPath,                            // Avatar image path
  'pinned_games': selectedGames,                      // Array of game slugs
  'preferences': preferences,                          // Preference map
  'onboarding_complete': true,                        // Completion flag
  'onboarding_skipped': hasSkipped,                   // Skip tracking
  'ab_variant': abTestVariant,                        // A/B test variant
  'ai_recommendations_used': aiRecommendedGames.isNotEmpty, // AI feature usage
  'updated_at': timestamp,                            // Last update time
}
```

**Dual Storage**:
1. **Supabase users table**: Full onboarding data with analytics metadata
2. **Supabase Auth metadata**: Quick-access profile data for app initialization

## State Management

### OnboardingState Structure
```dart
@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(0) int currentPage,              // Current page index (0-3)
    @Default(4) int totalPages,               // Total page count
    @Default(false) bool isLoading,           // Save operation loading
    @Default(false) bool hasSkipped,          // User skipped pages
    String? callsign,                         // User's callsign
    String? avatarPath,                       // Avatar image path
    @Default([]) List<String> selectedGames,  // Selected game slugs
    @Default([]) List<String> aiRecommendedGames, // AI recommendations
    @Default(false) bool isLoadingRecommendations, // AI loading state
    @Default({}) Map<String, bool> preferences, // User preferences
    @Default('A') String abTestVariant,       // A/B test variant
    String? error,                            // Validation/error message
  }) = _OnboardingState;
}
```

## Usage Flow

1. **Sign In Page** (Page 0)
   - User authenticates via Apple/Google
   - Cannot skip from this page
   
2. **Callsign & Avatar Page** (Page 1)
   - User sets display name and avatar
   - Skip button appears
   - Progress: 2/4
   
3. **Game Selection Page** (Page 2)
   - Search and select up to 6 games
   - **Variant B**: AI recommendations button
   - Popular games displayed
   - Progress: 3/4
   
4. **Preferences Page** (Page 3)
   - Set voice/mic preferences
   - Choose competitive vs chill
   - Validation runs on completion
   - Progress: 4/4

## Analytics Dashboard Queries

To analyze A/B test results in Firebase Analytics:

```sql
-- Compare completion rates by variant
SELECT 
  event_params.value.string_value as variant,
  COUNT(*) as completions,
  AVG(games_selected) as avg_games_selected
FROM events
WHERE event_name = 'onboarding_completed'
GROUP BY variant

-- Skip rate by variant
SELECT 
  event_params.value.string_value as variant,
  COUNTIF(skipped = true) / COUNT(*) as skip_rate
FROM events
WHERE event_name = 'onboarding_completed'
GROUP BY variant

-- AI recommendation usage (Variant B only)
SELECT 
  COUNT(*) as total_completions,
  COUNTIF(ai_recs_used = true) as used_ai_recs,
  COUNTIF(ai_recs_used = true) / COUNT(*) as adoption_rate
FROM events
WHERE event_name = 'onboarding_completed' 
  AND ab_variant = 'B'
```

## Dependencies

**Packages Used**:
- `firebase_analytics: ^12.0.2` - Analytics tracking
- `flutter_riverpod` - State management
- `freezed` - Immutable state classes
- Existing `GrokService` - xAI Grok API integration
- Existing `SupabaseService` - Database operations

## Future Enhancements

1. **Machine Learning**:
   - Train model on A/B test results to optimize onboarding flow
   - Personalize AI recommendations based on successful user patterns
   
2. **Dynamic Content**:
   - Adjust onboarding steps based on user behavior
   - Add/remove pages dynamically based on variant performance
   
3. **Advanced Analytics**:
   - Funnel analysis for drop-off points
   - Time-to-complete metrics per variant
   - Cohort retention analysis by onboarding variant

4. **Enhanced Validation**:
   - Real-time preference validation
   - Tooltips explaining preference dependencies
   - Progressive disclosure of advanced options

## Testing

To test the implementation:

```bash
# Regenerate freezed files
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Check analytics in Firebase Console
# Navigate to: Analytics > Events
# Look for: onboarding_* events
```

## Notes

- **Privacy**: All analytics data is anonymized
- **Performance**: AI recommendations cached to reduce API calls
- **Error Handling**: Graceful fallbacks if Grok API unavailable
- **Accessibility**: Progress indicators support screen readers
- **Theming**: Uses existing Material 3 theme system with cyan/purple accents
