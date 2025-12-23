import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'services/supabase_service.dart';
import 'chat/chat_groups_screen.dart';

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

  @override
  void initState() {
    super.initState();
    // Don't auto-check user - let authStateProvider handle navigation
    // This prevents premature navigation before actual login
  }

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
        // Try sign in first
        authResponse = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } catch (signInError) {
        // If sign in fails, create new account
        authResponse = await _supabase.auth.signUp(
          email: email,
          password: password,
        );
      }

      if (authResponse.user != null) {
        debugPrint('_handleEmailAuth: Auth successful');
        debugPrint('  - User: ${authResponse.user!.id}');
        debugPrint('  - Session: ${authResponse.session}');
        debugPrint(
            '  - Session access token: ${authResponse.session?.accessToken ?? "null"}');

        // Small delay to ensure session is fully synced before checking profile
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

  // TODO: Update Google Sign In method for v7 API
  Future<void> _handleGoogleSignIn() async {
    _showSnackBar('Google Sign-In temporarily disabled - updating to v7 API');
    /*
    setState(() => _isLoading = true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      await _handlePostSignIn(userCredential.user!);
    } catch (e) {
      _showSnackBar('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    */
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('_handleAppleSignIn: Starting Apple Sign-In flow');

      // Generate nonce for security
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      debugPrint('_handleAppleSignIn: Requesting Apple ID credential');
      // This call will show Apple's native UI and wait for user to complete
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      debugPrint(
          '_handleAppleSignIn: Received credential, signing in to Supabase');

      // Ensure we have the identity token
      if (appleCredential.identityToken == null) {
        throw Exception('No identity token received from Apple');
      }

      // Sign in with Supabase using the Apple credential
      final authResponse = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: appleCredential.identityToken!,
        nonce: rawNonce,
      );

      if (authResponse.user != null) {
        debugPrint(
            '_handleAppleSignIn: Auth successful, user: ${authResponse.user!.id}, session exists: ${authResponse.session != null}');

        // Small delay to ensure session is fully synced before checking profile
        await Future.delayed(const Duration(milliseconds: 300));

        await _handlePostSignIn(authResponse.user!);
      } else {
        throw Exception('Authentication succeeded but no user returned');
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      // User canceled or auth failed
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('_handleAppleSignIn: User canceled');
        // Don't show error for cancellation
      } else {
        _showSnackBar('Apple Sign-In failed: ${e.message}');
        debugPrint(
            'Apple Sign-In authorization error: ${e.code} - ${e.message}');
      }
    } catch (e) {
      _showSnackBar('Apple Sign-In failed: $e');
      debugPrint('Apple Sign-In error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Generate a cryptographically secure nonce for Apple Sign-In
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  Future<void> _handlePostSignIn(User user) async {
    try {
      debugPrint('_handlePostSignIn: Checking profile for user ${user.id}');

      // Check current session
      final session = _supabase.auth.currentSession;
      debugPrint(
          '_handlePostSignIn: Current session exists: ${session != null}, user: ${session?.user.id}');

      // Check if user exists in Supabase
      final response = await _supabase
          .from('users')
          .select('display_name')
          .eq('uid', user.id)
          .maybeSingle();

      debugPrint('_handlePostSignIn: Response = $response');

      if (response == null || response['display_name'] == null) {
        debugPrint(
            '_handlePostSignIn: No display name found, showing name dialog');
        _showNameDialog(user);
      } else {
        debugPrint(
            '_handlePostSignIn: Display name found: ${response['display_name']}');
        debugPrint(
            '⚠️  WARNING: Supabase session is NULL - check dashboard settings:');
        debugPrint('   Authentication → Settings → Email Auth');
        debugPrint('   Disable "Confirm email" for development');

        // TEMPORARY WORKAROUND: Navigate manually since session isn't created
        // TODO: Fix Supabase email confirmation settings
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ChatGroupsScreen()),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking user profile: $e');
      // If error, show name dialog to be safe
      _showNameDialog(user);
    }
  }

  void _showNameDialog(User user) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
      debugPrint('_saveName: Saving name "$name" for user ${user.id}');

      // Update or insert user in Supabase
      final now = DateTime.now().toIso8601String();
      await _supabase.from('users').upsert({
        'uid': user.id,
        'display_name': name.trim(),
        'email': user.email ?? 'unknown@user.com',
        'created_at': now,
        'updated_at': now,
      });

      debugPrint('_saveName: Name saved successfully');

      if (mounted) {
        Navigator.pop(context);
        // Navigate to main app since session won't be created
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ChatGroupsScreen()),
        );
      }
    } catch (e) {
      debugPrint('_saveName: Error saving name: $e');
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

  void _onEmailButtonPressed() {
    if (!_isLoading) {
      _handleEmailAuth();
    }
  }

  void _onGoogleButtonPressed() {
    if (!_isLoading) {
      _handleGoogleSignIn();
    }
  }

  void _onAppleButtonPressed() {
    if (!_isLoading) {
      _handleAppleSignIn();
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
              'Enter your email address and we\'ll send you a password reset link.',
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
          _showSnackBar('Password reset email sent! Check your inbox.');
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
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to SquadSync',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your email',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
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
                    onSubmitted: (_) => _onEmailButtonPressed(),
                    enabled: !_isLoading,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _showForgotPasswordDialog,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _onEmailButtonPressed,
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Sign In / Register',
                            style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _onGoogleButtonPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/google_logo.png',
                            height: 24), // Add Google logo asset
                        const SizedBox(width: 8),
                        const Text('Sign in with Google',
                            style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SignInWithAppleButton(
                    onPressed: _onAppleButtonPressed,
                    style: SignInWithAppleButtonStyle.black,
                  ),
                ],
              ),
            ),
          ),
          // Loading overlay to prevent interaction during auth
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
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
    );
  }
}
