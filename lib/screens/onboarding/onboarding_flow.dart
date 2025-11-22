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

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to state changes for navigation
    ref.listen(onboardingServiceProvider, (previous, next) {
      if (next.value?.currentStep != previous?.value?.currentStep) {
        final currentStep = next.value?.currentStep ?? 0;
        if (currentStep < 2) {
          _pageController.animateToPage(
            currentStep,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          _completeOnboarding();
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadDraft() async {
    final onboardingService = ref.read(onboardingServiceProvider.notifier);
    final draft = onboardingService.loadDraft();
    if (draft.currentStep > 0) {
      _pageController.jumpToPage(draft.currentStep);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup (${(onboardingState.value?.currentStep ?? 0) + 1}/2)'),
        automaticallyImplyLeading: false,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ProfileSetupScreen(onNext: _nextStep).animate().fadeIn(duration: 500.ms),
          AddGameScreen(onComplete: _completeOnboarding).animate().fadeIn(duration: 500.ms),
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
        final pinnedGames = ref.read(onboardingServiceProvider).value?.pinnedGames.length ?? 0;
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
