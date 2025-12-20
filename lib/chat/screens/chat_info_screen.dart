import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_theme.dart';
import '../models/message_data.dart';
import '../widgets/clip_message_bubble.dart';
import '../link_preview.dart';
import '../../domain/entities/message.dart' hide MessageType;
import '../models/message_data.dart' show MessageType;
import '../../services/background_service.dart';
import '../../core/utils/image_crop_helper.dart';
import 'components/chat_info_widgets.dart';
import 'components/chat_info_app_bar.dart';
import 'components/chat_info_members.dart';
import 'components/chat_info_actions.dart';
import 'components/chat_info_settings.dart';
import 'components/chat_info_backgrounds.dart';
import 'components/chat_info_media.dart';
import 'components/chat_info_links_files.dart';
import '../../domain/entities/message.dart' show ChatType;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/chat_notifier.dart' as cn;
import '../../presentation/notifiers/user_notifier.dart';
import '../services/chat_message_search_delegate.dart';
import '../widgets/background_preview_screen.dart';

/// Chat/Squad info screen with perfect iMessage layout in glass style
///
/// Features:
/// - Custom glass app bar with hero avatar and edit button
/// - Horizontal member avatars with online status and role badges
/// - Three large glass circular action buttons
/// - Segmented control tabs for content sections
/// - Full screen scrollable TabBarView
class ChatInfoScreen extends ConsumerStatefulWidget {
  final String squadId;
  final String squadName;
  final String? avatarUrl;
  final List<Map<String, dynamic>>? members;
  final ChatType chatType;

  const ChatInfoScreen({
    super.key,
    required this.squadId,
    required this.squadName,
    this.avatarUrl,
    this.members,
    this.chatType = ChatType.squad,
  });

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedSegment = 0;
  bool _notificationsEnabled = true;
  bool _hideAlerts = false;
  late final BackgroundService _backgroundService;

  @override
  void initState() {
    super.initState();
    _backgroundService = BackgroundService();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedSegment = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neonColor = Colors.white;
    final members = widget.members ?? [];

    return Stack(
      children: [
        // Full-screen blur for liquid glass effect
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              color: Colors.black.withOpacity(0.6),
            ),
          ),
        ),
        // Main content
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(
            children: [
              // Custom app bar
              ChatInfoAppBar(
                squadId: widget.squadId,
                squadName: widget.squadName,
                avatarUrl: widget.avatarUrl,
                neonColor: neonColor,
                onEditPressed: () => _showEditSheet(context),
                onSearchPressed: () => _showMessageSearch(context),
              ),

              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Member avatars horizontal scroll
                      ChatInfoMembersSection(
                        squadId: widget.squadId,
                        members: members,
                        neonColor: neonColor,
                        onAddMemberPressed: () => _showAddMemberSheet(context),
                      ),

                      const SizedBox(
                          height: 24), // Three big glass circular buttons
                      ChatInfoActionsSection(
                        squadId: widget.squadId,
                        squadName: widget.squadName,
                        neonColor: neonColor,
                      ),

                      const SizedBox(height: 24),

                      // Segmented control tabs
                      _buildSegmentedControl(context, neonColor),

                      const SizedBox(height: 16),

                      // Tab content
                      _buildTabContent(context, neonColor),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Glass segmented control for tabs
  Widget _buildSegmentedControl(BuildContext context, Color neonColor) {
    final tabs = ['Info', 'Backgrounds', 'Clips', 'Photos', 'Links', 'Files'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: List.generate(tabs.length, (index) {
                final isSelected = _selectedSegment == index;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSegment = index;
                      _tabController.animateTo(index);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.25)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      tabs[index],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  /// Tab content based on selected segment
  Widget _buildTabContent(BuildContext context, Color neonColor) {
    switch (_selectedSegment) {
      case 0:
        return ChatInfoSettingsTab(
          builder: _buildInfoTab,
          neonColor: neonColor,
        );
      case 1:
        return ChatInfoBackgroundsTab(
          builder: _buildBackgroundsTab,
          neonColor: neonColor,
        );
      case 2:
        return ChatInfoMediaTab(
          builder: _buildClipsTab,
          neonColor: neonColor,
        );
      case 3:
        return ChatInfoMediaTab(
          builder: _buildPhotosTab,
          neonColor: neonColor,
        );
      case 4:
        return ChatInfoLinksFilesTab(
          builder: _buildLinksTab,
          neonColor: neonColor,
        );
      case 5:
        return ChatInfoLinksFilesTab(
          builder: _buildFilesTab,
          neonColor: neonColor,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildInfoTab(BuildContext context, Color neonColor) {
    final members = widget.members ?? [];

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Notifications toggle
        _buildToggleCard(
          context,
          neonColor,
          'Notifications',
          Icons.notifications,
          _notificationsEnabled,
          (value) async {
            setState(() {
              _notificationsEnabled = value;
            });

            // Save to Supabase user_groups
            try {
              final currentUser = AuthServiceSupabase().currentUser;
              if (currentUser != null) {
                // Fetch current user_groups
                final response = await SupabaseService.client
                    .from('users')
                    .select('user_groups')
                    .eq('uid', currentUser.id)
                    .maybeSingle();

                if (response != null) {
                  final userGroups = List<Map<String, dynamic>>.from(
                      response['user_groups'] ?? []);

                  // Find and update the specific group
                  final groupIndex = userGroups
                      .indexWhere((g) => g['chat_group_id'] == widget.squadId);

                  if (groupIndex != -1) {
                    userGroups[groupIndex]['notifications_enabled'] = value;

                    await SupabaseService.client.from('users').update({
                      'user_groups': userGroups,
                    }).eq('uid', currentUser.id);
                  }
                }
              }
            } catch (e) {
              debugPrint('Error saving notification setting: $e');
            }
          },
        ),
        const SizedBox(height: 8),

        // Hide Alerts toggle
        _buildToggleCard(
          context,
          neonColor,
          'Hide Alerts',
          Icons.notifications_off,
          _hideAlerts,
          (value) async {
            setState(() {
              _hideAlerts = value;
            });

            // Save to Supabase user_groups
            try {
              final currentUser = AuthServiceSupabase().currentUser;
              if (currentUser != null) {
                // Fetch current user_groups
                final response = await SupabaseService.client
                    .from('users')
                    .select('user_groups')
                    .eq('uid', currentUser.id)
                    .maybeSingle();

                if (response != null) {
                  final userGroups = List<Map<String, dynamic>>.from(
                      response['user_groups'] ?? []);

                  // Find and update the specific group
                  final groupIndex = userGroups
                      .indexWhere((g) => g['chat_group_id'] == widget.squadId);

                  if (groupIndex != -1) {
                    userGroups[groupIndex]['hide_alerts'] = value;

                    await SupabaseService.client.from('users').update({
                      'user_groups': userGroups,
                    }).eq('uid', currentUser.id);
                  }
                }
              }
            } catch (e) {
              debugPrint('Error saving hide alerts setting: $e');
            }
          },
        ),
        const SizedBox(height: 24),

        // Lobby System section
        _buildSectionHeader(context, neonColor, 'Lobby System'),
        const SizedBox(height: 12),
        _buildLobbyInfoCard(context, neonColor),
        const SizedBox(height: 24),

        // Member list section
        _buildSectionHeader(context, neonColor, 'Members'),
        const SizedBox(height: 12),
        _buildMemberListCard(context, neonColor, members),
        const SizedBox(height: 16),

        // Add Member button
        _buildActionCard(
          context,
          neonColor,
          'Add Member',
          Icons.person_add,
          () => _showAddMemberSheet(context),
        ),
        const SizedBox(height: 8),

        // Share Lobby Link button
        _buildActionCard(
          context,
          neonColor,
          'Share Lobby Link',
          Icons.share,
          () => _generateAndShareLobbyLink(context),
        ),
        const SizedBox(height: 24),

        // Peacock Queue section (if squad)
        _buildSectionHeader(context, neonColor, 'Peacock Queue'),
        const SizedBox(height: 12),
        _buildPeacockQueueCard(context, neonColor),
        const SizedBox(height: 24),

        // Lobby Spots section (if applicable)
        _buildSectionHeader(context, neonColor, 'Lobby Spots'),
        const SizedBox(height: 12),
        _buildLobbySpotsCard(context, neonColor),
        const SizedBox(height: 32),

        // Danger zone: Clear Chat & Leave Group/Lobby
        _buildSectionHeader(
          context,
          Theme.of(context).colorScheme.error,
          'Danger Zone',
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          Theme.of(context).colorScheme.error,
          'Clear Chat History',
          Icons.delete_sweep,
          () => _showClearChatConfirmation(context),
          isDestructive: true,
        ),
        const SizedBox(height: 12),
        _buildActionCard(
          context,
          Theme.of(context).colorScheme.error,
          widget.chatType == ChatType.userGroup ? 'Leave Group' : 'Leave Lobby',
          Icons.exit_to_app,
          () => _showLeaveConfirmation(context),
          isDestructive: true,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBackgroundsTab(BuildContext context, Color neonColor) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _backgroundService.getCurrentBackground(widget.squadId),
      builder: (context, snapshot) {
        final currentBg = snapshot.data ?? {'type': 'none', 'value': ''};
        final currentType = currentBg['type'] ?? 'none';
        final currentValue = currentBg['value'] ?? '';

        // Determine selected preset ID
        String? selectedPresetId;
        if (currentType == 'preset') {
          selectedPresetId = currentValue;
        }

        final presetKeys = BackgroundService.presets.keys.toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick access bubbles - 2 rows (4 top, 3 bottom offset)
              _buildQuickAccessBubbles(context, neonColor, currentBg),
              const SizedBox(height: 32),

              // Preset backgrounds - 2 column grid with bigger cards
              Text(
                'Presets',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: presetKeys.length,
                itemBuilder: (context, index) {
                  final presetId = presetKeys[index];
                  final isSelected = selectedPresetId == presetId;

                  return _buildPresetCard(
                    context,
                    neonColor,
                    presetId,
                    isSelected,
                    () => _applyPresetBackground(context, presetId, neonColor),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessBubbles(
    BuildContext context,
    Color neonColor,
    Map<String, dynamic> currentBg,
  ) {
    final bubbleSize = 70.0;
    final screenWidth = MediaQuery.of(context).size.width - 32;

    return Column(
      children: [
        // Top row - 4 bubbles
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickBubble(
              context,
              'None',
              Icons.block,
              () => _applyNoneBackground(context, neonColor),
              bubbleSize,
              currentBg['type'] == 'none',
            ),
            _buildQuickBubble(
              context,
              'Photo',
              Icons.photo_camera,
              () => _showPhotoBackgroundPicker(context, neonColor),
              bubbleSize,
              currentBg['type'] == 'image',
            ),
            _buildQuickBubble(
              context,
              'Recent',
              Icons.history,
              () => _showRecentBackgrounds(context, neonColor),
              bubbleSize,
              false,
            ),
            _buildQuickBubble(
              context,
              'Sunset',
              Icons.wb_twilight,
              () => _showAnimatedBackgroundVariations(
                  context, neonColor, 'sunset'),
              bubbleSize,
              false,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFF4A1C8C)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Bottom row - 3 bubbles, offset
        Padding(
          padding: EdgeInsets.only(left: screenWidth * 0.12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickBubble(
                context,
                'Ocean',
                Icons.waves,
                () => _showAnimatedBackgroundVariations(
                    context, neonColor, 'ocean'),
                bubbleSize,
                false,
                gradient: const LinearGradient(
                  colors: [Color(0xFF001F3F), Color(0xFF0074D9)],
                ),
              ),
              _buildQuickBubble(
                context,
                'Neon',
                Icons.auto_awesome,
                () => _showAnimatedBackgroundVariations(
                    context, neonColor, 'neon'),
                bubbleSize,
                false,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5FF), Color(0xFFFF00FF)],
                ),
              ),
              _buildQuickBubble(
                context,
                'Emerald',
                Icons.nature,
                () => _showAnimatedBackgroundVariations(
                    context, neonColor, 'emerald'),
                bubbleSize,
                false,
                gradient: const LinearGradient(
                  colors: [Color(0xFF00F5A0), Color(0xFF00D9F5)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickBubble(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
    double size,
    bool isSelected, {
    Gradient? gradient,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Column(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              color: gradient == null ? Colors.white.withOpacity(0.25) : null,
              border: Border.all(
                color:
                    isSelected ? Colors.white : Colors.white.withOpacity(0.2),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _applyNoneBackground(BuildContext context, Color neonColor) async {
    _showBackgroundPreview(
      context,
      neonColor,
      'None',
      [
        {
          'id': 'none',
          'name': 'No Background',
          'color': const Color(0xFF0B0E14),
        }
      ],
    );
  }

  void _showPhotoBackgroundPicker(BuildContext context, Color neonColor) async {
    final result = await ImageCropHelper.pickAndCropBackgroundImage(context);

    if (result != null && context.mounted) {
      try {
        // Upload to Supabase Storage
        final imagePath = await _backgroundService.uploadCustomBackground(
          widget.squadId,
          result.path,
        );

        // Show preview with uploaded image
        if (context.mounted) {
          _showBackgroundPreview(
            context,
            neonColor,
            'Photo Background',
            [
              {
                'id': 'image_$imagePath',
                'name': 'Photo',
                'imageUrl': imagePath,
              }
            ],
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showRecentBackgrounds(BuildContext context, Color neonColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent Backgrounds',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: Text(
                  'Recent backgrounds history\ncoming soon',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnimatedBackgroundVariations(
    BuildContext context,
    Color neonColor,
    String theme,
  ) {
    // Get variations for the theme
    final variations = _getBackgroundVariations(theme);
    final themeName =
        '${theme.substring(0, 1).toUpperCase()}${theme.substring(1)}';

    _showBackgroundPreview(context, neonColor, themeName, variations);
  }

  /// Unified method to show background preview with ripple transition
  void _showBackgroundPreview(
    BuildContext context,
    Color neonColor,
    String themeName,
    List<Map<String, dynamic>> variations,
  ) {
    // Navigate with ripple page route for smooth transition
    Navigator.of(context).push(
      _RipplePageRoute(
        page: BackgroundPreviewScreen(
          themeName: themeName,
          variations: variations,
          squadId: widget.squadId,
          chatName: widget.squadName,
          chatImageUrl: widget.avatarUrl,
          chatType: widget.chatType,
          onApply: (presetId) async {
            try {
              // Determine background type from preset ID
              String type = 'preset';
              String value = presetId;

              if (presetId == 'none') {
                type = 'none';
                value = '';
              } else if (presetId.startsWith('image_')) {
                type = 'image';
                value = presetId.substring(6); // Remove 'image_' prefix
              }

              await _backgroundService.applyBackground(
                widget.squadId,
                type: type,
                value: value,
              );

              if (context.mounted) {
                Navigator.pop(context); // Close preview
                Navigator.pop(context); // Close background picker
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getBackgroundVariations(String theme) {
    switch (theme) {
      case 'sunset':
        return [
          {
            'id': 'sunset_void',
            'name': 'Sunset Void',
            'gradient': const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFF4A1C8C)],
            ),
          },
          {
            'id': 'sunset_fire',
            'name': 'Fire Sunset',
            'gradient': const LinearGradient(
              colors: [Color(0xFFFF4500), Color(0xFF8B0000)],
            ),
          },
          {
            'id': 'sunset_warm',
            'name': 'Warm Sunset',
            'gradient': const LinearGradient(
              colors: [Color(0xFFFFAA33), Color(0xFFFF6B6B)],
            ),
          },
        ];
      case 'ocean':
        return [
          {
            'id': 'ocean_depths',
            'name': 'Ocean Depths',
            'gradient': const LinearGradient(
              colors: [Color(0xFF001F3F), Color(0xFF0074D9)],
            ),
          },
          {
            'id': 'ocean_teal',
            'name': 'Teal Ocean',
            'gradient': const LinearGradient(
              colors: [Color(0xFF004D5C), Color(0xFF00CED1)],
            ),
          },
          {
            'id': 'ocean_midnight',
            'name': 'Midnight Ocean',
            'gradient': const LinearGradient(
              colors: [Color(0xFF0D1B2A), Color(0xFF1B4965)],
            ),
          },
        ];
      case 'neon':
        return [
          {
            'id': 'neon_horizon',
            'name': 'Neon Horizon',
            'gradient': const LinearGradient(
              colors: [Color(0xFF00F5FF), Color(0xFFFF00FF)],
            ),
          },
          {
            'id': 'neon_pink',
            'name': 'Pink Neon',
            'gradient': const LinearGradient(
              colors: [Color(0xFFFF006E), Color(0xFFFF00FF)],
            ),
          },
          {
            'id': 'neon_blue',
            'name': 'Blue Neon',
            'gradient': const LinearGradient(
              colors: [Color(0xFF00F5FF), Color(0xFF0066FF)],
            ),
          },
        ];
      case 'emerald':
        return [
          {
            'id': 'emerald_dream',
            'name': 'Emerald Dream',
            'gradient': const LinearGradient(
              colors: [Color(0xFF00F5A0), Color(0xFF00D9F5)],
            ),
          },
          {
            'id': 'emerald_forest',
            'name': 'Forest Emerald',
            'gradient': const LinearGradient(
              colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
            ),
          },
          {
            'id': 'emerald_mint',
            'name': 'Mint Emerald',
            'gradient': const LinearGradient(
              colors: [Color(0xFF3CFFD2), Color(0xFF56FFA4)],
            ),
          },
        ];
      default:
        return [];
    }
  }

  Widget _buildBackgroundVariationCard(
    BuildContext context,
    Color neonColor,
    String presetId,
    String name,
    LinearGradient gradient,
  ) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        try {
          await _backgroundService.applyBackground(
            widget.squadId,
            type: 'preset',
            value: presetId,
          );
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$name applied'),
                backgroundColor: neonColor,
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClipsTab(BuildContext context, Color neonColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getMediaStream(['clip']),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(context, neonColor, 'Error loading clips');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: neonColor),
          );
        }

        final clipMessages = snapshot.data ?? [];

        if (clipMessages.isEmpty) {
          return _buildEmptyStateCard(
            context,
            neonColor,
            'No clips yet',
            Icons.movie,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: clipMessages.length,
          itemBuilder: (context, index) {
            final data = clipMessages[index];
            final message = MessageData.fromMap(data);

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipMessageBubble(
                messageData: message,
                isMe: false,
                chatGroupId: widget.squadId,
                chatType: ChatType.userGroup,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotosTab(BuildContext context, Color neonColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getMediaStream(['image']),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(context, neonColor, 'Error loading photos');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: neonColor),
          );
        }

        final photoMessages = snapshot.data ?? [];
        final photoUrls = photoMessages
            .map((data) {
              // Try different image fields
              if (data['avatar_url'] != null) {
                return data['avatar_url'] as String;
              } else if (data['image_url'] != null) {
                return data['image_url'] as String;
              }
              final photos = data['photos'] as List?;
              if (photos != null && photos.isNotEmpty) {
                return photos[0]['url'] as String?;
              }
              return null;
            })
            .where((url) => url != null)
            .cast<String>()
            .toList();

        if (photoUrls.isEmpty) {
          return _buildEmptyStateCard(
            context,
            neonColor,
            'No photos yet',
            Icons.photo_library,
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: photoUrls.length,
            itemBuilder: (context, index) {
              return _buildPhotoCard(context, neonColor, photoUrls[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildLinksTab(BuildContext context, Color neonColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getAllMessagesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(context, neonColor, 'Error loading links');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: neonColor),
          );
        }

        final messages = snapshot.data ?? [];
        final linkMessages = messages.where((data) {
          final text = data['text'] as String? ?? '';
          return _containsUrl(text);
        }).toList();

        if (linkMessages.isEmpty) {
          return _buildEmptyStateCard(
            context,
            neonColor,
            'No links yet',
            Icons.link,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: linkMessages.length,
          itemBuilder: (context, index) {
            final data = linkMessages[index];
            final text = data['text'] as String? ?? '';
            final urls = _extractUrls(text);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildLinkCard(context, neonColor, urls.first, text),
            );
          },
        );
      },
    );
  }

  Widget _buildFilesTab(BuildContext context, Color neonColor) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getMediaStream(['audio', 'file', 'voiceNote']),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(context, neonColor, 'Error loading files');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: neonColor),
          );
        }

        final fileMessages = snapshot.data ?? [];

        if (fileMessages.isEmpty) {
          return _buildEmptyStateCard(
            context,
            neonColor,
            'No files yet',
            Icons.folder,
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: fileMessages.length,
          itemBuilder: (context, index) {
            final data = fileMessages[index];
            final message = MessageData.fromMap(data);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildFileCard(context, neonColor, message),
            );
          },
        );
      },
    );
  }

  /// Section header text
  Widget _buildSectionHeader(BuildContext context, Color color, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  /// Toggle card with switch
  Widget _buildToggleCard(
    BuildContext context,
    Color neonColor,
    String title,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: neonColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Member list card with avatars, names, and roles
  Widget _buildMemberListCard(BuildContext context, Color neonColor,
      List<Map<String, dynamic>> members) {
    // Mock data if no members provided
    if (members.isEmpty) {
      members = [
        {
          'uid': '1',
          'name': 'Player 1',
          'isOnline': true,
          'role': 'admin',
          'spot': 'Spot 1'
        },
        {'uid': '2', 'name': 'Player 2', 'isOnline': true, 'spot': 'Spot 2'},
        {'uid': '3', 'name': 'Player 3', 'isOnline': false},
        {
          'uid': '4',
          'name': 'Player 4',
          'isOnline': true,
          'role': 'mod',
          'spot': 'Spot 4'
        },
      ];
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: neonColor.withOpacity(0.1),
              indent: 68,
            ),
            itemBuilder: (context, index) {
              final member = members[index];
              final isOnline = member['isOnline'] as bool? ?? false;
              final role = member['role'] as String?;
              final spot = member['spot'] as String?;

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Show member menu
                    final uid = member['uid'] as String?;
                    if (uid != null) {
                      _showMemberMenu(context, member);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // Avatar with online status
                        Stack(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isOnline
                                      ? AppTheme.success(
                                          Theme.of(context).colorScheme)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundImage: member['avatarUrl'] != null
                                    ? NetworkImage(
                                        member['avatarUrl'] as String)
                                    : null,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                child: member['avatarUrl'] == null
                                    ? Icon(Icons.person,
                                        color: neonColor, size: 20)
                                    : null,
                              ),
                            ),
                            // Role badge
                            if (role != null)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: role == 'admin'
                                        ? AppTheme.warning(
                                            Theme.of(context).colorScheme)
                                        : neonColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Theme.of(context).colorScheme.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    role == 'admin' ? Icons.star : Icons.shield,
                                    size: 10,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Name and spot/role
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member['name'] as String? ?? 'Unknown',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              if (spot != null || role != null)
                                const SizedBox(height: 2),
                              if (spot != null || role != null)
                                Text(
                                  spot ??
                                      (role == 'admin' ? 'Admin' : 'Moderator'),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: neonColor.withOpacity(0.7),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Online indicator
                        if (isOnline)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.success(
                                  Theme.of(context).colorScheme),
                              boxShadow: AppTheme.success(
                                      Theme.of(context).colorScheme)
                                  .neonGlow(blur: 8, opacity: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Lobby Info card - Shows lobby system rules and constitution
  Widget _buildLobbyInfoCard(BuildContext context, Color neonColor) {
    final infoItems = [
      {
        'icon': Icons.gavel,
        'title': 'Constitution',
        'description': 'Rules auto-apply to new lobbies',
      },
      {
        'icon': Icons.timer,
        'title': 'Spot Timers',
        'description': 'Claim spots before time expires',
      },
      {
        'icon': Icons.visibility,
        'title': 'Visibility',
        'description': 'Private, friends-only, or public',
      },
      {
        'icon': Icons.label,
        'title': 'Tags',
        'description': 'Add tags to help others find lobbies',
      },
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: infoItems.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: neonColor.withOpacity(0.1),
              indent: 68,
            ),
            itemBuilder: (context, index) {
              final item = infoItems[index];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: neonColor.withOpacity(0.15),
                        border: Border.all(
                          color: neonColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: neonColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['description'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Peacock Queue card
  Widget _buildPeacockQueueCard(BuildContext context, Color neonColor) {
    // Mock peacock queue data
    final peacockQueue = [
      {'name': 'Player 5', 'position': 1, 'timeWaiting': '2m'},
      {'name': 'Player 6', 'position': 2, 'timeWaiting': '5m'},
    ];

    if (peacockQueue.isEmpty) {
      return _buildEmptyStateCard(
        context,
        neonColor,
        'No one in queue',
        Icons.queue_play_next,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: peacockQueue.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: neonColor.withOpacity(0.1),
              indent: 16,
            ),
            itemBuilder: (context, index) {
              final entry = peacockQueue[index];
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Position badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: neonColor.withOpacity(0.2),
                        border: Border.all(
                          color: neonColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${entry['position']}',
                          style: GoogleFonts.orbitron(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: neonColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry['name'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      entry['timeWaiting'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: neonColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Lobby Spots card
  Widget _buildLobbySpotsCard(BuildContext context, Color neonColor) {
    // Mock squad spots (null means empty spot)
    final squadSpots = [
      'Player 1',
      'Player 2',
      null,
      'Player 4',
      null,
      null,
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: squadSpots.length,
            itemBuilder: (context, index) {
              final spot = squadSpots[index];
              final isEmpty = spot == null;

              return Container(
                decoration: BoxDecoration(
                  color: isEmpty
                      ? Colors.white.withOpacity(0.03)
                      : neonColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isEmpty
                        ? neonColor.withOpacity(0.2)
                        : neonColor.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isEmpty ? Icons.person_add_outlined : Icons.person,
                      color: isEmpty
                          ? Colors.white.withOpacity(0.4)
                          : Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEmpty ? 'Spot ${index + 1}' : spot,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                        color: isEmpty
                            ? Colors.white.withOpacity(0.4)
                            : Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Empty state card
  Widget _buildEmptyStateCard(
    BuildContext context,
    Color neonColor,
    String message,
    IconData icon,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: neonColor.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  icon,
                  color: Colors.white.withOpacity(0.4),
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show add member sheet
  void _showAddMemberSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ChatInfoAddMemberSheet(squadId: widget.squadId),
    );
  }

  /// Generate and share lobby link
  void _generateAndShareLobbyLink(BuildContext context) async {
    final deepLink = 'codsquadapp://join/${widget.squadId}';

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: deepLink));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lobby link copied to clipboard!'),
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Get preset background definitions
  // ignore: unused_element
  List<Map<String, dynamic>> _getPresetBackgrounds() {
    return [
      {
        'id': 'cyber_purple',
        'name': 'Cyber Purple',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a0033), Color(0xFF4d0099), Color(0xFF1a0033)],
        ),
      },
      {
        'id': 'warzone_green',
        'name': 'Warzone',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001a00), Color(0xFF00ff00), Color(0xFF003300)],
        ),
      },
      {
        'id': 'valorant_red',
        'name': 'Valorant',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF330000), Color(0xFFff4655), Color(0xFF1a0000)],
        ),
      },
      {
        'id': 'apex_orange',
        'name': 'Apex',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF331100), Color(0xFFff6600), Color(0xFF1a0800)],
        ),
      },
      {
        'id': 'neon_blue',
        'name': 'Neon Blue',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001a33), Color(0xFF00bfff), Color(0xFF000d1a)],
        ),
      },
      {
        'id': 'dark_matrix',
        'name': 'Matrix',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF000000), Color(0xFF003300), Color(0xFF001a00)],
        ),
      },
      {
        'id': 'cyberpunk_pink',
        'name': 'Cyberpunk',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF330022), Color(0xFFff00ff), Color(0xFF1a0011)],
        ),
      },
      {
        'id': 'overwatch_blue',
        'name': 'Overwatch',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001133), Color(0xFF0088ff), Color(0xFF000822)],
        ),
      },
      {
        'id': 'fortnite_purple',
        'name': 'Fortnite',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF220033), Color(0xFF8800ff), Color(0xFF110022)],
        ),
      },
      {
        'id': 'destiny_teal',
        'name': 'Destiny',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001a1a), Color(0xFF00cccc), Color(0xFF000d0d)],
        ),
      },
      {
        'id': 'halo_green',
        'name': 'Halo',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF001100), Color(0xFF00ff66), Color(0xFF000800)],
        ),
      },
      {
        'id': 'dark_void',
        'name': 'Dark Void',
        'gradient': const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0a0a0a), Color(0xFF1a1a2e), Color(0xFF000000)],
        ),
      },
    ];
  }

  /// Build preset background card with thumbnail
  Widget _buildPresetCard(
    BuildContext context,
    Color neonColor,
    String presetId,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final presetValue = BackgroundService.presets[presetId]!;
    final displayName = _formatPresetName(presetId);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background preview thumbnail
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? neonColor : neonColor.withOpacity(0.3),
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: isSelected
                    ? neonColor.neonGlow(blur: 20, opacity: 0.6)
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _buildPresetThumbnail(presetValue),
              ),
            ),

            // Glass overlay with name
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Text(
                      displayName,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? neonColor
                            : Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),

            // Selected checkmark with neon glow
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: neonColor,
                    shape: BoxShape.circle,
                    boxShadow: neonColor.neonGlow(blur: 12, opacity: 0.8),
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.black,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build upload custom image button
  Widget _buildUploadCustomButton(BuildContext context, Color neonColor) {
    return GestureDetector(
      onTap: () => _uploadCustomBackground(context, neonColor),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: neonColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: neonColor.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: neonColor.neonGlow(blur: 15, opacity: 0.3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file,
                  color: neonColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Upload Custom Background',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: neonColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Apply preset background using BackgroundService
  Future<void> _applyPresetBackground(
    BuildContext context,
    String presetId,
    Color neonColor,
  ) async {
    try {
      await _backgroundService.applyPreset(widget.squadId, presetId);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply background: $e'),
          backgroundColor: Colors.red.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Build live background preview
  Widget _buildBackgroundPreview(Map<String, dynamic> background) {
    final type = background['type'] ?? 'none';
    final value = background['value'] ?? '';

    switch (type) {
      case 'color':
      case 'solid':
        if (value.isEmpty || !value.startsWith('#')) {
          return Container(color: const Color(0xFF0B0E14));
        }
        try {
          final color = Color(
            int.parse(value.substring(1), radix: 16) + 0xFF000000,
          );
          return Container(color: color);
        } catch (e) {
          return Container(color: const Color(0xFF0B0E14));
        }

      case 'gradient':
        return _buildGradientPreview(value);

      case 'image':
        if (value.isEmpty) {
          return Container(color: const Color(0xFF0B0E14));
        }
        return Image.network(
          value,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Container(color: const Color(0xFF0B0E14)),
        );

      case 'preset':
        final presetValue = BackgroundService.presets[value];
        if (presetValue == null) {
          return Container(color: const Color(0xFF0B0E14));
        }
        return _buildPresetThumbnail(presetValue);

      default:
        return Container(color: const Color(0xFF0B0E14));
    }
  }

  /// Build gradient preview
  Widget _buildGradientPreview(String gradientString) {
    try {
      final parts = gradientString.split(':');
      if (parts.length < 3) {
        return Container(color: const Color(0xFF0B0E14));
      }

      final gradientType = parts[1];
      final colorStrings = parts[2].split(',');

      if (colorStrings.length < 2) {
        return Container(color: const Color(0xFF0B0E14));
      }

      final colors = colorStrings.map((colorStr) {
        try {
          return Color(int.parse(colorStr.replaceAll('0x', ''), radix: 16));
        } catch (e) {
          return const Color(0xFF0B0E14);
        }
      }).toList();

      if (gradientType == 'radial') {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(colors: colors),
          ),
        );
      } else {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        );
      }
    } catch (e) {
      return Container(color: const Color(0xFF0B0E14));
    }
  }

  /// Build current background info card
  Widget _buildCurrentBackgroundInfo(
    BuildContext context,
    Color neonColor,
    Map<String, dynamic> currentBg,
  ) {
    final type = currentBg['type'] ?? 'none';
    final value = currentBg['value'] ?? '';

    String bgName = 'None';
    if (type == 'preset') {
      bgName = _formatPresetName(value);
    } else if (type == 'color' || type == 'solid') {
      bgName = 'Custom Color ($value)';
    } else if (type == 'image') {
      bgName = 'Custom Image';
    } else if (type == 'gradient') {
      bgName = 'Custom Gradient';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.wallpaper,
                color: neonColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Background',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bgName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: neonColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build preset thumbnail
  Widget _buildPresetThumbnail(String presetValue) {
    if (presetValue.startsWith('#')) {
      try {
        final color = Color(
          int.parse(presetValue.substring(1), radix: 16) + 0xFF000000,
        );
        return Container(color: color);
      } catch (e) {
        return Container(color: const Color(0xFF0B0E14));
      }
    } else if (presetValue.startsWith('gradient:')) {
      return _buildGradientPreview(presetValue);
    } else if (presetValue.startsWith('assets/')) {
      return Image.asset(
        presetValue,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey,
          child: const Icon(Icons.image_not_supported, color: Colors.white54),
        ),
      );
    } else {
      return Image.network(
        presetValue,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey,
          child: const Icon(Icons.image_not_supported, color: Colors.white54),
        ),
      );
    }
  }

  /// Format preset name for display
  String _formatPresetName(String presetId) {
    return presetId
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Upload custom background
  Future<void> _uploadCustomBackground(
    BuildContext context,
    Color neonColor,
  ) async {
    try {
      // Use ImageCropHelper for picking and cropping background image
      final croppedFile =
          await ImageCropHelper.pickAndCropBackgroundImage(context);

      if (croppedFile == null) return;

      // Check if widget is still mounted after async operation
      if (!mounted) {
        debugPrint('Widget unmounted after image crop, aborting upload');
        return;
      }

      // Show uploading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: neonColor),
              const SizedBox(height: 16),
              Text(
                'Uploading background...',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      // Upload using BackgroundService with cropped file
      await _backgroundService.uploadCustomBackground(
        widget.squadId,
        croppedFile.path,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close dialog

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Custom background uploaded successfully!'),
          backgroundColor: neonColor.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close dialog if open

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Build reset to default button
  Widget _buildResetDefaultButton(BuildContext context, Color neonColor) {
    return GestureDetector(
      onTap: () => _resetToDefault(context, neonColor),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.restore,
                  color: Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Reset to Default',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Reset background to default
  Future<void> _resetToDefault(BuildContext context, Color neonColor) async {
    try {
      await _backgroundService.removeBackground(widget.squadId);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Background reset to default'),
          backgroundColor: neonColor.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset: $e'),
          backgroundColor: Colors.red.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show member menu with friend request option
  void _showMemberMenu(BuildContext context, Map<String, dynamic> member) {
    final theme = Theme.of(context);
    final uid = member['uid'] as String;
    final displayName = member['displayName'] as String? ?? 'Unknown';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  displayName,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              // Add Friend option
              ListTile(
                leading:
                    Icon(Icons.person_add, color: theme.colorScheme.primary),
                title: const Text('Add Friend'),
                onTap: () {
                  Navigator.pop(context);
                  _sendFriendRequestToMember(context, uid, displayName);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Send friend request to a member
  Future<void> _sendFriendRequestToMember(
      BuildContext context, String targetUid, String targetName) async {
    try {
      await ref
          .read(userNotifierProvider.notifier)
          .sendFriendRequest(targetUid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $targetName'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send friend request: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show custom upload sheet
  // ignore: unused_element
  void _showCustomUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ChatInfoCustomBackgroundSheet(squadId: widget.squadId),
    );
  }

  /// Get Supabase stream for specific media types
  Stream<List<Map<String, dynamic>>> _getMediaStream(List<String> types) {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return SupabaseService.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_group_id', widget.squadId)
        .order('timestamp_ms', ascending: false)
        .limit(100)
        .map((data) => data
            .where((row) => types.contains(row['type']?.toString()))
            .toList());
  }

  /// Get stream of all messages (for link filtering)
  Stream<List<Map<String, dynamic>>> _getAllMessagesStream() {
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return SupabaseService.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.squadId)
        .order('timestamp', ascending: false)
        .limit(200);
  }

  /// Check if text contains URLs
  bool _containsUrl(String text) {
    final urlPattern = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(text);
  }

  /// Extract URLs from text
  List<String> _extractUrls(String text) {
    final urlPattern = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    return urlPattern.allMatches(text).map((match) => match.group(0)!).toList();
  }

  /// Build photo card with glass frame
  Widget _buildPhotoCard(
      BuildContext context, Color neonColor, String imageUrl) {
    return GestureDetector(
      onTap: () {
        // Open full screen image viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatInfoFullScreenImageViewer(imageUrl: imageUrl),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.white.withOpacity(0.25),
                child: Center(
                  child: CircularProgressIndicator(
                    color: neonColor,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.white.withOpacity(0.25),
                child: Icon(
                  Icons.broken_image,
                  color: neonColor.withOpacity(0.5),
                ),
              ),
            ),
            // Glass border overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build link card with preview
  Widget _buildLinkCard(
      BuildContext context, Color neonColor, String url, String text) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Link preview widget
              LinkPreviewWidget(
                url: url,
                type: LinkType.website,
              ),

              // Message text if it has more than just the URL
              if (text.trim() != url.trim())
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    text.replaceAll(url, '').trim(),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build file card with icon and details
  Widget _buildFileCard(
      BuildContext context, Color neonColor, MessageData message) {
    IconData fileIcon;
    String fileType;

    if (message.audioUrl != null) {
      fileIcon = Icons.audiotrack;
      fileType = 'Audio';
    } else if (message.type == MessageType.audio) {
      fileIcon = Icons.mic;
      fileType = 'Voice Message';
    } else {
      fileIcon = Icons.insert_drive_file;
      fileType = 'File';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Open/play file
              if (message.type == MessageType.audio &&
                  message.audioUrl != null) {
                // Play audio using existing audio message widget
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Audio Player'),
                    content: Text('Audio playback: ${message.audioUrl}'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('File viewer coming soon')),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // File icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: neonColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      fileIcon,
                      color: neonColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileType,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.timestamp.toString().split('.')[0],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Download/play icon
                  Icon(
                    message.type == MessageType.audio
                        ? Icons.play_circle_outline
                        : Icons.download,
                    color: neonColor,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(
      BuildContext context, Color neonColor, String message) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    Color color,
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      color: isDestructive ? color : Colors.white, size: 24),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? color : Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: isDestructive
                        ? color.withOpacity(0.5)
                        : Colors.white.withOpacity(0.5),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.squadName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Group Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'Enter new group name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                try {
                  final currentUser = AuthServiceSupabase().currentUser;
                  if (currentUser != null) {
                    // Update both lobbies and chat_groups tables
                    await Future.wait([
                      SupabaseService.client.from('lobbies').update({
                        'name': newName,
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', widget.squadId),
                      SupabaseService.client.from('chat_groups').update({
                        'name': newName,
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', widget.squadId),
                    ]);
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                } catch (e) {
                  debugPrint('Error updating group name: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to update group name')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ChatInfoEditLobbySheet(
        squadId: widget.squadId,
        squadName: widget.squadName,
        avatarUrl: widget.avatarUrl,
        parentContext: context,
        onEditName: () => _showEditNameDialog(context),
        onAvatarUpdated: () async {
          // Reload user groups to refresh the avatar in UI
          await ref.read(cn.chatNotifierProvider.notifier).loadUserGroups();
          // Trigger UI refresh to show updated avatar immediately
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  void _showMessageSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: ChatMessageSearchDelegate(),
    );
  }

  void _showClearChatConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History?'),
        content: const Text(
          'This will permanently delete all messages in this chat. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              try {
                // Show loading indicator
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Deleting messages...'),
                    duration: Duration(seconds: 2),
                  ),
                );

                // Determine chat group ID based on chat type
                final chatGroupId = widget.chatType == ChatType.userGroup
                    ? widget.squadId
                    : null;

                // Delete all messages for this chat/lobby
                if (chatGroupId != null) {
                  // User group: delete by chat_group_id
                  await SupabaseService.client
                      .from('chat_messages')
                      .delete()
                      .eq('chat_group_id', chatGroupId);
                } else {
                  // Lobby: delete by squad_id
                  await SupabaseService.client
                      .from('chat_messages')
                      .delete()
                      .eq('squad_id', widget.squadId);
                }

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Chat history cleared successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                debugPrint('Error clearing chat: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to clear chat: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _showLeaveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.chatType == ChatType.userGroup
            ? 'Leave Group?'
            : 'Leave Lobby?'),
        content: Text('Are you sure you want to leave "${widget.squadName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // Leave group or lobby based on chat type
              try {
                if (widget.chatType == ChatType.userGroup) {
                  // Use ChatNotifier for user groups
                  await ref
                      .read(cn.chatNotifierProvider.notifier)
                      .leaveGroup(widget.squadId);
                } else {
                  // Direct database call for lobbies (legacy behavior)
                  final currentUser = AuthServiceSupabase().currentUser;
                  if (currentUser != null) {
                    // Remove from user's groups
                    final response = await SupabaseService.client
                        .from('users')
                        .select('user_groups')
                        .eq('uid', currentUser.id)
                        .maybeSingle();

                    if (response != null) {
                      final userGroups = List<Map<String, dynamic>>.from(
                          response['user_groups'] ?? []);
                      userGroups.removeWhere(
                          (g) => g['chat_group_id'] == widget.squadId);

                      await SupabaseService.client.from('users').update({
                        'user_groups': userGroups,
                      }).eq('uid', currentUser.id);
                    }

                    // Remove from squad members
                    final squadResponse = await SupabaseService.client
                        .from('lobbies')
                        .select('member_uids')
                        .eq('id', widget.squadId)
                        .maybeSingle();

                    if (squadResponse != null) {
                      final memberUids =
                          List<String>.from(squadResponse['member_uids'] ?? []);
                      memberUids.remove(currentUser.id);

                      await SupabaseService.client.from('lobbies').update({
                        'member_uids': memberUids,
                      }).eq('id', widget.squadId);
                    }
                  }
                }

                if (!mounted) return;
                // Navigate back to chat groups screen using GoRouter
                if (context.mounted) {
                  // Pop info screen first
                  Navigator.pop(context);
                  // Then navigate back to chats (this will also pop the ChatScreen)
                  if (context.mounted) {
                    context.go('/chat');
                  }
                }

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Left ${widget.squadName}'),
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.9),
                  ),
                );
              } catch (e) {
                debugPrint(
                    'Error leaving ${widget.chatType == ChatType.userGroup ? "group" : "squad"}: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Failed to leave ${widget.chatType == ChatType.userGroup ? "group" : "squad"}'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  /// Build background decoration matching chat screen
  Widget _buildBackgroundDecoration(Map<String, dynamic> background) {
    final type = background['type'] ?? 'none';
    final value = background['value'] ?? '';

    switch (type) {
      case 'color':
      case 'solid':
        if (value.isEmpty || !value.startsWith('#')) {
          return Container(color: const Color(0xFF0B0E14));
        }
        try {
          final color = Color(
            int.parse(value.substring(1), radix: 16) + 0xFF000000,
          );
          return Container(color: color);
        } catch (e) {
          return Container(color: const Color(0xFF0B0E14));
        }

      case 'gradient':
        return _buildGradientBackground(value);

      case 'image':
        if (value.isEmpty) {
          return Container(color: const Color(0xFF0B0E14));
        }
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(value),
              fit: BoxFit.cover,
              opacity: 1.0,
            ),
          ),
        );

      case 'preset':
        final presetValue = BackgroundService.presets[value];
        if (presetValue == null) {
          return Container(color: const Color(0xFF0B0E14));
        }

        if (presetValue.startsWith('#')) {
          try {
            final color = Color(
              int.parse(presetValue.substring(1), radix: 16) + 0xFF000000,
            );
            return Container(color: color);
          } catch (e) {
            return Container(color: const Color(0xFF0B0E14));
          }
        }

        if (presetValue.startsWith('gradient:')) {
          return _buildGradientBackground(presetValue);
        }

        if (presetValue.startsWith('assets/')) {
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(presetValue),
                fit: BoxFit.cover,
                opacity: 1.0,
              ),
            ),
          );
        }
        return Container(color: const Color(0xFF0B0E14));

      default:
        return Container(color: const Color(0xFF0B0E14));
    }
  }

  /// Build gradient background from string format
  Widget _buildGradientBackground(String value) {
    try {
      final parts = value.split(':');
      if (parts.length < 3) {
        return Container(color: const Color(0xFF0B0E14));
      }

      final colorStrings = parts[2].split(',');
      final colors = colorStrings.map((colorString) {
        return Color(int.parse(colorString));
      }).toList();

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      );
    } catch (e) {
      return Container(color: const Color(0xFF0B0E14));
    }
  }
}

/// Custom page route with reversed scale/fade transition
/// Shrinks and fades to complement the chat menu's grow animation
class _RipplePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  _RipplePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Reverse scale animation - shrink from 1.3 to 1.0
            // This is the opposite of the chat menu which grows from 0.7 to 1.0
            final scaleAnimation = Tween<double>(
              begin: 1.3,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ));

            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        );
}

// Supporting widgets moved to components/chat_info_widgets.dart
