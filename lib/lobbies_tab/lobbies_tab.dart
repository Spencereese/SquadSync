import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/layout.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/game_notifier.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../widgets/unified_game_selection_sheet.dart';
import 'peacock_widgets.dart';
import 'member_widgets.dart';
import 'lobby_dialogs.dart';
import 'widgets/lobby_grid.dart';
import 'widgets/lobby_controls.dart';
import 'widgets/lobby_header.dart';
import 'widgets/game_alerts_display.dart';
import 'widgets/peacock_queue_section.dart';

class MembersSection extends ConsumerWidget {
  final String? chatGroupId;
  final List<String> chatGroupMembers;
  final String? circle;
  final List<String>? friends;
  final Function(BuildContext, String, WidgetRef) showBlockDialog;
  final Function(BuildContext, ScaffoldMessengerState, WidgetRef, String)
      showComplaintDialog;

  const MembersSection({
    super.key,
    this.chatGroupId,
    required this.chatGroupMembers,
    this.circle,
    this.friends,
    required this.showBlockDialog,
    required this.showComplaintDialog,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(ln.lobbyNotifierProvider).when(
          data: (squadState) {
            // Use provided members list (computed based on circle), otherwise fall back to squad members
            final membersToShow = chatGroupMembers.isNotEmpty
                ? chatGroupMembers
                : squadState.lobbyMemberUids;

            if (membersToShow.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('No members yet',
                      style: TextStyle(color: Colors.grey)),
                ),
              );
            } else {
              return SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.grey[900],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: membersToShow.length,
                    itemBuilder: (context, index) {
                      final player = membersToShow[index];
                      return MemberWidgets.buildMemberCard(context, ref, player,
                          showBlockDialog, showComplaintDialog,
                          circle: circle, friends: friends);
                    },
                  ),
                ),
              );
            }
          },
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => SliverToBoxAdapter(
            child: Center(child: Text('Error: $error')),
          ),
        );
  }
}

class ClaimSpotFAB extends StatelessWidget {
  final String? lobbyId;
  final Function(BuildContext) callSpot;
  final Function(BuildContext) lockSpot;

  const ClaimSpotFAB({
    super.key,
    required this.lobbyId,
    required this.callSpot,
    required this.lockSpot,
  });

  @override
  Widget build(BuildContext context) {
    if (lobbyId == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseService.client
          .from('peacocks')
          .select()
          .eq('id', lobbyId!)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final peacockData = snapshot.data!;
        final filledRaw = peacockData['filled'];
        final filled = (filledRaw is List<dynamic>)
            ? filledRaw.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        final userSpot = filled.firstWhere(
          (f) => f['uid'] == AuthServiceSupabase().currentUserId,
          orElse: () => <String, dynamic>{},
        );

        if (userSpot.isNotEmpty) {
          final status = userSpot['status'];
          if (status == 'called') {
            return FloatingActionButton.extended(
              onPressed: () => lockSpot(context),
              backgroundColor: Colors.yellowAccent,
              icon: const Icon(Icons.lock),
              label: const Text('Lock Spot'),
            );
          } else if (status == 'ready') {
            return FloatingActionButton.extended(
              onPressed: () => callSpot(context),
              backgroundColor: Colors.orangeAccent,
              icon: const Icon(Icons.call),
              label: const Text('Call Spot'),
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class LobbyTab extends ConsumerStatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const LobbyTab(
      {super.key, this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  ConsumerState<LobbyTab> createState() => _LobbyTabState();
}

class _LobbyTabState extends ConsumerState<LobbyTab> {
  @override
  void initState() {
    super.initState();
    // Set selectedLobbyId - prefer lobbyId over chatGroupId
    final idToSet = widget.lobbyId ?? widget.chatGroupId;
    if (idToSet != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(ln.lobbyNotifierProvider.notifier).setSelectedLobbyId(idToSet);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LobbyTabContent(
        lobbyId: widget.lobbyId,
        gameName: widget.gameName,
        game: widget.game,
        chatGroupId: widget.chatGroupId);
  }
}

class _LobbyTabContent extends ConsumerStatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const _LobbyTabContent(
      {this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  _LobbyTabContentState createState() => _LobbyTabContentState();
}

class _LobbyTabContentState extends ConsumerState<_LobbyTabContent> {
  final bool _showPeacockMembers = false;
  late BuildContext _currentContext;
  List<String> _chatGroupMembers = [];
  String? _circle;
  List<String> _friends = [];

  // Quick Join enhancements
  List<Map<String, dynamic>> _suggestedLobbies = [];
  bool _isLoadingSuggestions = false;
  DateTime? _lastSuggestionFetch;
  final Duration _debounceDuration = const Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Check if lobby should be disbanded when leaving the screen
    _checkAndDisbandEmptyLobby();
    super.dispose();
  }

  Future<void> _checkAndDisbandEmptyLobby() async {
    try {
      final squadState = ref.read(ln.lobbyNotifierProvider).valueOrNull;
      if (squadState == null) return;

      final lobbyId = widget.lobbyId ?? squadState.selectedLobbyId;
      if (lobbyId == null) return;

      final gameName = widget.gameName ?? squadState.currentGame?['name'];
      if (gameName == null) return;

      // Get current spots for this game
      final spots = squadState.gameLobbySpots[gameName] ?? [];

      // Check if ALL spots are empty (null or empty string)
      final allSpotsEmpty = spots.every((spot) => spot == null || spot.isEmpty);

      // Only disband if all spots are empty
      if (allSpotsEmpty && spots.isNotEmpty) {
        debugPrint('💥 Disbanding empty lobby: $lobbyId (game: $gameName)');
        await ref.read(ln.lobbyNotifierProvider.notifier).deleteLobby(lobbyId);
      }
    } catch (e) {
      debugPrint('Error checking empty lobby: $e');
      // Don't throw - this is cleanup code
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentContext = context;

    // Set currentGame if gameName is provided but currentGame is not set or doesn't match
    if (widget.game != null) {
      // If we have the full game object, use it directly - do this immediately, not in post-frame
      final currentGame = ref.read(ln.lobbyNotifierProvider).maybeWhen(
            data: (state) => state.currentGame,
            orElse: () => null,
          );
      // Only set if not already set to avoid unnecessary updates
      if (currentGame?['name'] != widget.game?['name']) {
        ref.read(ln.lobbyNotifierProvider.notifier).setCurrentGame(widget.game);
      }
    } else if (widget.gameName != null) {
      final squadStateAsync = ref.read(ln.lobbyNotifierProvider);
      final currentGame = squadStateAsync.maybeWhen(
        data: (state) => state.currentGame,
        orElse: () => null,
      );
      if (currentGame == null || currentGame['name'] != widget.gameName) {
        // First, try to find the game in pinned games (most likely source for quick start)
        final userStateAsync = ref.read(userNotifierProvider);
        final pinnedGames = userStateAsync.maybeWhen(
          data: (userState) => userState?.pinnedGames ?? [],
          orElse: () => [],
        );
        Map<String, dynamic>? game =
            pinnedGames.cast<Map<String, dynamic>?>().firstWhere(
                  (g) => g?['name'] == widget.gameName,
                  orElse: () => null,
                );

        // If not found, try case-insensitive match in pinned games
        game ??= pinnedGames.cast<Map<String, dynamic>?>().firstWhere(
              (g) =>
                  g?['name']?.toLowerCase() == widget.gameName?.toLowerCase(),
              orElse: () => null,
            );

        // If still not found, try partial match in pinned games
        game ??= pinnedGames.cast<Map<String, dynamic>?>().firstWhere(
              (g) =>
                  g?['name']
                      ?.toLowerCase()
                      .contains(widget.gameName!.toLowerCase()) ==
                  true,
              orElse: () => null,
            );

        // If still not found, search for the game asynchronously
        if (game == null) {
          // Trigger async search without awaiting
          ref
              .read(gameNotifierProvider.notifier)
              .fetchGamesFromIGDB(widget.gameName!)
              .then((searchResults) {
            if (searchResults.isNotEmpty && mounted) {
              final squadStateAsync = ref.read(ln.lobbyNotifierProvider);
              final currentGame = squadStateAsync.maybeWhen(
                data: (state) => state.currentGame,
                orElse: () => null,
              );
              // Only update if currentGame is still the basic fallback (has empty summary)
              if (currentGame?['summary'] == '' &&
                  currentGame?['name'] == widget.gameName) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(ln.lobbyNotifierProvider.notifier)
                      .setCurrentGame(searchResults.first);
                });
              }
            }
          }).catchError((e) {
            debugPrint('Error searching for game ${widget.gameName}: $e');
          });
        } else {
          // Set the found game
          ref.read(ln.lobbyNotifierProvider.notifier).setCurrentGame(game);
        }

        // Use found game or create fallback
        game ??= {
          'name': widget.gameName,
          'maxSpots': 4,
          'description': 'Custom Game',
          'summary':
              '', // Ensure summary is empty so _showGameInfo doesn't show wrong description
        };

        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(ln.lobbyNotifierProvider.notifier).setCurrentGame(game);
        });
      }
    }

    // Fetch chat group members if chatGroupId is provided
    if (widget.chatGroupId != null && _chatGroupMembers.isEmpty) {
      _fetchChatGroupMembers();
    }

    // Fetch circle if lobbyId is provided
    if (widget.lobbyId != null && _circle == null) {
      _fetchCircle();
    }

    // Fetch friends
    if (_friends.isEmpty) {
      _fetchFriends();
    }
  }

  Future<void> _fetchChatGroupMembers() async {
    if (widget.chatGroupId == null) return;

    try {
      // Query chat group by ID only (no squad_id filter needed)
      final chatGroupDoc = await SupabaseService.client
          .from('chat_groups')
          .select('member_uids')
          .eq('id', widget.chatGroupId!)
          .maybeSingle();

      if (chatGroupDoc != null && mounted) {
        final members = List<String>.from(chatGroupDoc['member_uids'] ?? []);
        setState(() {
          _chatGroupMembers = members;
        });

        // Update lobby state with these members reactively
        ref.read(ln.lobbyNotifierProvider.notifier).updateLobbyMembers(members);
      }
    } catch (e) {
      debugPrint('Error fetching chat group members: $e');
    }
  }

  Future<void> _fetchCircle() async {
    if (widget.lobbyId == null) return;

    try {
      final peacockDoc = await SupabaseService.client
          .from('peacocks')
          .select('circle')
          .eq('id', widget.lobbyId!)
          .maybeSingle();

      if (peacockDoc != null && mounted) {
        final circle = peacockDoc['circle'] as String?;
        setState(() {
          _circle = circle;
        });
      }
    } catch (e) {
      debugPrint('Error fetching circle: $e');
    }
  }

  Future<void> _fetchFriends() async {
    final friends = ref.read(userNotifierProvider).value?.friends ?? [];
    setState(() {
      _friends = friends;
    });
  }

  Future<void> _fetchQuickJoinSuggestions() async {
    if (_lastSuggestionFetch != null &&
        DateTime.now().difference(_lastSuggestionFetch!) < _debounceDuration) {
      return; // Debounce
    }

    setState(() {
      _isLoadingSuggestions = true;
    });

    try {
      final userStateAsync = ref.read(userNotifierProvider);
      final pinnedGames = userStateAsync.maybeWhen(
        data: (userState) =>
            (userState?.pinnedGames ?? []).cast<Map<String, dynamic>>(),
        orElse: () => <Map<String, dynamic>>[],
      );

      if (pinnedGames.isNotEmpty) {
        // TODO: Implement lobby suggestions using Riverpod notifiers
        _suggestedLobbies = [];
      } else {
        _suggestedLobbies = [];
      }

      _lastSuggestionFetch = DateTime.now();
    } catch (e) {
      debugPrint('Error fetching quick join suggestions: $e');
      _suggestedLobbies = [];
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  Future<void> _handleQuickJoin() async {
    await _fetchQuickJoinSuggestions();

    if (_suggestedLobbies.isNotEmpty) {
      // Navigate to the first suggested lobby or show a dialog
      final lobby = _suggestedLobbies.first;
      // For now, just show a snackbar
      ScaffoldMessenger.of(_currentContext).showSnackBar(
        SnackBar(content: Text('Suggested lobby: ${lobby['gameName']}')),
      );
    } else {
      ScaffoldMessenger.of(_currentContext).showSnackBar(
        const SnackBar(
            content: Text('No public lobbies found for your pinned games')),
      );
    }
  }

  Future<void> _handleCreatePublicLobby() async {
    HapticFeedback.mediumImpact();

    await UnifiedGameSelectionSheet.show(
      context,
      title: 'Create Public Lobby',
      subtitle: 'Select a game for your public lobby',
      showMaxSpotSelector: true,
      showPinnedGames: true,
      showSearchButton: true,
      isPrivateLobby: false,
      onGameWithSpotsSelected: (gameName, maxSpots) async {
        try {
          HapticFeedback.mediumImpact();

          // Show loading indicator
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Text('Creating public lobby...'),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );

          // Create public lobby without chat group linkage
          final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);
          await lobbyNotifier.createLobby(
            chatGroupId: '', // Empty for standalone public lobbies
            gameName: gameName,
            maxSpots: maxSpots,
            isPublic: true,
          );

          HapticFeedback.lightImpact();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Public lobby created for $gameName!'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        } catch (e) {
          HapticFeedback.heavyImpact();

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create lobby: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
    );
  }

  List<String> _getMembersForCircle() {
    if (_circle == null) {
      // Default to chat group members if circle not loaded yet
      return _chatGroupMembers.isNotEmpty ? _chatGroupMembers : [];
    }

    switch (_circle) {
      case 'Lobby':
        return _chatGroupMembers.isNotEmpty ? _chatGroupMembers : [];
      case 'Friends':
        return _friends;
      case 'Public':
        // Show friends plus anyone who has joined spots
        final squadStateAsync = ref.read(ln.lobbyNotifierProvider);
        final squadState = squadStateAsync.maybeWhen(
          data: (state) => state,
          orElse: () => null,
        );
        if (squadState == null) return [];
        final gameName = widget.gameName ?? '';
        final gameLobbySpots = squadState.gameLobbySpots[gameName] ?? [];
        final joinedUsers = gameLobbySpots
            .where((spot) => spot != null)
            .map((spot) => ref
                .read(ln.lobbyNotifierProvider.notifier)
                .getDisplayNameForUid(spot!.split('_')[0]))
            .where((name) => name.isNotEmpty)
            .toList();
        return {..._friends, ...joinedUsers}.toList();
      default:
        return _chatGroupMembers.isNotEmpty ? _chatGroupMembers : [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final squadAsync = ref.watch(ln.lobbyNotifierProvider);
        return squadAsync.when(
          data: (squadState) => _buildSquadContent(squadState),
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => Scaffold(
            body: Center(child: Text('Error: $error')),
          ),
        );
      },
    );
  }

  Widget _buildSquadContent(dynamic squadState) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final currentGame = squadState.currentGame;
          final coverUrl = currentGame?['coverUrl'] as String?;

          return Stack(
            children: [
              // Blurred game cover background
              if (coverUrl != null)
                Positioned.fill(
                  child: Image.network(
                    coverUrl.startsWith('http') ? coverUrl : 'https:$coverUrl',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            theme.colorScheme.surface,
                            theme.colorScheme.surfaceContainerHighest
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.surface,
                          theme.colorScheme.surfaceContainerHighest
                        ],
                      ),
                    ),
                  ),
                ),

              // Light blur overlay for better game cover visibility
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              Column(
                children: [
                  // Header with navigation and game name
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: LobbyHeader(lobbyId: widget.lobbyId),
                  ),

                  // Lobby content
                  Expanded(
                    child: _buildLobbyTabContent(squadState),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      // Only show FAB when appropriate:
      // - ClaimSpotFAB when inside a lobby (lobbyId != null)
      // - Nothing when inside lobby view (no create button inside lobbies)
      floatingActionButton: widget.lobbyId != null
          ? ClaimSpotFAB(
              lobbyId: widget.lobbyId,
              callSpot: _callSpot,
              lockSpot: _lockSpot,
            )
          : null, // No FAB in dashboard mode - use discovery screen for creating public lobbies
    );
  }

  Widget _buildLobbyTabContent(dynamic squadState) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Quick Join button
        SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Consumer(
              builder: (context, ref, child) {
                final pinnedGames = ref.watch(userNotifierProvider
                    .select((asyncValue) => asyncValue.maybeWhen(
                          data: (userState) => userState?.pinnedGames ?? [],
                          orElse: () => [],
                        )));
                return ElevatedButton.icon(
                  onPressed: pinnedGames.isNotEmpty ? _handleQuickJoin : null,
                  icon: _isLoadingSuggestions
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.electric_bolt, color: Colors.white),
                  label: Text(
                    _isLoadingSuggestions ? 'Finding Lobbies...' : 'Quick Join',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007AFF),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Lobby spots grid
        LobbyGrid(),

        // Peacock members section (conditionally shown)
        SliverToBoxAdapter(
          child: _showPeacockMembers
              ? Consumer(
                  builder: (context, ref, child) =>
                      PeacockWidgets.buildPeacockMembersList(
                          context, ref, _togglePeacockMember),
                )
              : const SizedBox.shrink(),
        ),

        // Action buttons (Win/Loss)
        LobbyControls(),

        // Game alerts display
        const GameAlertsDisplay(),

        // Peacock Queue Section
        Consumer(
          builder: (context, ref, child) {
            final squadState = ref.watch(ln.lobbyNotifierProvider);
            return squadState.when(
              data: (state) {
                final gameName = state.currentGame?['name'];
                if (gameName == null || widget.lobbyId == null) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: PeacockQueueSection(
                    lobbyId: widget.lobbyId!,
                    gameName: gameName,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
              error: (_, __) =>
                  const SliverToBoxAdapter(child: SizedBox.shrink()),
            );
          },
        ),

        //
        // Members section header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Semantics(
              label: 'Squad Members List',
              child: Text(
                'Squad Members:',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.cyanAccent),
              ),
            ),
          ),
        ),

        // Members list
        MembersSection(
          chatGroupId: widget.chatGroupId,
          chatGroupMembers: _getMembersForCircle(),
          circle: _circle,
          friends: _friends,
          showBlockDialog: _showBlockDialog,
          showComplaintDialog: _showComplaintDialog,
        ),

        // Bottom spacing
        SliverToBoxAdapter(
          child: SizedBox(
            height: mainTabClearanceOf(context),
          ),
        ),
      ],
    );
  }

  void _togglePeacockMember(String member, bool isInPeacock) {
    if (isInPeacock) {
      ref.read(ln.lobbyNotifierProvider.notifier).removeFromPeacock(member);
    } else {
      ref.read(ln.lobbyNotifierProvider.notifier).addToPeacock(member);
    }
    setState(() {});
  }

  void _showBlockDialog(BuildContext context, String player, WidgetRef ref) {
    LobbyDialogs.showBlockDialog(context, player, ref);
  }

  void _showComplaintDialog(BuildContext context,
      ScaffoldMessengerState messenger, WidgetRef ref, String player) {
    LobbyDialogs.showComplaintDialog(context, messenger, ref, player);
  }

  Future<void> _callSpot(BuildContext context) async {
    final userId = AuthServiceSupabase().currentUserId;
    if (userId == null || widget.gameName == null) return;

    final squadState = ref.watch(ln.lobbyNotifierProvider).value;
    if (squadState == null) return;

    final spots = squadState.gameLobbySpots[widget.gameName!] ?? [];
    final maxSpots = squadState.currentGame?['maxSpots'] ?? 4;

    // Find the first available spot
    int? availableSpot;
    for (int i = 0; i < maxSpots && i < spots.length; i++) {
      if (spots[i] == null) {
        availableSpot = i;
        break;
      }
    }

    if (availableSpot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available spots!')),
      );
      return;
    }

    try {
      final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);
      await lobbyNotifier.callSpotForGame(availableSpot, widget.gameName!);

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Called spot ${availableSpot + 1}!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to call spot: $e')),
      );
    }
  }

  Future<void> _lockSpot(BuildContext context) async {
    final userId = AuthServiceSupabase().currentUserId;
    if (userId == null || widget.lobbyId == null) return;

    try {
      final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);
      await lobbyNotifier.lockPeacockSpot(
          widget.lobbyId!, userId, widget.gameName!);

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spot locked!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to lock spot: $e')),
      );
    }
  }
}
