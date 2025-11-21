import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../managers/game_manager.dart';
import '../../chat/chat_groups_screen.dart';
import '../../services/app_flow_manager.dart';
import '../../widgets/async_value_widget.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final DateTime _onboardingStartTime = DateTime.now();

  // Step 1: Profile
  final TextEditingController _displayNameController = TextEditingController();
  File? _avatarFile;
  bool _isUploadingAvatar = false;

  // Step 2: Games
  final TextEditingController _gameSearchController = TextEditingController();
  final List<Map<String, dynamic>> _pinnedGames = [];

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
                (_displayNameController.text.isNotEmpty && !_isUploadingAvatar)
                    ? _nextStep
                    : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: _isUploadingAvatar
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Next'),
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
            child: AsyncValueWidget<GameState>(
              value: ref.watch(gameManagerProvider),
              data: (gameState) => gameState.isOffline
                  ? Banner(
                      message: 'Using offline cache',
                      location: BannerLocation.topEnd,
                      child: _buildGameList(gameState.games),
                    )
                  : _buildGameList(gameState.games),
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Searching games...'),
                  ],
                ),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'API error: ${error.toString()}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(gameManagerProvider.notifier)
                            .fetchGamesFromIGDB(_gameSearchController.text);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
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
    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      debugPrint('Starting profile save...');
      String? avatarUrl;
      if (_avatarFile != null) {
        debugPrint('Uploading avatar...');
        avatarUrl = await _uploadAvatar();
        debugPrint('Avatar uploaded: $avatarUrl');
      }

      // Save display name and avatar URL
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('Saving to Firestore for user: ${user.uid}');
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': _displayNameController.text,
          'avatarUrl': avatarUrl,
        }, SetOptions(merge: true));
        debugPrint('Profile saved successfully');
      } else {
        debugPrint('No current user found');
        throw Exception('User not authenticated');
      }

      debugPrint('Navigating to next step...');
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } catch (e) {
      debugPrint('Error in _nextStep: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    }
  }

  Future<String?> _uploadAvatar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _avatarFile == null) return null;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      debugPrint('Starting avatar upload for user: ${user.uid}');
      final ref =
          FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
      final uploadTask = ref.putFile(_avatarFile!);

      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() => null);
      debugPrint('Upload task completed');

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Download URL obtained: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      throw Exception('Failed to upload avatar: $e');
    } finally {
      setState(() {
        _isUploadingAvatar = false;
      });
    }
  }

  void _searchGames() async {
    if (_gameSearchController.text.isEmpty) return;

    try {
      await ref
          .read(gameManagerProvider.notifier)
          .fetchGamesFromIGDB(_gameSearchController.text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Widget _buildGameList(List<Map<String, dynamic>> games) {
    return ListView.builder(
      itemCount: games.length,
      itemBuilder: (context, index) {
        final game = games[index];
        final isPinned = _pinnedGames.any((g) => g['id'] == game['id']);
        return ListTile(
          title: Text(game['name']),
          trailing: IconButton(
            icon: Icon(isPinned ? Icons.star : Icons.star_border),
            onPressed: () => _togglePinGame(game),
          ),
        );
      },
    );
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
