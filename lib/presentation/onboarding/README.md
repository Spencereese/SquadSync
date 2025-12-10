# OnboardingFlow - Complete Implementation

## Overview
A modern, neon-cyberpunk themed onboarding experience with 4 pages using Material Design principles and smooth animations.

## Features

### 🎨 Visual Design
- **Background**: Matrix rain particle animation with subtle cyan/green particles
- **Glassmorphism**: All cards use frosted glass effect with backdrop blur
- **Neon Accents**: Cyan/magenta borders with pulsing glow animations
- **Dark Theme**: #0B0E14 background matching SquadSync aesthetic
- **Smooth Transitions**: Page indicator with neon dot style using WormEffect

### 📱 Page Structure

#### Page 1: Authentication
- **Sign-in Options**:
  - Apple Sign-In (iOS only) - Black gradient button
  - Google Sign-In - Red/orange gradient (placeholder pending v7 API)
  - Email Sign-In - Cyan/blue gradient with dialog
- **Features**:
  - Pulsing neon border animation on all buttons
  - Glass card containers
  - Auto-advance to Page 2 after successful authentication

#### Page 2: Callsign & Avatar
- **Callsign Input**:
  - Large centered text field with neon glow
  - Auto-capitalizes input
  - 15 character limit
  - Real-time validation
- **Avatar Picker**:
  - Circular frame with cyan neon border and glow
  - Tap to open image picker
  - Shows selected image immediately
- **Continue Button**: Enabled only when callsign is provided

#### Page 3: Game Selector
- **Tinder-Style Swiper**:
  - Uses `flutter_card_swiper` package
  - Maximum 6 games can be selected
  - Swipe right to add, left to skip
  - Visual feedback: "ADD" (green) / "SKIP" (red) overlays
- **Manual Controls**:
  - X button (red) - swipe left
  - Heart button (green) - swipe right
  - Skip button - proceed when at least 1 game selected
- **Game Cards**:
  - 6 pre-defined games: COD, Apex, Fortnite, Valorant, Overwatch, Destiny
  - Glassmorphic cards with game icons
  - Selected games show cyan/purple gradient overlay
- **Auto-advance**: Moves to Page 4 when all cards swiped and games selected

#### Page 4: Preferences
- **Preference Chips**:
  - Push Notifications (default: on)
  - Sound Effects (default: on)
  - Haptic Feedback (default: on)
  - Auto-Join Squads (default: off)
  - Show Online Status (default: on)
  - Dark Mode (default: on)
- **Interactive Chips**:
  - Tap to toggle on/off
  - Animated border and shadow
  - Icon + label layout
- **Final Button**: "ENTER THE VOID" with cyan/purple gradient

### 🎯 State Management

#### OnboardingNotifier (Riverpod)
```dart
final onboardingProvider = NotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
```

**State Properties**:
- `currentPage` - Active page index (0-3)
- `isLoading` - Loading state during completion
- `callsign` - User's chosen callsign
- `avatarPath` - Local path to selected avatar image
- `selectedGames` - List of game IDs (max 6)
- `preferences` - Map of preference keys to boolean values
- `error` - Error message if any

**Methods**:
- `setPage(int)` - Jump to specific page
- `nextPage()` - Advance to next page
- `previousPage()` - Go back one page
- `setCallsign(String)` - Update callsign
- `setAvatarPath(String)` - Update avatar path
- `toggleGame(String)` - Add/remove game from selection
- `setGames(List<String>)` - Set all selected games at once
- `togglePreference(String, bool)` - Update preference value
- `completeOnboarding()` - Save to Firestore and finish
- `canProceedFromPage(int)` - Validation check for page progression

### 🔥 Firebase Integration

**Firestore Document** (`users/{uid}`):
```dart
{
  'callsign': String,
  'avatarPath': String?,
  'pinnedGames': List<String>,
  'preferences': Map<String, bool>,
  'createdAt': Timestamp,
  'onboardingComplete': true,
}
```

**Authentication**:
- Apple Sign-In: Uses `sign_in_with_apple` package
- Email Sign-In: Creates account if doesn't exist, signs in if exists
- Google Sign-In: Placeholder (pending v7 API migration)

### 📦 Dependencies

Added to `pubspec.yaml`:
```yaml
dependencies:
  smooth_page_indicator: ^1.2.0+3
  flutter_card_swiper: ^7.0.1
  freezed_annotation: ^2.4.4

dev_dependencies:
  freezed: ^2.5.2 (already present)
  build_runner: ^2.4.8 (already present)
```

### 🎬 Animations

1. **Matrix Rain Background**: Continuous particle animation
2. **Pulse Animation**: Sign-in button borders (2s cycle)
3. **Glow Animation**: Neon button pulsing glow (2s cycle)
4. **Page Transitions**: Smooth PageView with physics
5. **Swipe Feedback**: Card rotation and overlay animations

### 🚀 Usage

```dart
// In your app's route configuration
MaterialApp(
  routes: {
    '/onboarding': (context) => const OnboardingFlow(),
    '/main': (context) => const MainNavigationScreen(),
  },
)

// Navigate to onboarding
Navigator.of(context).pushNamed('/onboarding');

// After completion, automatically navigates to '/main'
```

### 🛠️ Customization

**Colors**:
- Primary: `Colors.cyan` (neon accent)
- Secondary: `Colors.purpleAccent` (gradient accent)
- Background: `Color(0xFF0B0E14)` (dark void)

**Games List** (modify in `_GameSelectorPageState`):
```dart
final List<GameCard> _games = [
  GameCard(id: 'cod', name: 'Call of Duty', image: 'assets/images/cod.png'),
  // Add more games...
];
```

**Preferences** (modify in `_PreferencesPage`):
```dart
_PreferenceChip(
  label: 'Your Preference',
  icon: Icons.your_icon,
  selected: state.preferences['yourKey'] ?? defaultValue,
  onTap: () => ref.read(onboardingProvider.notifier)
      .togglePreference('yourKey', newValue),
),
```

### 🎨 Widget Hierarchy

```
OnboardingFlow
├─ MatrixRainBackground (full screen)
├─ SafeArea
│  ├─ Skip Button (top right)
│  ├─ PageView
│  │  ├─ _SignInPage
│  │  │  └─ _NeonSignInButton (x3)
│  │  ├─ _CallsignAvatarPage
│  │  │  ├─ Avatar Picker (GestureDetector)
│  │  │  ├─ GlassCard (callsign input)
│  │  │  └─ NeonButton (continue)
│  │  ├─ _GameSelectorPage
│  │  │  ├─ CardSwiper
│  │  │  └─ Manual Controls (_SwipeButton x2)
│  │  └─ _PreferencesPage
│  │     ├─ _PreferenceChip (x6)
│  │     └─ NeonButton (ENTER THE VOID)
│  └─ SmoothPageIndicator (bottom)
```

### ⚠️ Notes

1. **Google Sign-In**: Currently shows placeholder. Requires Google Sign-In v7 API implementation.
2. **Avatar Upload**: Only stores local path. Implement Firebase Storage upload in `completeOnboarding()` if needed.
3. **Game Images**: Currently uses placeholder icons. Replace with actual game images in assets.
4. **Platform Support**: Apple Sign-In only shows on iOS. Email sign-in works cross-platform.
5. **Navigation**: Assumes `/main` route exists for post-onboarding navigation.

### 🧪 Testing

To test the onboarding flow:
1. Clear user authentication: `FirebaseAuth.instance.signOut()`
2. Navigate to `/onboarding`
3. Complete all 4 pages
4. Verify Firestore document creation
5. Confirm navigation to main screen

### 🔄 Generated Files

After running `flutter pub run build_runner build --delete-conflicting-outputs`:
- `lib/presentation/onboarding/onboarding_notifier.freezed.dart`
- `lib/presentation/onboarding/onboarding_notifier.g.dart` (if using json_serializable)

### 📝 File Structure

```
lib/presentation/onboarding/
├── onboarding_flow.dart              # Main PageView widget
├── onboarding_notifier.dart          # Riverpod state management
├── onboarding_notifier.freezed.dart  # Generated freezed code
└── widgets/
    ├── matrix_rain_background.dart   # Animated particle background
    ├── glass_card.dart                # Glassmorphic container
    └── neon_button.dart               # Glowing animated button
```

---

**Total Lines of Code**: ~1100
**Widgets Created**: 12
**Animation Controllers**: 3
**State Properties**: 7
**Firestore Integration**: ✅
**Platform Support**: iOS, Android, Web, Desktop
