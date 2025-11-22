import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/onboarding_service.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const ProfileSetupScreen({super.key, required this.onNext});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _displayNameController = TextEditingController();
  File? _avatarFile;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final onboardingState = ref.read(onboardingServiceProvider);
    if (onboardingState.value?.displayName != null) {
      _displayNameController.text = onboardingState.value!.displayName!;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingServiceProvider);
    final nameValid = (onboardingState.value?.displayName?.length ?? 0) > 3;
    final avatarValid = onboardingState.value?.avatarUrl != null;
    final isValid = nameValid && avatarValid;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Create Your Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: _pickAvatar,
            child: CircleAvatar(
              radius: 60,
              backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
              child: _avatarFile == null
                  ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                  : _isUploadingAvatar
                      ? const CircularProgressIndicator()
                      : null,
            ).animate().scale(duration: 300.ms),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _displayNameController,
            decoration: InputDecoration(
              labelText: 'Display Name',
              border: const OutlineInputBorder(),
              errorText: (_displayNameController.text.isNotEmpty && _displayNameController.text.length <= 3)
                  ? 'Display name must be longer than 3 characters'
                  : null,
            ),
            onChanged: (value) => _updateProfile(),
          ).animate().slideX(begin: -0.2, duration: 400.ms),
          const Spacer(),
          if (!isValid)
            Text(
              onboardingState.value?.avatarUrl == null
                  ? 'Please upload an avatar to continue'
                  : 'Please enter a valid display name',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ).animate().fadeIn(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isValid ? () => _nextStep(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
          ).animate().slideY(begin: 0.2, duration: 400.ms),
        ],
      ),
    );
  }

  void _pickAvatar() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _avatarFile = File(pickedFile.path);
      });
      await _uploadAvatar();
    }
  }

  Future<void> _uploadAvatar() async {
    if (_avatarFile == null) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      final onboardingService = ref.read(onboardingServiceProvider.notifier);
      final avatarUrl = await onboardingService.uploadAvatar(_avatarFile!);
      if (avatarUrl != null) {
        await onboardingService.updateProfile(_displayNameController.text, avatarUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload avatar: $e')),
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

  void _updateProfile() async {
    final onboardingService = ref.read(onboardingServiceProvider.notifier);
    final currentState = ref.read(onboardingServiceProvider).value;
    await onboardingService.updateProfile(_displayNameController.text, currentState?.avatarUrl ?? '');
  }

  void _nextStep(BuildContext context) {
    HapticFeedback.mediumImpact();
    widget.onNext();
  }
}