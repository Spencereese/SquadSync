import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../presentation/notifiers/user_notifier.dart';
import '../domain/entities/app_user.dart';
import '../services/media_service.dart';

class ProfileEditingScreen extends ConsumerStatefulWidget {
  const ProfileEditingScreen({super.key});

  @override
  ConsumerState<ProfileEditingScreen> createState() =>
      _ProfileEditingScreenState();
}

class _ProfileEditingScreenState extends ConsumerState<ProfileEditingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  bool _isLoading = false;
  File? _selectedImage;
  final MediaService _mediaService = MediaService();

  @override
  void initState() {
    super.initState();
    final userAsync = ref.read(userNotifierProvider);
    _displayNameController = TextEditingController(
      text: userAsync.maybeWhen(
        data: (user) => user?.displayName ?? '',
        orElse: () => '',
      ),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userNotifier = ref.read(userNotifierProvider.notifier);

      // Update display name
      await userNotifier.updateDisplayName(_displayNameController.text.trim());

      // Update profile image if selected
      if (_selectedImage != null) {
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final imageUrl = await _mediaService.uploadMediaWithSignedUrl(
          _selectedImage!,
          fileName,
        );
        await userNotifier.updateProfileImage(imageUrl);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.robotoMono(),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile: $e',
              style: GoogleFonts.robotoMono(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.robotoMono(
            fontWeight: FontWeight.bold,
            color: Colors.cyan,
          ),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.cyan),
      ),
      backgroundColor: Colors.black,
      body: userAsync.when(
        data: (user) => _buildForm(user),
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.cyan),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading profile: $error',
            style: GoogleFonts.robotoMono(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AppUser? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Profile Image
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.cyan.withValues(alpha: 0.2),
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : (user?.profileImage != null &&
                                user!.profileImage!.isNotEmpty
                            ? NetworkImage(user.profileImage!)
                            : null) as ImageProvider?,
                    child: _selectedImage == null && user?.profileImage == null
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.cyan,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.cyan,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap to change profile picture',
              style: GoogleFonts.robotoMono(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 32),

            // Display Name
            TextFormField(
              controller: _displayNameController,
              style: GoogleFonts.robotoMono(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: GoogleFonts.robotoMono(color: Colors.cyan),
                hintText: 'Enter your display name',
                hintStyle: GoogleFonts.robotoMono(color: Colors.grey),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan, width: 2),
                ),
                errorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
                focusedErrorBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Display name cannot be empty';
                }
                if (value.trim().length < 2) {
                  return 'Display name must be at least 2 characters';
                }
                if (value.trim().length > 30) {
                  return 'Display name cannot exceed 30 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.robotoMono(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
