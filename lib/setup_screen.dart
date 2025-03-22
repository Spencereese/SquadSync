import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'squad_queue_logic.dart';
import 'squad_queue_ui.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  SetupScreenState createState() => SetupScreenState();
}

class SetupScreenState extends State<SetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkUser();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _checkUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('yourName');
      if (savedName != null &&
          savedName.isNotEmpty &&
          _auth.currentUser != null) {
        if (mounted) {
          _navigateToSquadQueue(savedName);
        }
      }
    } catch (e) {
      debugPrint('Error checking user: $e');
    }
  }

  Future<void> _signIn() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Please enter your name');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.signInAnonymously();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('yourName', name);

      if (mounted) {
        _navigateToSquadQueue(name);
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Sign-in failed: ${e.message}');
    } catch (e) {
      _showSnackBar('An unexpected error occurred');
      debugPrint('Sign-in error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToSquadQueue(String name) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SquadQueuePage(yourName: name),
      ),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Your Name',
                  border: OutlineInputBorder(),
                  hintText: 'Enter your name',
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _signIn,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Join the Squad',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
