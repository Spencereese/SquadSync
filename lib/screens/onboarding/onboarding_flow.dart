import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../managers/game_manager.dart';
import '../../chat/chat_groups_screen.dart';
import '../../services/app_flow_manager.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final DateTime _onboardingStartTime = DateTime.now();

  // Step 1: Profile
  final TextEditingController _displayNameController = TextEditingController();
  File? _avatarFile;
  bool _isUploadingAvatar = false;

  // Step 2: Games
  final TextEditingController _gameSearchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final List<Map<String, dynamic>> _pinnedGames = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _displayNameController.dispose();
    _gameSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Setup (${_currentStep + 1}/2)'),
        automaticallyImplyLeading: false,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (page) {
          setState(() {
            _currentStep = page;
          });
        },
        children: [
          _buildStep1(),
          _buildStep2(),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Create Your Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _pickAvatar,
            child: CircleAvatar(
              radius: 60,
              backgroundImage:
                  _avatarFile != null ? FileImage(_avatarFile!) : null,
              child: _avatarFile == null
                  ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                  : _isUploadingAvatar
                      ? const CircularProgressIndicator()
                      : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed:
                _displayNameController.text.isNotEmpty ? _nextStep : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pin Your Favorite Games',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _gameSearchController,
            decoration: InputDecoration(
              labelText: 'Search games...',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _searchGames,
              ),
            ),
            onSubmitted: (_) => _searchGames(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final game = _searchResults[index];
                      final isPinned =
                          _pinnedGames.any((g) => g['id'] == game['id']);
                      return ListTile(
                        title: Text(game['name']),
                        trailing: IconButton(
                          icon: Icon(isPinned ? Icons.star : Icons.star_border),
                          onPressed: () => _togglePinGame(game),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _pinnedGames.isNotEmpty ? _completeOnboarding : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Get Started'),
          ),
        ],
      ),
    );
  }

  void _pickAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
    }
  }

  void _nextStep() async {
    if (_avatarFile != null) {
      setState(() {
        _isUploadingAvatar = true;
      });
      await _uploadAvatar();
      setState(() {
        _isUploadingAvatar = false;
      });
    }

    // Save display name
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': _displayNameController.text,
        'avatarUrl': _avatarFile != null ? await _getAvatarUrl() : null,
      }, SetOptions(merge: true));
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _uploadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _avatarFile != null) {
      final ref =
          FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
      await ref.putFile(_avatarFile!);
    }
  }

  Future<String?> _getAvatarUrl() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final ref =
          FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
      return await ref.getDownloadURL();
    }
    return null;
  }

  void _searchGames() async {
    if (_gameSearchController.text.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    final gameManager =
        provider.Provider.of<GameManager>(context, listen: false);
    final results = await gameManager.searchGames(_gameSearchController.text);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _togglePinGame(Map<String, dynamic> game) {
    setState(() {
      if (_pinnedGames.any((g) => g['id'] == game['id'])) {
        _pinnedGames.removeWhere((g) => g['id'] == game['id']);
      } else {
        _pinnedGames.add(game);
      }
    });
  }

  void _completeOnboarding() async {
    final container = ProviderScope.containerOf(context);
    final analytics = container.read(appFlowManagerProvider);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'pinnedGames': _pinnedGames,
      }, SetOptions(merge: true));

      // Track onboarding completion analytics
      await analytics.trackOnboardingCompleted(
        userId: user.uid,
        gamesPinned: _pinnedGames.length,
        timeSpent: DateTime.now().difference(_onboardingStartTime),
      );
    }

    if (!mounted) return;

    // Update onboarding status - assuming it's handled elsewhere or add to shared preferences
    // For now, just navigate

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const ChatGroupsScreen()),
    );
  }
}
