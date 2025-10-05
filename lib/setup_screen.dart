import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
// import 'package:google_sign_in/google_sign_in.dart'; // TODO: Re-enable when v7 API is updated
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../squad_state.dart';
import 'squad_tab/squad_queue_page.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  SetupScreenState createState() => SetupScreenState();
}

class SetupScreenState extends State<SetupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // TODO: Update Google Sign In for v7 API
  // final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // TODO: Update Google Sign In initialization for v7 API
    // _googleSignIn = GoogleSignIn();
    _checkUser();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null && mounted) {
        final squadState = Provider.of<SquadState>(context, listen: false);
        await squadState.initialize(context);
        if (mounted) {
          _navigateToSquadQueue();
        }
      }
    } catch (e) {
      debugPrint('Error checking user: $e');
    }
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
      UserCredential userCredential;
      try {
        userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } catch (signInError) {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      await _handlePostSignIn(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Authentication failed: ${e.message}');
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
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
      );
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await _handlePostSignIn(userCredential.user!);
    } catch (e) {
      _showSnackBar('Apple Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePostSignIn(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists || userDoc.data()?['displayName'] == null) {
      _showNameDialog(user);
    } else {
      if (!mounted) return;
      final squadState = Provider.of<SquadState>(context, listen: false);
      await squadState.initialize(context);
      if (mounted) {
        _navigateToSquadQueue();
      }
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
      await _firestore.collection('users').doc(user.uid).set({
        'displayName': name.trim(),
      }, SetOptions(merge: true));
      if (mounted) {
        final squadState = Provider.of<SquadState>(context, listen: false);
        await squadState.initialize(context);
        if (mounted) {
          Navigator.pop(context);
          _navigateToSquadQueue();
        }
      }
    } catch (e) {
      _showSnackBar('Error saving name: $e');
    }
  }

  void _navigateToSquadQueue() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SquadQueuePage()),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
              const SizedBox(height: 32),
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
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  hintText: 'Enter your password',
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _onEmailButtonPressed(),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
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
    );
  }
}
