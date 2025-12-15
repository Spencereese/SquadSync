import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/image_crop_helper.dart';

class AvatarSelectionWidget extends StatefulWidget {
  final String? initialAvatarPath;
  final Function(String avatarPath, Color accentColor) onAvatarSelected;

  const AvatarSelectionWidget({
    super.key,
    this.initialAvatarPath,
    required this.onAvatarSelected,
  });

  @override
  State<AvatarSelectionWidget> createState() => _AvatarSelectionWidgetState();
}

class _AvatarSelectionWidgetState extends State<AvatarSelectionWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  int? _selectedPresetIndex;
  File? _uploadedImage;

  // 8 Cyber presets with neon colors
  final List<AvatarPreset> _presets = [
    AvatarPreset(
      name: 'Chrome Skull',
      assetPath: 'assets/images/avatars/chrome_skull.png',
      glowColor: const Color(0xFF00E5FF), // Cyan
      icon: Icons.person_pin,
    ),
    AvatarPreset(
      name: 'Glitch Mask',
      assetPath: 'assets/images/avatars/glitch_mask.png',
      glowColor: const Color(0xFFFF00FF), // Magenta
      icon: Icons.masks,
    ),
    AvatarPreset(
      name: 'Hooded Silhouette',
      assetPath: 'assets/images/avatars/hooded_silhouette.png',
      glowColor: const Color(0xFF00FF41), // Matrix green
      icon: Icons.person_outline,
    ),
    AvatarPreset(
      name: 'Neon Visor',
      assetPath: 'assets/images/avatars/neon_visor.png',
      glowColor: const Color(0xFFFF3D00), // Orange-red
      icon: Icons.visibility,
    ),
    AvatarPreset(
      name: 'Cyber Ghost',
      assetPath: 'assets/images/avatars/cyber_ghost.png',
      glowColor: const Color(0xFF7C4DFF), // Purple
      icon: Icons.auto_awesome,
    ),
    AvatarPreset(
      name: 'Circuit Face',
      assetPath: 'assets/images/avatars/circuit_face.png',
      glowColor: const Color(0xFF00E676), // Bright green
      icon: Icons.settings_input_composite,
    ),
    AvatarPreset(
      name: 'Void Warrior',
      assetPath: 'assets/images/avatars/void_warrior.png',
      glowColor: const Color(0xFFFFEA00), // Yellow
      icon: Icons.shield,
    ),
    AvatarPreset(
      name: 'Digital Phantom',
      assetPath: 'assets/images/avatars/digital_phantom.png',
      glowColor: const Color(0xFF00BCD4), // Light cyan
      icon: Icons.flutter_dash,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Color get _currentGlowColor {
    if (_selectedPresetIndex != null) {
      return _presets[_selectedPresetIndex!].glowColor;
    }
    return Colors.cyan; // Default for uploaded images
  }

  Future<void> _pickImage() async {
    try {
      final croppedFile =
          await ImageCropHelper.pickAndCropProfileImage(context);

      if (croppedFile != null) {
        setState(() {
          _uploadedImage = croppedFile;
          _selectedPresetIndex = null; // Clear preset selection
        });

        HapticFeedback.mediumImpact();
        widget.onAvatarSelected(croppedFile.path, Colors.cyan);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _selectPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _uploadedImage = null; // Clear uploaded image
    });

    HapticFeedback.selectionClick();
    widget.onAvatarSelected(
      _presets[index].assetPath,
      _presets[index].glowColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Big center avatar preview with neon glow
        _buildAvatarPreview(),
        const SizedBox(height: 32),

        // Upload button
        _buildUploadButton(),
        const SizedBox(height: 24),

        // Divider with text
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      _currentGlowColor.withOpacity(0.5),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR CHOOSE PRESET',
                style: TextStyle(
                  color: _currentGlowColor.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _currentGlowColor.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Horizontal scroll of presets
        _buildPresetScroller(),
      ],
    );
  }

  Widget _buildAvatarPreview() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = Tween<double>(begin: 0.5, end: 1.0).animate(
          CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
        );

        return Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              // Outer glow
              BoxShadow(
                color: _currentGlowColor.withOpacity(0.4 * glowIntensity.value),
                blurRadius: 40,
                spreadRadius: 10,
              ),
              // Inner glow
              BoxShadow(
                color: _currentGlowColor.withOpacity(0.6 * glowIntensity.value),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _currentGlowColor,
                width: 3,
              ),
              color: const Color(0xFF0B0E14),
            ),
            child: ClipOval(
              child: _buildAvatarContent(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarContent() {
    // Show uploaded image
    if (_uploadedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            _uploadedImage!,
            fit: BoxFit.cover,
          ),
          // Neon glow filter overlay
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  _currentGlowColor.withOpacity(0.1),
                  _currentGlowColor.withOpacity(0.2),
                ],
                stops: const [0.5, 0.8, 1.0],
              ),
            ),
          ),
        ],
      );
    }

    // Show preset
    if (_selectedPresetIndex != null) {
      final preset = _presets[_selectedPresetIndex!];
      return Stack(
        fit: StackFit.expand,
        children: [
          // Use icon as fallback since assets may not exist yet
          Container(
            color: Colors.black87,
            child: Icon(
              preset.icon,
              size: 80,
              color: preset.glowColor.withOpacity(0.8),
            ),
          ),
          // Neon glow filter
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Colors.transparent,
                  preset.glowColor.withOpacity(0.1),
                  preset.glowColor.withOpacity(0.2),
                ],
                stops: const [0.5, 0.8, 1.0],
              ),
            ),
          ),
        ],
      );
    }

    // Default placeholder
    return Container(
      color: Colors.black26,
      child: Icon(
        Icons.person,
        size: 80,
        color: _currentGlowColor.withOpacity(0.3),
      ),
    );
  }

  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _currentGlowColor.withOpacity(0.2),
              _currentGlowColor.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: _currentGlowColor.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _currentGlowColor.withOpacity(0.2),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.upload_file,
              color: _currentGlowColor,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'UPLOAD CUSTOM',
              style: TextStyle(
                color: _currentGlowColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetScroller() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _presets.length,
        itemBuilder: (context, index) {
          return _buildPresetItem(index);
        },
      ),
    );
  }

  Widget _buildPresetItem(int index) {
    final preset = _presets[index];
    final isSelected = _selectedPresetIndex == index;

    return GestureDetector(
      onTap: () => _selectPreset(index),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            // Preset avatar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? preset.glowColor
                      : preset.glowColor.withOpacity(0.3),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: preset.glowColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: Container(
                  color: Colors.black87,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fallback icon (replace with actual asset when available)
                      Icon(
                        preset.icon,
                        size: 40,
                        color: preset.glowColor.withOpacity(0.8),
                      ),
                      // Glow overlay
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                Colors.transparent,
                                preset.glowColor.withOpacity(0.2),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Preset name
            SizedBox(
              width: 80,
              child: Text(
                preset.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? preset.glowColor : Colors.grey.shade500,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AvatarPreset {
  final String name;
  final String assetPath;
  final Color glowColor;
  final IconData icon; // Fallback icon when asset doesn't exist

  AvatarPreset({
    required this.name,
    required this.assetPath,
    required this.glowColor,
    required this.icon,
  });
}
