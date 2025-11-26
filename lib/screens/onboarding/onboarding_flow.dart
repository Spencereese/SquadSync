import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/onboarding_service.dart';
import '../../chat/chat_groups_screen.dart';
import '../../services/app_flow_manager.dart';
import 'profile_setup_screen.dart';
import 'add_game_screen.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _pageController = PageController();
  final DateTime _onboardingStartTime = DateTime.now();
  int _previousStep = 0;

  @override
  void initState() {
    super.initState();
    // Removed _loadDraft() call - the service initializes itself
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Removed ref.listen - will handle navigation in build method
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingServiceProvider);

    // Handle page navigation when step changes
    final currentStep = onboardingState.value?.currentStep ?? 0;
    if (currentStep != _previousStep && currentStep < 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.animateToPage(
          currentStep,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    } else if (currentStep >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completeOnboarding();
      });
    }
    _previousStep = currentStep;

    return Scaffold(
      appBar: AppBar(
        title:
            Text('Setup (${(onboardingState.value?.currentStep ?? 0) + 1}/2)'),
        automaticallyImplyLeading: false,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ProfileSetupScreen(onNext: _nextStep)
              .animate()
              .fadeIn(duration: 500.ms),
          AddGameScreen(onComplete: _completeOnboarding)
              .animate()
              .fadeIn(duration: 500.ms),
        ],
      ),
    );
  }

  void _nextStep() {
    final onboardingService = ref.read(onboardingServiceProvider.notifier);
    onboardingService.nextStep();
  }

  void _completeOnboarding() async {
    try {
      final onboardingService = ref.read(onboardingServiceProvider.notifier);
      await onboardingService.completeOnboarding();

      // Analytics
      final container = ProviderScope.containerOf(context);
      final analytics = container.read(appFlowManagerProvider);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final pinnedGames =
            ref.read(onboardingServiceProvider).value?.pinnedGames.length ?? 0;
        await analytics.trackOnboardingCompleted(
          userId: user.uid,
          gamesPinned: pinnedGames,
          timeSpent: DateTime.now().difference(_onboardingStartTime),
        );
      }

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ChatGroupsScreen()),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to complete onboarding: $e')),
        );
      }
    }
  }
}
