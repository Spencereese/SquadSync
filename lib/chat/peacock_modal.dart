import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../squad_state.dart';
import '../managers/game_manager.dart';
import '../managers/user_manager.dart';
import '../managers/notification_manager.dart';

class PeacockModal extends StatefulWidget {
  final Map<String, dynamic>? initialGame;

  const PeacockModal({super.key, this.initialGame});

  @override
  _PeacockModalState createState() => _PeacockModalState();
}

class _PeacockModalState extends State<PeacockModal> {
  final TextEditingController _gameController = TextEditingController();
  double _spots = 4;
  String? _selectedCircle;
  bool _alertBackups = false;
  bool _isLoading = false;
  Map<String, dynamic>? _selectedGame;

  @override
  void initState() {
    super.initState();
    _selectedCircle =
        Provider.of<UserManager>(context, listen: false).alertCircles.first;

    // Pre-fill game if provided
    if (widget.initialGame != null) {
      _gameController.text = widget.initialGame!['name'] ?? '';
      _selectedGame = widget.initialGame;
      if (widget.initialGame!['maxSpots'] != null) {
        _spots = (widget.initialGame!['maxSpots'] as int).toDouble();
      }
    }

    // Fetch pinned games
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userManager = Provider.of<UserManager>(context, listen: false);
      userManager.fetchPinnedGames();
    });
  }

  @override
  void dispose() {
    _gameController.dispose();
    super.dispose();
  }

  Future<void> _submitPeacock() async {
    if (_gameController.text.isEmpty || _selectedCircle == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final squadState = Provider.of<SquadState>(context, listen: false);
      final gameName = _gameController.text;

      // Init gameSpotTimers in SquadManager
      squadState.dataManager.gameSpotTimers[gameName] ??=
          List.filled(_spots.toInt(), null);

      // Assign creator to spot 1 as caller with 5-minute countdown
      // Use direct assignment instead of callSpotForGame since creator gets longer timer
      squadState.dataManager.gameSquadSpots[gameName] ??=
          List.filled(_spots.toInt(), null);
      squadState.dataManager.gameSpotTimers[gameName] ??=
          List.filled(_spots.toInt(), null);

      // Set creator in spot 1 with 5-minute calling timer
      squadState.dataManager.gameSquadSpots[gameName]![0] =
          '${user.uid}_calling';
      squadState.dataManager.gameSpotTimers[gameName]![0] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': 300, // 5 minutes for lobby creator
        'calling': true,
        'peacockCreated':
            true, // Flag to distinguish from regular calling spots
      };
      squadState.dataManager
              .globalStatuses[squadState.displayName ?? 'Unknown Player'] =
          'Calling';

      // Mark fields as changed for persistence
      squadState.persistenceManager.markFieldChanged('squadSpots');
      squadState.persistenceManager.markFieldChanged('spotTimers');
      squadState.persistenceManager.markFieldChanged('globalStatuses');
      squadState.uiManager.setNewSquadSpot(true, gameName);
      squadState.updateFirestoreAsync(force: true);

      // Create peacock document in Firestore for lobby visibility
      final peacockData = {
        'hostUid': user.uid,
        'hostName': squadState.displayName ?? 'Unknown Player',
        'game': {'name': gameName},
        'spots': _spots.toInt(),
        'filled': [
          {'uid': user.uid, 'spot': 1, 'status': 'ready'}
        ], // Creator auto-assigned to spot 1 with ready status
        'viewers': <String>[], // Start with empty viewers list
        'timer': Timestamp.fromDate(DateTime.now()
            .add(const Duration(minutes: 5))), // 5min timer for lobby
        'createdAt': Timestamp.now(),
        'circle': _selectedCircle,
      };

      await FirebaseFirestore.instance.collection('peacocks').add(peacockData);

      // Update Firestore user doc
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'peacock': {
          'game': gameName,
          'spots': _spots.toInt(),
          'timer': DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          'circle': _selectedCircle,
        }
      }, SetOptions(merge: true));

      // Update user status to indicate they're looking for squad
      squadState.dataManager.setStatus(user.uid, 'Looking for squad');

      // Trigger notification
      final notificationManager =
          Provider.of<NotificationManager>(context, listen: false);
      await notificationManager.showNotification(
        title: 'Peacock Alert',
        body: 'Looking for ${_spots.toInt()} spots in $gameName',
      );

      // Ask if user wants to pin the game for quick access
      if (_selectedGame != null && mounted) {
        final shouldPin = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Pin Game',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Pin this game with current settings for quick access?',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Yes',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
        );

        if (shouldPin == true) {
          final userManager = Provider.of<UserManager>(context, listen: false);
          final quickStartGame = {
            ..._selectedGame!,
            'maxSpots': _spots.toInt(),
            'alertCircle': _selectedCircle,
            'alertBackups': _alertBackups,
          };
          await userManager.addPinnedGame(quickStartGame);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create peacock: $e')),
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
    final userManager = Provider.of<UserManager>(context);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.9, 1.0],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Modern drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Modern header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.group_add_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Group',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              fontSize: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Start a squad for gaming together',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: theme
                            .colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.1),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // Game selection section
                      Text(
                        'Choose Game',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: TypeAheadField(
                          controller: _gameController,
                          builder: (context, controller, focusNode) {
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search for a game...',
                                hintStyle: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                            );
                          },
                          suggestionsCallback: (pattern) async {
                            final userManager = Provider.of<UserManager>(
                                context,
                                listen: false);
                            final pinnedGames = userManager.pinnedGames;

                            if (pattern.isEmpty) {
                              // Show pinned games when no search query
                              return pinnedGames
                                  .map((game) => {
                                        'name': game['name'],
                                        'slug': game['slug'] ??
                                            game['name']
                                                ?.toString()
                                                .toLowerCase()
                                                .replaceAll(' ', '-'),
                                        'coverUrl': game['coverUrl'],
                                        'summary': game['summary'],
                                        'genres': game['genres'],
                                        'maxSpots': game['maxSpots'] ?? 4,
                                      })
                                  .toList();
                            }

                            final gameManager = Provider.of<GameManager>(
                                context,
                                listen: false);
                            return await (gameManager as dynamic)
                                .searchGames(pattern);
                          },
                          itemBuilder: (context, suggestion) {
                            final game = suggestion as Map<String, dynamic>;
                            final coverUrl = game['coverUrl'] as String?;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: coverUrl != null
                                          ? DecorationImage(
                                              image: CachedNetworkImageProvider(
                                                  coverUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                    ),
                                    child: coverUrl == null
                                        ? Icon(
                                            Icons.videogame_asset_rounded,
                                            color: theme
                                                .colorScheme.onSurfaceVariant,
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          game['name'] as String? ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        if (game['genres'] != null)
                                          Text(
                                            (game['genres'] as List<dynamic>?)
                                                    ?.join(', ') ??
                                                '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          onSelected: (suggestion) async {
                            final game = suggestion as Map<String, dynamic>;
                            setState(() {
                              _gameController.text =
                                  game['name'] as String? ?? '';
                              _selectedGame = game;
                              if (game['maxSpots'] != null) {
                                _spots = (game['maxSpots'] as int).toDouble();
                              }
                            });
                            HapticFeedback.lightImpact();
                            // Ensure suggestions close
                            FocusScope.of(context).unfocus();
                          },
                          emptyBuilder: (context) => Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'No games found',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Selected game preview
                      if (_selectedGame != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  image: _selectedGame!['coverUrl'] != null
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(
                                              _selectedGame!['coverUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                ),
                                child: _selectedGame!['coverUrl'] == null
                                    ? Icon(
                                        Icons.videogame_asset_rounded,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        size: 24,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedGame!['name'] ?? '',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_spots.toInt()} player${_spots.toInt() == 1 ? '' : 's'} max',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedGame = null;
                                    _gameController.clear();
                                    _spots = 4.0;
                                  });
                                },
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Group settings section
                      Text(
                        'Group Settings',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Max spots slider
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Max Players',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _spots.toInt().toString(),
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: theme.colorScheme.primary,
                                inactiveTrackColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                thumbColor: theme.colorScheme.primary,
                                overlayColor: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8),
                              ),
                              child: Slider(
                                value: _spots,
                                min: 2,
                                max: _selectedGame?['maxSpots']?.toDouble() ??
                                    100,
                                divisions:
                                    ((_selectedGame?['maxSpots']?.toDouble() ??
                                                100) -
                                            2 +
                                            1)
                                        .toInt(),
                                onChanged: (value) {
                                  setState(() {
                                    _spots = value;
                                  });
                                  HapticFeedback.lightImpact();
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '2',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${(_selectedGame?['maxSpots']?.toDouble() ?? 100).toInt()}',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Circle selection
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.circle_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Circle',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _selectedCircle,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                              ),
                              items: userManager.alertCircles.map((circle) {
                                return DropdownMenuItem<String>(
                                  value: circle,
                                  child: Text(
                                    circle,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCircle = value!;
                                });
                              },
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                              ),
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              dropdownColor: theme.colorScheme.surface,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Alert toggle
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.notifications_active_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Alert backups if unfilled after 5min',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Notify friends when the squad is ready',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _alertBackups,
                              onChanged: (value) {
                                setState(() {
                                  _alertBackups = value;
                                });
                                HapticFeedback.lightImpact();
                              },
                              activeColor: theme.colorScheme.primary,
                              activeTrackColor: theme.colorScheme.primary
                                  .withValues(alpha: 0.2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Launch button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: (_isLoading ||
                                  _gameController.text.isEmpty ||
                                  _selectedCircle == null)
                              ? null
                              : _submitPeacock,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            disabledBackgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            disabledForegroundColor:
                                theme.colorScheme.onSurfaceVariant,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.rocket_launch_rounded,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Launch Squad',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
