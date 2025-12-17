import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/lobby.dart';
import '../../presentation/notifiers/lobby_notifier.dart';
import '../../presentation/notifiers/user_notifier.dart';
import '../../core/app_theme.dart';

/// Glassmorphic lobby card displayed in chat messages
class LobbyCardWidget extends ConsumerStatefulWidget {
  final Lobby lobby;
  final bool isCompact;

  const LobbyCardWidget({
    super.key,
    required this.lobby,
    this.isCompact = false,
  });

  @override
  ConsumerState<LobbyCardWidget> createState() => _LobbyCardWidgetState();
}

class _LobbyCardWidgetState extends ConsumerState<LobbyCardWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lobbyState = ref.watch(lobbyNotifierProvider);
    final userState = ref.watch(userNotifierProvider);

    return lobbyState.when(
      data: (state) {
        // Find updated lobby data from userLobbies map
        final currentLobby = state.userLobbies[widget.lobby.id] ?? widget.lobby;

        return _buildCard(theme, currentLobby, userState);
      },
      loading: () => _buildCard(theme, widget.lobby, userState),
      error: (_, __) => _buildCard(theme, widget.lobby, userState),
    );
  }

  Widget _buildCard(ThemeData theme, Lobby lobby, AsyncValue userState) {
    final currentUser = userState.value;
    if (currentUser == null) return const SizedBox.shrink();

    final isMember = lobby.memberUids.contains(currentUser.uid);
    final hasSpot = lobby.spots.any(
        (uid) => uid == currentUser.uid || uid == '${currentUser.uid}_calling');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Glass effect overlay
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surface.withOpacity(0.7),
                      theme.colorScheme.surface.withOpacity(0.5),
                    ],
                  ),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with game name and tags
                  _buildHeader(theme, lobby),

                  const SizedBox(height: 12),

                  // Lobby spots
                  _buildLobbySpots(theme, lobby, currentUser.uid),

                  const SizedBox(height: 12),

                  // Constitution rules preview
                  if (lobby.constitutionRules.isNotEmpty && _isExpanded)
                    _buildConstitutionPreview(theme, lobby),

                  const SizedBox(height: 12),

                  // Action buttons
                  _buildActionButtons(theme, lobby, isMember, hasSpot),
                ],
              ),
            ),

            // Expand/collapse button
            if (lobby.constitutionRules.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon:
                      Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surface.withOpacity(0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Lobby lobby) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Game name and member count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lobby.gameName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${lobby.memberUids.length} members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Visibility badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getVisibilityColor(lobby.visibility, theme)
                    .withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getVisibilityColor(lobby.visibility, theme),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getVisibilityIcon(lobby.visibility),
                    size: 14,
                    color: _getVisibilityColor(lobby.visibility, theme),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    lobby.visibility.replaceAll('_', ' ').toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _getVisibilityColor(lobby.visibility, theme),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Tags
        if (lobby.tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: lobby.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      labelStyle: theme.textTheme.labelSmall,
                      backgroundColor:
                          theme.colorScheme.primaryContainer.withOpacity(0.5),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLobbySpots(ThemeData theme, Lobby lobby, String currentUserUid) {
    final filledSpots = lobby.spots.where((uid) => uid != null).length;
    final maxSpots = lobby.maxSpots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lobby Spots',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$filledSpots/$maxSpots',
              style: theme.textTheme.bodySmall?.copyWith(
                color: filledSpots == maxSpots
                    ? AppTheme.success(theme.colorScheme)
                    : theme.colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Spot indicators
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(maxSpots, (index) {
            final uid = index < lobby.spots.length ? lobby.spots[index] : null;
            final isCalling = uid?.endsWith('_calling') ?? false;
            final actualUid = isCalling ? uid!.replaceAll('_calling', '') : uid;
            final isCurrentUser = actualUid == currentUserUid;

            return _buildSpotChip(
                theme, actualUid, isCalling, isCurrentUser, index);
          }),
        ),
      ],
    );
  }

  Widget _buildSpotChip(ThemeData theme, String? uid, bool isCalling,
      bool isCurrentUser, int index) {
    if (uid == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(width: 4),
            Text(
              'Open',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<String>(
      future: _getDisplayName(uid),
      builder: (context, snapshot) {
        final displayName = snapshot.data ?? 'Loading...';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isCurrentUser
                ? theme.colorScheme.primary.withOpacity(0.3)
                : isCalling
                    ? AppTheme.warning(theme.colorScheme).withOpacity(0.2)
                    : theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isCurrentUser
                  ? theme.colorScheme.primary
                  : isCalling
                      ? AppTheme.warning(theme.colorScheme)
                      : theme.colorScheme.primary.withOpacity(0.5),
              width: isCurrentUser ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCalling)
                Icon(
                  Icons.timer,
                  size: 14,
                  color: AppTheme.warning(theme.colorScheme),
                ),
              if (isCalling) const SizedBox(width: 4),
              Text(
                displayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isCurrentUser
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight:
                      isCurrentUser ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConstitutionPreview(ThemeData theme, Lobby lobby) {
    final rules = lobby.constitutionRules;
    final spotTimer = rules['spot_timer'] as String?;
    final afkPenalty = rules['afk_penalty'] as String?;
    final enforcementLevel = rules['enforcement_level'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.gavel,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Constitution Rules',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (spotTimer != null)
            _buildRuleItem(theme, Icons.timer, 'Spot Timer', spotTimer),
          if (afkPenalty != null)
            _buildRuleItem(
                theme, Icons.warning_amber, 'AFK Penalty', afkPenalty),
          if (enforcementLevel != null)
            _buildRuleItem(
                theme, Icons.shield, 'Enforcement', enforcementLevel),
        ],
      ),
    );
  }

  Widget _buildRuleItem(
      ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon,
              size: 14, color: theme.colorScheme.onSurface.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      ThemeData theme, Lobby lobby, bool isMember, bool hasSpot) {
    return Row(
      children: [
        if (!isMember)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _joinLobby(lobby.id),
              icon: const Icon(Icons.login, size: 18),
              label: const Text('Join Lobby'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

        if (isMember && !hasSpot)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _claimSpot(lobby.id),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Claim Spot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success(theme.colorScheme),
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

        if (hasSpot)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _leaveSpot(lobby.id),
              icon: const Icon(Icons.exit_to_app, size: 18),
              label: const Text('Leave Spot'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

        const SizedBox(width: 8),

        // Info button
        IconButton(
          onPressed: () => _showLobbyDetails(lobby),
          icon: const Icon(Icons.info_outline),
          style: IconButton.styleFrom(
            backgroundColor:
                theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          ),
        ),
      ],
    );
  }

  Future<void> _joinLobby(String lobbyId) async {
    final notifier = ref.read(lobbyNotifierProvider.notifier);
    final currentUser = ref.read(userNotifierProvider).value;
    if (currentUser == null) return;
    await notifier.joinLobby(lobbyId, currentUser.uid);
  }

  Future<void> _claimSpot(String lobbyId) async {
    final notifier = ref.read(lobbyNotifierProvider.notifier);
    // Find first available spot
    final lobby = widget.lobby;
    final firstEmptyIndex = lobby.spots.indexWhere((uid) => uid == null);
    if (firstEmptyIndex != -1) {
      await notifier.claimSpotSimple(firstEmptyIndex);
    }
  }

  Future<void> _leaveSpot(String lobbyId) async {
    final notifier = ref.read(lobbyNotifierProvider.notifier);
    final currentUser = ref.read(userNotifierProvider).value;
    if (currentUser == null) return;

    final lobby = widget.lobby;
    final spotIndex = lobby.spots.indexWhere(
        (uid) => uid == currentUser.uid || uid == '${currentUser.uid}_calling');

    if (spotIndex != -1) {
      await notifier.unclaimSpotSimple(spotIndex);
    }
  }

  void _showLobbyDetails(Lobby lobby) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lobby.gameName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Members: ${lobby.memberUids.length}'),
              Text('Max Spots: ${lobby.maxSpots}'),
              Text('Visibility: ${lobby.visibility}'),
              if (lobby.tags.isNotEmpty) Text('Tags: ${lobby.tags.join(', ')}'),
              if (lobby.constitutionRules.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Constitution Rules:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...lobby.constitutionRules.entries
                    .map((e) => Text('${e.key}: ${e.value}')),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<String> _getDisplayName(String uid) async {
    // This assumes UserNotifier has a method to get display name by UID
    // You may need to implement this or use a different approach
    return uid; // Placeholder - implement actual UID-to-name lookup
  }

  Color _getVisibilityColor(String visibility, ThemeData theme) {
    switch (visibility) {
      case 'public':
        return AppTheme.success(theme.colorScheme);
      case 'friends_only':
        return AppTheme.info(theme.colorScheme);
      case 'group_private':
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _getVisibilityIcon(String visibility) {
    switch (visibility) {
      case 'public':
        return Icons.public;
      case 'friends_only':
        return Icons.people;
      case 'group_private':
      default:
        return Icons.lock;
    }
  }
}
