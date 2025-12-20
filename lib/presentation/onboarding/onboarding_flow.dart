import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service_supabase.dart';
import 'dart:io';
import 'onboarding_notifier.dart';
import 'widgets/matrix_rain_background.dart';
import 'widgets/glass_card.dart';
import 'widgets/neon_button.dart';
import 'widgets/avatar_selection_widget.dart';
import 'widgets/preferences_screen.dart';
import 'widgets/game_selection_screen.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Stack(
        children: [
          // Matrix rain background
          const MatrixRainBackground(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar with progress and skip
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Progress indicator
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: notifier.progressPercentage,
                                      backgroundColor:
                                          Colors.cyan.withOpacity(0.1),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.cyan.withOpacity(0.7),
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${state.currentPage + 1}/${state.totalPages}',
                                  style: TextStyle(
                                    color: Colors.cyan.withOpacity(0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Skip button - only show if not on last page
                      if (state.currentPage > 0 &&
                          state.currentPage < state.totalPages - 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: TextButton(
                            onPressed: () {
                              notifier.skipToEnd();
                              _pageController.animateToPage(
                                state.totalPages - 1,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Text(
                              'SKIP',
                              style: TextStyle(
                                color: Colors.cyan.withOpacity(0.5),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Page view
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      ref.read(onboardingProvider.notifier).setPage(page);
                    },
                    children: [
                      _SignInPage(
                        pulseController: _pulseController,
                        pageController: _pageController,
                      ),
                      _CallsignAvatarPage(pageController: _pageController),
                      GameSelectionScreen(
                        onComplete: () {
                          _pageController.animateToPage(
                            3,
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                      PreferencesScreen(
                        onComplete: () async {
                          await ref
                              .read(onboardingProvider.notifier)
                              .completeOnboarding();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacementNamed('/main');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Page 1: Sign-in
class _SignInPage extends ConsumerWidget {
  final AnimationController pulseController;
  final PageController pageController;

  const _SignInPage({
    required this.pulseController,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: pulseController, curve: Curves.easeInOut),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo/Title
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.cyan, Colors.purpleAccent],
              ).createShader(bounds),
              child: const Text(
                'SQUADSYNC',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Assemble. Dominate. Repeat.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.cyan.withOpacity(0.6),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 80),

            // Sign-in buttons
            AnimatedBuilder(
              animation: pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: pulseAnimation.value,
                child: child,
              ),
              child: Column(
                children: [
                  if (Platform.isIOS)
                    _NeonSignInButton(
                      icon: Icons.apple,
                      label: 'Sign in with Apple',
                      gradient: const LinearGradient(
                        colors: [Colors.black87, Colors.black54],
                      ),
                      onPressed: () => _signInWithApple(ref),
                    ),
                  if (Platform.isIOS) const SizedBox(height: 16),
                  _NeonSignInButton(
                    icon: Icons.g_mobiledata,
                    label: 'Sign in with Google',
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.orange.shade700],
                    ),
                    onPressed: () => _signInWithGoogle(ref),
                  ),
                  const SizedBox(height: 16),
                  _NeonSignInButton(
                    icon: Icons.email_outlined,
                    label: 'Sign in with Email',
                    gradient: const LinearGradient(
                      colors: [Colors.cyan, Colors.blue],
                    ),
                    onPressed: () => _signInWithEmail(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithApple(WidgetRef ref) async {
    try {
      final authService = AuthServiceSupabase();
      await authService.signInWithApple();
      pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      debugPrint('Apple sign in error: $e');
    }
  }

  Future<void> _signInWithGoogle(WidgetRef ref) async {
    // Google Sign-In v7 API update - temporarily simplified
    // TODO: Implement full Google Sign-In flow after API migration
    debugPrint(
        'Google sign in requested - implementation pending v7 API migration');

    // For now, show a message
    try {
      // Placeholder: This would normally handle Google Sign-In
      // For demo purposes, auto-advance (remove in production)
      await Future.delayed(const Duration(milliseconds: 500));
      // ref.read(onboardingProvider.notifier).nextPage();
    } catch (e) {
      debugPrint('Google sign in error: $e');
    }
  }

  Future<void> _signInWithEmail(BuildContext context, WidgetRef ref) async {
    // Show email/password dialog
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B0E14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.cyan, width: 1),
        ),
        title:
            const Text('Email Sign In', style: TextStyle(color: Colors.cyan)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.cyan.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: Colors.cyan.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showForgotPasswordDialog(context);
                },
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Colors.cyan.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign In', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        final authService = AuthServiceSupabase();
        // Try sign in first
        try {
          await authService.signInWithEmailPassword(
            email: emailController.text.trim(),
            password: passwordController.text,
          );
          pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        } catch (signInError) {
          // If sign in fails, try sign up
          try {
            await authService.signUpWithEmailPassword(
              email: emailController.text.trim(),
              password: passwordController.text,
            );
            pageController.animateToPage(
              1,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            );
          } catch (createError) {
            debugPrint('Email sign up error: $createError');
          }
        }
      } catch (e) {
        debugPrint('Email sign in error: $e');
      }
    }
  }

  Future<void> _showForgotPasswordDialog(BuildContext context) async {
    final emailController = TextEditingController();
    final authService = AuthServiceSupabase();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0B0E14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.cyan, width: 1),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.cyan),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a password reset link.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.cyan.withOpacity(0.7)),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan.withOpacity(0.3)),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, emailController.text.trim()),
            child: const Text('Send Reset Link', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && context.mounted) {
      try {
        await authService.resetPassword(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Password reset email sent! Check your inbox.'),
              backgroundColor: Colors.cyan.withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red.withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

class _NeonSignInButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback onPressed;

  const _NeonSignInButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          gradient: gradient.scale(0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Page 2: Callsign + Avatar
class _CallsignAvatarPage extends ConsumerStatefulWidget {
  final PageController pageController;

  const _CallsignAvatarPage({required this.pageController});

  @override
  ConsumerState<_CallsignAvatarPage> createState() =>
      _CallsignAvatarPageState();
}

class _CallsignAvatarPageState extends ConsumerState<_CallsignAvatarPage> {
  final TextEditingController _callsignController = TextEditingController();
  Color _dynamicAccentColor = Colors.cyan;

  @override
  void dispose() {
    _callsignController.dispose();
    super.dispose();
  }

  void _onAvatarSelected(String avatarPath, Color accentColor) {
    setState(() {
      _dynamicAccentColor = accentColor;
    });
    ref.read(onboardingProvider.notifier).setAvatarPath(avatarPath);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'IDENTIFY',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.cyan,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose your callsign & avatar',
              style: TextStyle(
                fontSize: 14,
                color: Colors.cyan.withOpacity(0.6),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 48),

            // Avatar selection widget
            AvatarSelectionWidget(
              initialAvatarPath: ref.watch(onboardingProvider).avatarPath,
              onAvatarSelected: _onAvatarSelected,
            ),
            const SizedBox(height: 48),

            // Callsign input
            GlassCard(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _callsignController,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: _dynamicAccentColor.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  decoration: InputDecoration(
                    hintText: 'CALLSIGN',
                    hintStyle: TextStyle(
                      color: _dynamicAccentColor.withOpacity(0.3),
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                    border: InputBorder.none,
                  ),
                  maxLength: 15,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    ref.read(onboardingProvider.notifier).setCallsign(value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 48),

            // Continue button
            NeonButton(
              label: 'CONTINUE',
              onPressed: () {
                if (_callsignController.text.trim().isNotEmpty) {
                  HapticFeedback.lightImpact();
                  widget.pageController.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
              },
              enabled: _callsignController.text.trim().isNotEmpty,
              gradient: LinearGradient(
                colors: [
                  _dynamicAccentColor,
                  _dynamicAccentColor.withOpacity(0.7)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
