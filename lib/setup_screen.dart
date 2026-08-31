import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_theme.dart';
import 'services/supabase_service.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => SetupScreenState();
}

class SetupScreenState extends ConsumerState<SetupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _supabase = SupabaseService.client;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _googleInitialized = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter both email and password');
      return;
    }

    setState(() => _isLoading = true);
    try {
      AuthResponse authResponse;
      try {
        authResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (_) {
        authResponse = await _supabase.auth.signUp(
          email: email,
          password: password,
        );
      }

      if (authResponse.user != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _handlePostSignIn(authResponse.user!);
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: ${e.message}'),
            action: SnackBarAction(
              label: 'Reset Password',
              onPressed: _showForgotPasswordDialog,
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      _showSnackBar('An unexpected error occurred');
      debugPrint('Auth error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ensureGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }
    await GoogleSignIn.instance.initialize(
      clientId: dotenv.env['GOOGLE_IOS_CLIENT_ID'],
      serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    );
    _googleInitialized = true;
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      await _ensureGoogleSignIn();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        _showSnackBar('Google Sign-In is not available on this platform');
        return;
      }

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('Google did not return an ID token');
      }

      final authResponse = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );

      if (authResponse.user != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _handlePostSignIn(authResponse.user!);
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      _showSnackBar('Google Sign-In failed: ${e.description ?? e.code.name}');
      debugPrint('Google Sign-In error: $e');
    } catch (e) {
      _showSnackBar('Google Sign-In failed');
      debugPrint('Google Sign-In error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      if (appleCredential.identityToken == null) {
        throw Exception('No identity token received from Apple');
      }

      final authResponse = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: appleCredential.identityToken!,
        nonce: rawNonce,
      );

      if (authResponse.user != null) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _handlePostSignIn(authResponse.user!);
      } else {
        throw Exception('Authentication succeeded but no user returned');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) {
        _showSnackBar('Apple Sign-In failed: ${e.message}');
        debugPrint('Apple Sign-In authorization error: ${e.code} - ${e.message}');
      }
    } catch (e) {
      _showSnackBar('Apple Sign-In failed');
      debugPrint('Apple Sign-In error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  Future<void> _handlePostSignIn(User user) async {
    try {
      final response = await _supabase
          .from('users')
          .select('display_name')
          .eq('uid', user.id)
          .maybeSingle();

      if (response == null || response['display_name'] == null) {
        _showNameDialog(user);
        return;
      }

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Error checking user profile: $e');
      _showNameDialog(user);
    }
  }

  void _showNameDialog(User user) {
    final TextEditingController nameController = TextEditingController();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Your First Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'First Name'),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveName(user, nameController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => _saveName(user, nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveName(User user, String name) async {
    if (name.trim().isEmpty) {
      _showSnackBar('Please enter your first name');
      return;
    }
    try {
      final now = DateTime.now().toIso8601String();
      await _supabase.from('users').upsert({
        'uid': user.id,
        'display_name': name.trim(),
        'email': user.email ?? 'unknown@user.com',
        'created_at': now,
        'updated_at': now,
      });

      if (mounted) {
        Navigator.pop(context);
        context.go('/');
      }
    } catch (e) {
      debugPrint('Error saving name: $e');
      _showSnackBar('Error saving name: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we will send you a password reset link.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                hintText: 'Enter your email',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, emailController.text.trim()),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        await _supabase.auth.resetPasswordForEmail(result);
        if (mounted) {
          _showSnackBar('Password reset email sent. Check your inbox.');
        }
      } on AuthException catch (e) {
        if (mounted) {
          _showSnackBar('Failed to send reset email: ${e.message}');
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('An error occurred. Please try again.');
        }
      }
    }
    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neon = theme.colorScheme.primary;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Color(0xFF0B0E14),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E14),
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            const _LoginBackdrop(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 440,
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: Center(
                        child: GlassmorphicContainer(
                          blur: 22,
                          borderRadius: 24,
                          padding:
                              const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 72,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.groups_3_rounded,
                            size: 64,
                            color: neon,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'SquadSync',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to find your squad',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@email.com',
                          ),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          enabled: !_isLoading,
                          autofillHints: const [AutofillHints.email],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !_isPasswordVisible,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_isLoading) {
                              _handleEmailAuth();
                            }
                          },
                          enabled: !_isLoading,
                          autofillHints: const [AutofillHints.password],
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _isLoading ? null : _showForgotPasswordDialog,
                            child: const Text('Forgot Password?'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        NeonPulseButton(
                          onPressed: _isLoading ? null : _handleEmailAuth,
                          child: const Text('Sign In / Register'),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: neon.withValues(alpha: 0.25),
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: neon.withValues(alpha: 0.25),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google_logo.png',
                                height: 22,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.g_mobiledata,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('Sign in with Google'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SignInWithAppleButton(
                          onPressed: _isLoading ? () {} : _handleAppleSignIn,
                          style: SignInWithAppleButtonStyle.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
                },
              ),
            ),
            if (_isLoading)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Signing in...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B0E14),
            Color(0xFF101820),
            Color(0xFF0B1220),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: _GlowOrb(
              color: Theme.of(context).colorScheme.primary,
              size: 220,
            ),
          ),
          const Positioned(
            bottom: -60,
            left: -30,
            child: _GlowOrb(
              color: Color(0xFF6A4C93),
              size: 180,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.28),
        ),
      ),
    );
  }
}
