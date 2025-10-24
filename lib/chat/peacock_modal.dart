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
        'hostLockTimer': Timestamp.fromDate(DateTime.now()
            .add(const Duration(minutes: 5))), // 5min timer for host to lock
        'createdAt': Timestamp.now(),
        'circle': _selectedCircle,
      };

      await FirebaseFirestore.instance.collection('peacocks').add(peacockData);

      // Update Firestore user doc
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'peacock': {
          'game': gameName,
          'spots': _spots.toInt(),
          'hostLockTimer': DateTime.now()
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
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.85, 1.0],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header with icon, title, and close button
                      Row(
                        children: [
                          Icon(Icons.flash_on,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Start a Squad',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close,
                                color: theme.colorScheme.onSurface),
                            style: IconButton.styleFrom(
                              backgroundColor: theme
                                  .colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Pinned games section
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pinned Games',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (userManager.pinnedGames.isEmpty)
                            Container(
                              height: 80,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outline
                                      .withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pin favorites for quick access',
                                    style: TextStyle(
                                        color: theme.colorScheme.onSurface),
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: userManager.pinnedGames.length,
                                itemBuilder: (context, index) {
                                  final game = userManager.pinnedGames[index];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _gameController.text =
                                            game['name'] ?? '';
                                        _selectedGame = game;
                                        if (game['maxSpots'] != null) {
                                          _spots = (game['maxSpots'] as int)
                                              .toDouble();
                                        }
                                      });
                                      // Haptic feedback
                                      HapticFeedback.lightImpact();
                                    },
                                    child: Container(
                                      width: 70,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                image: game['coverUrl'] != null
                                                    ? DecorationImage(
                                                        image:
                                                            CachedNetworkImageProvider(
                                                                game[
                                                                    'coverUrl']),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                                color: theme.colorScheme
                                                    .surfaceContainerHighest,
                                                border: Border.all(
                                                  color: theme
                                                      .colorScheme.outline
                                                      .withValues(alpha: 0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: game['coverUrl'] == null
                                                  ? Icon(Icons.gamepad,
                                                      color: theme.colorScheme
                                                          .onSurface)
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            game['name'] ?? '',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  theme.colorScheme.onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Game search at the top
                      TypeAheadField(
                        controller: _gameController,
                        builder: (context, controller, focusNode) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style:
                                  TextStyle(color: theme.colorScheme.onSurface),
                              decoration: InputDecoration(
                                labelText: 'Game',
                                hintText: 'Search for a game...',
                                labelStyle: TextStyle(
                                    color: theme.colorScheme.onSurface),
                                hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7)),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: theme.colorScheme.outline),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.5)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2),
                                ),
                                filled: true,
                                fillColor: theme
                                    .colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                          );
                        },
                        suggestionsCallback: (pattern) async {
                          if (pattern.isEmpty) return [];
                          final gameManager =
                              Provider.of<GameManager>(context, listen: false);
                          // ignore: avoid_dynamic_calls
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
                                  width: 60,
                                  height: 60,
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
                                      ? Icon(Icons.gamepad,
                                          color: theme.colorScheme.onSurface,
                                          size: 30)
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
                                          fontSize: 16,
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
                                            fontSize: 14,
                                            color: theme.colorScheme.onSurface,
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
                            // Auto-fill spots from game data
                            if (game['maxSpots'] != null) {
                              _spots = (game['maxSpots'] as int).toDouble();
                            }
                          });
                          // Haptic feedback
                          HapticFeedback.lightImpact();
                          // Show pin dialog
                          final shouldPin = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: theme.colorScheme.surface,
                              title: Text(
                                'Pin Game',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface),
                              ),
                              content: Text(
                                'Pin this game for quick access?',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(
                                    'No',
                                    style: TextStyle(
                                        color: theme.colorScheme.primary),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(
                                    'Yes',
                                    style: TextStyle(
                                        color: theme.colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (shouldPin == true) {
                            final userManager = Provider.of<UserManager>(
                                context,
                                listen: false);
                            await userManager.addPinnedGame(game);
                          }
                        },
                        emptyBuilder: (context) => Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No games found',
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Selected game preview
                      if (_selectedGame != null)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (_selectedGame!['coverUrl'] != null)
                                CachedNetworkImage(
                                  imageUrl: _selectedGame!['coverUrl'],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.image,
                                        size: 50,
                                        color: theme.colorScheme.onSurface),
                                  ),
                                )
                              else
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.gamepad,
                                      size: 50,
                                      color: theme.colorScheme.onSurface),
                                ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedGame!['name'] ?? '',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (_selectedGame!['genres'] != null)
                                      Text(
                                        (_selectedGame!['genres']
                                                as List<dynamic>)
                                            .join(', '),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_selectedGame != null) const SizedBox(height: 20),
                      // Max spots display
                      if (_selectedGame != null &&
                          _selectedGame!['maxSpots'] != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.secondaryContainer
                                  .withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.people,
                                  color: theme.colorScheme.secondary),
                              const SizedBox(width: 12),
                              Text(
                                'Max spots: ${_selectedGame!['maxSpots']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_selectedGame != null &&
                          _selectedGame!['maxSpots'] != null)
                        const SizedBox(height: 20),
                      // Spots slider
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Number of Spots',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'Spots:',
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface),
                              ),
                              Expanded(
                                child: Slider(
                                  value: _spots,
                                  min: 1,
                                  max: _selectedGame?['maxSpots']?.toDouble() ??
                                      6,
                                  divisions: ((_selectedGame?['maxSpots']
                                                  ?.toDouble() ??
                                              6) -
                                          1)
                                      .toInt(),
                                  label: _spots.toInt().toString(),
                                  activeColor: theme.colorScheme.primary,
                                  inactiveColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  onChanged: (value) =>
                                      setState(() => _spots = value),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _spots.toInt().toString(),
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Circle dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCircle,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        dropdownColor: theme.colorScheme.surface,
                        decoration: InputDecoration(
                          labelText: 'Circle',
                          labelStyle: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                BorderSide(color: theme.colorScheme.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.colorScheme.outline
                                    .withValues(alpha: 0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                                color: theme.colorScheme.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.1),
                        ),
                        items: userManager.alertCircles.map((circle) {
                          return DropdownMenuItem(
                            value: circle,
                            child: Text(circle,
                                style: TextStyle(
                                    color: theme.colorScheme.onSurface)),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedCircle = value),
                      ),
                      const SizedBox(height: 20),
                      // Alert backups checkbox
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            'Alert backups if unfilled after 5min',
                            style:
                                TextStyle(color: theme.colorScheme.onSurface),
                          ),
                          value: _alertBackups,
                          activeColor: theme.colorScheme.primary,
                          checkColor: theme.colorScheme.onPrimary,
                          onChanged: (value) =>
                              setState(() => _alertBackups = value ?? false),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Launch button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (_isLoading ||
                                  _gameController.text.isEmpty ||
                                  _selectedCircle == null)
                              ? null
                              : _submitPeacock,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            disabledBackgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            disabledForegroundColor:
                                theme.colorScheme.onSurface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            shadowColor: theme.colorScheme.shadow,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.rocket_launch),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Launch Squad',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                        ),
                      ),
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
