import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_theme.dart';
import '../../../services/supabase_service.dart';
import '../../../services/auth_service_supabase.dart';

/// Glassmorphic circular button used throughout chat info screen
class ChatInfoGlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color neonColor;

  const ChatInfoGlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: neonColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: neonColor.neonGlow(
          blur: 12,
          opacity: 0.3,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(
              icon,
              color: neonColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Member avatar with online status indicator and role badge
class ChatInfoMemberAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isOnline;
  final String? role;
  final Color neonColor;

  const ChatInfoMemberAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.isOnline,
    this.role,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOnline
                        ? AppTheme.success(Theme.of(context).colorScheme)
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  child: avatarUrl == null
                      ? Icon(Icons.person, color: neonColor, size: 24)
                      : null,
                ),
              ),
              // Role badge
              if (role != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: role == 'admin'
                          ? AppTheme.warning(Theme.of(context).colorScheme)
                          : neonColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      role == 'admin' ? Icons.star : Icons.shield,
                      size: 12,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Large circular action button with label and optional badge
class ChatInfoBigActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color neonColor;
  final VoidCallback onPressed;
  final String? badge;

  const ChatInfoBigActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.neonColor,
    required this.onPressed,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: neonColor.withOpacity(0.4),
                      width: 2,
                    ),
                    boxShadow: neonColor.neonGlow(
                      blur: 20,
                      opacity: 0.4,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPressed,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(
                          icon,
                          color: neonColor,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (badge != null)
              Positioned(
                top: -4,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warning(Theme.of(context).colorScheme),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warning(Theme.of(context).colorScheme)
                            .withOpacity(0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: neonColor,
          ),
        ),
      ],
    );
  }
}

/// Edit squad modal sheet
class ChatInfoEditLobbySheet extends StatelessWidget {
  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final VoidCallback onEditName;

  const ChatInfoEditLobbySheet({
    super.key,
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    required this.onEditName,
  });

  @override
  Widget build(BuildContext context) {
    final neonColor = Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            border: Border(
              top: BorderSide(
                color: neonColor.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Edit Lobby',
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: neonColor,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Icon(Icons.edit, color: neonColor),
                title: const Text('Change Lobby Name'),
                trailing: Icon(Icons.chevron_right,
                    color: neonColor.withOpacity(0.5)),
                onTap: () {
                  Navigator.pop(context);
                  onEditName();
                },
              ),
              ListTile(
                leading: Icon(Icons.image, color: neonColor),
                title: const Text('Change Lobby Avatar'),
                trailing: Icon(Icons.chevron_right,
                    color: neonColor.withOpacity(0.5)),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadLobbyAvatar(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick and upload lobby avatar
  Future<void> _pickAndUploadLobbyAvatar(BuildContext context) async {
    try {
      // Import image_picker dynamically to avoid static import
      final ImagePicker picker = ImagePicker();

      // Pick image from gallery
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!context.mounted) return;

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );

      try {
        // Get current user ID for folder structure (RLS requirement)
        final user = AuthServiceSupabase().currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }

        // Upload to Supabase Storage (avatars bucket)
        // Path MUST be {user_uid}/filename for RLS policy compliance
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'lobby_${squadId}_$timestamp.jpg';
        final storagePath = '${user.id}/$fileName';

        // Read file as bytes
        final bytes = await image.readAsBytes();

        // Upload to Supabase Storage
        final supabase = SupabaseService.client;
        await supabase.storage.from('avatars').uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );

        // Get public URL
        final downloadUrl =
            supabase.storage.from('avatars').getPublicUrl(storagePath);

        // Update lobby avatar in database
        await supabase.from('lobbies').update({
          'avatar_url': downloadUrl,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', squadId);

        if (!context.mounted) return;

        // Close loading dialog
        Navigator.pop(context);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lobby avatar updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (uploadError) {
        if (!context.mounted) return;

        // Close loading dialog
        Navigator.pop(context);

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload avatar: $uploadError'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Add member search and selection modal sheet
class ChatInfoAddMemberSheet extends StatefulWidget {
  final String squadId;

  const ChatInfoAddMemberSheet({
    super.key,
    required this.squadId,
  });

  @override
  State<ChatInfoAddMemberSheet> createState() => _ChatInfoAddMemberSheetState();
}

class _ChatInfoAddMemberSheetState extends State<ChatInfoAddMemberSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final neonColor = Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            border: Border(
              top: BorderSide(
                color: neonColor.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Member',
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: neonColor,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by username...',
                  prefixIcon: Icon(Icons.search, color: neonColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: neonColor.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: neonColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: neonColor, width: 2),
                  ),
                ),
                onChanged: (value) async {
                  if (value.trim().isEmpty) {
                    setState(() {
                      _searchResults.clear();
                    });
                    return;
                  }

                  // Search users by username
                  try {
                    final results = await SupabaseService.client
                        .from('users')
                        .select('uid, display_name, photo_url')
                        .ilike('display_name', '%$value%')
                        .limit(10);

                    setState(() {
                      _searchResults = results
                          .map((row) => {
                                'uid': row['uid'],
                                'name': row['display_name'] ?? 'Unknown',
                                'avatarUrl': row['photo_url'],
                              })
                          .toList();
                    });
                  } catch (e) {
                    debugPrint('Error searching users: $e');
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_searchResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Search for users to add to your lobby',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom background selection modal sheet
class ChatInfoCustomBackgroundSheet extends StatelessWidget {
  final String squadId;

  const ChatInfoCustomBackgroundSheet({
    super.key,
    required this.squadId,
  });

  @override
  Widget build(BuildContext context) {
    final neonColor = Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            border: Border(
              top: BorderSide(
                color: neonColor.withOpacity(0.3),
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Custom Background',
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: neonColor,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Icon(Icons.photo_library, color: neonColor),
                title: const Text('Choose from Gallery'),
                trailing: Icon(Icons.chevron_right,
                    color: neonColor.withOpacity(0.5)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Add image_picker package: flutter pub add image_picker'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.color_lens, color: neonColor),
                title: const Text('Solid Color'),
                trailing: Icon(Icons.chevron_right,
                    color: neonColor.withOpacity(0.5)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Add flutter_colorpicker package: flutter pub add flutter_colorpicker'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.gradient, color: neonColor),
                title: const Text('Custom Gradient'),
                trailing: Icon(Icons.chevron_right,
                    color: neonColor.withOpacity(0.5)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Gradient builder coming soon!'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen image viewer with pinch-to-zoom
class ChatInfoFullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const ChatInfoFullScreenImageViewer({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.error,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
