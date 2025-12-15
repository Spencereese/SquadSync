import 'dart:ui';
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
import '../services/chat_message_search_delegate.dart';

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
    final neonColor = theme.colorScheme.primary;
    final members = widget.members ?? [];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: neonColor.withOpacity(0.2),
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
                          ? neonColor.withOpacity(0.2)
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
                            ? neonColor
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
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

        return Stack(
          children: [
            // Live background preview with opacity 0.5
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: _buildBackgroundPreview(currentBg),
              ),
            ),

            // Content on top
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  _buildSectionHeader(context, neonColor, 'Chat Backgrounds'),
                  const SizedBox(height: 16),

                  // Current background info card
                  _buildCurrentBackgroundInfo(context, neonColor, currentBg),
                  const SizedBox(height: 24),

                  // Preset backgrounds grid
                  Text(
                    'Presets',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: neonColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
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
                        () => _applyPresetBackground(
                            context, presetId, neonColor),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Upload custom button
                  _buildUploadCustomButton(context, neonColor),
                  const SizedBox(height: 16),

                  // Reset to default button
                  _buildResetDefaultButton(context, neonColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      },
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
              if (data['image_url'] != null) {
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: neonColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: neonColor, size: 24),
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
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: neonColor.withOpacity(0.3),
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
                    // Show member profile
                    final uid = member['uid'] as String?;
                    if (uid != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Profile for ${member['name']}'),
                        ),
                      );
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
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: neonColor.withOpacity(0.3),
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
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: neonColor.withOpacity(0.3),
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
                      color: isEmpty ? neonColor.withOpacity(0.4) : neonColor,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isEmpty ? 'Spot ${index + 1}' : spot,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                        color: isEmpty
                            ? Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.4)
                            : neonColor,
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
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
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
                  color: neonColor.withOpacity(0.4),
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
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      border: Border(
                        top: BorderSide(
                          color: neonColor.withOpacity(0.3),
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
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Background "${_formatPresetName(presetId)}" applied!'),
          backgroundColor: neonColor.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: neonColor.withOpacity(0.3),
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

      if (!mounted) return;

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
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                color: Colors.white.withOpacity(0.05),
                child: Center(
                  child: CircularProgressIndicator(
                    color: neonColor,
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.white.withOpacity(0.05),
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
                    color: neonColor.withOpacity(0.3),
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: neonColor.withOpacity(0.3),
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: neonColor.withOpacity(0.3),
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
                        color: neonColor.withOpacity(0.3),
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
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDestructive
                    ? color.withOpacity(0.1)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: color.withOpacity(0.5),
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
        title: const Text('Change Lobby Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Lobby Name',
            hintText: 'Enter new lobby name',
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
                    await SupabaseService.client
                        .from('lobbies')
                        .update({'name': newName}).eq('id', widget.squadId);
                  }
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lobby name updated!')),
                  );
                } catch (e) {
                  debugPrint('Error updating lobby name: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to update lobby name')),
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
      builder: (context) => ChatInfoEditLobbySheet(
        squadId: widget.squadId,
        squadName: widget.squadName,
        avatarUrl: widget.avatarUrl,
        onEditName: () => _showEditNameDialog(context),
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
}

// Supporting widgets moved to components/chat_info_widgets.dart
