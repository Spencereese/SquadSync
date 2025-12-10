// 🎯 QUICK REFERENCE - OnboardingFlow Integration

// ═══════════════════════════════════════════════════════════════
// 1. IMPORT THE ONBOARDING FLOW
// ═══════════════════════════════════════════════════════════════
import 'package:squad_sync/presentation/onboarding/onboarding_flow.dart';
import 'package:squad_sync/presentation/onboarding/onboarding_notifier.dart';

// ═══════════════════════════════════════════════════════════════
// 2. BASIC USAGE - Just show the onboarding
// ═══════════════════════════════════════════════════════════════
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const OnboardingFlow()),
);

// ═══════════════════════════════════════════════════════════════
// 3. WATCH STATE - Listen to onboarding progress
// ═══════════════════════════════════════════════════════════════
final state = ref.watch(onboardingProvider);
print('Current page: ${state.currentPage}');
print('Selected games: ${state.selectedGames}');
print('Callsign: ${state.callsign}');

// ═══════════════════════════════════════════════════════════════
// 4. MANUAL CONTROL - Programmatically control flow
// ═══════════════════════════════════════════════════════════════
// Jump to page
ref.read(onboardingProvider.notifier).setPage(2);

// Go to next page
ref.read(onboardingProvider.notifier).nextPage();

// Set callsign
ref.read(onboardingProvider.notifier).setCallsign('GHOST');

// Add games
ref.read(onboardingProvider.notifier).toggleGame('cod');
ref.read(onboardingProvider.notifier).toggleGame('apex');

// Set preferences
ref.read(onboardingProvider.notifier).togglePreference('notifications', true);

// Complete onboarding (saves to Firestore)
await ref.read(onboardingProvider.notifier).completeOnboarding();

// ═══════════════════════════════════════════════════════════════
// 5. CHECK VALIDATION - Can user proceed from page?
// ═══════════════════════════════════════════════════════════════
bool canProceed = ref.read(onboardingProvider.notifier).canProceedFromPage(1);

// ═══════════════════════════════════════════════════════════════
// 6. CUSTOMIZATION - Modify colors/theme
// ═══════════════════════════════════════════════════════════════

// Background color
const backgroundColor = Color(0xFF0B0E14); // Dark void

// Neon accent colors
const primaryNeon = Colors.cyan;
const secondaryNeon = Colors.purpleAccent;

// Glassmorphism opacity
Colors.white.withOpacity(0.05); // Glass effect

// ═══════════════════════════════════════════════════════════════
// 7. ADD/REMOVE GAMES - Edit game list
// ═══════════════════════════════════════════════════════════════

// In onboarding_flow.dart, _GameSelectorPageState:
final List<GameCard> _games = [
  GameCard(id: 'cod', name: 'Call of Duty', image: 'assets/images/cod.png'),
  GameCard(id: 'apex', name: 'Apex Legends', image: 'assets/images/apex.png'),
  // Add your games here
  GameCard(id: 'custom', name: 'My Game', image: 'assets/images/mygame.png'),
];

// ═══════════════════════════════════════════════════════════════
// 8. ADD/REMOVE PREFERENCES - Edit preference chips
// ═══════════════════════════════════════════════════════════════

// In onboarding_flow.dart, _PreferencesPage:
_PreferenceChip(
  label: 'My Custom Preference',
  icon: Icons.settings,
  selected: state.preferences['myPref'] ?? false,
  onTap: () => ref.read(onboardingProvider.notifier)
      .togglePreference('myPref', !(state.preferences['myPref'] ?? false)),
),

// ═══════════════════════════════════════════════════════════════
// 9. FIRESTORE STRUCTURE - User document after onboarding
// ═══════════════════════════════════════════════════════════════

/*
users/{uid} = {
  callsign: "GHOST",
  avatarPath: "/path/to/local/image.jpg",
  pinnedGames: ["cod", "apex", "valorant"],
  preferences: {
    notifications: true,
    soundEffects: true,
    haptics: true,
    autoJoin: false,
    showOnline: true,
    darkMode: true
  },
  createdAt: Timestamp,
  onboardingComplete: true
}
*/

// ═══════════════════════════════════════════════════════════════
// 10. NAVIGATION SETUP - Route configuration
// ═══════════════════════════════════════════════════════════════

MaterialApp(
  routes: {
    '/onboarding': (context) => const OnboardingFlow(),
    '/main': (context) => const MainNavigationScreen(),
  },
  // OnboardingFlow automatically navigates to '/main' on completion
);

// ═══════════════════════════════════════════════════════════════
// 11. PAGE BREAKDOWN
// ═══════════════════════════════════════════════════════════════

/*
Page 0: Sign-In
  - Apple Sign-In (iOS only)
  - Google Sign-In (placeholder)
  - Email Sign-In
  - Auto-advance on success

Page 1: Callsign & Avatar
  - Text input (callsign)
  - Image picker (avatar)
  - Continue button

Page 2: Game Selector
  - Swipe cards (Tinder-style)
  - Max 6 games
  - Manual controls
  - Skip when ≥1 selected

Page 3: Preferences
  - 6 toggle chips
  - "ENTER THE VOID" button
  - Saves to Firestore
*/

// ═══════════════════════════════════════════════════════════════
// 12. KEY WIDGETS
// ═══════════════════════════════════════════════════════════════

// Matrix rain background
const MatrixRainBackground();

// Glass card container
GlassCard(
  child: YourWidget(),
  gradient: LinearGradient(...), // Optional
);

// Neon button
NeonButton(
  label: 'CONTINUE',
  onPressed: () {},
  enabled: true,
  gradient: LinearGradient(colors: [Colors.cyan, Colors.purple]),
);

// ═══════════════════════════════════════════════════════════════
// 13. DEPENDENCIES REQUIRED
// ═══════════════════════════════════════════════════════════════

/*
smooth_page_indicator: ^1.2.0+3
flutter_card_swiper: ^7.0.1
freezed_annotation: ^2.4.4
freezed: ^2.5.2 (dev)
build_runner: ^2.4.8 (dev)
*/

// ═══════════════════════════════════════════════════════════════
// 14. BUILD COMMAND
// ═══════════════════════════════════════════════════════════════

// Generate freezed code:
// flutter pub run build_runner build --delete-conflicting-outputs

// ═══════════════════════════════════════════════════════════════
// 15. COMMON TASKS
// ═══════════════════════════════════════════════════════════════

// Skip to specific page
ref.read(onboardingProvider.notifier).setPage(3);

// Get current state
final onboarding = ref.read(onboardingProvider);
if (onboarding.isLoading) { /* show loader */ }
if (onboarding.error != null) { /* show error */ }

// Reset onboarding (useful for testing)
await FirebaseAuth.instance.signOut();
await FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .update({'onboardingComplete': false});

// ═══════════════════════════════════════════════════════════════
// 🎉 DONE! You're ready to use OnboardingFlow
// ═══════════════════════════════════════════════════════════════
