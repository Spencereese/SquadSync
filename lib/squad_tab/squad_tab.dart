import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../managers/stubs.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/game_notifier.dart';
import '../presentation/notifiers/squad_notifier.dart' as sn;
import 'peacock_widgets.dart';
import 'member_widgets.dart';
import 'squad_dialogs.dart';
import 'widgets/squad_grid.dart';
import 'widgets/squad_controls.dart';
import 'widgets/squad_header.dart';
import 'widgets/game_alerts_display.dart';

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
    return ref.watch(sn.squadNotifierProvider).when(
          data: (squadState) {
            // Use provided members list (computed based on circle), otherwise fall back to squad members
            final membersToShow = chatGroupMembers.isNotEmpty
                ? chatGroupMembers
                : squadState.squadMemberUids;

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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('peacocks')
          .doc(lobbyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data();
        if (data is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        final peacockData = data;
        final filledRaw = peacockData['filled'];
        final filled = (filledRaw is List<dynamic>)
            ? filledRaw.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        final userSpot = filled.firstWhere(
          (f) => f['uid'] == FirebaseAuth.instance.currentUser?.uid,
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

class SquadTab extends ConsumerStatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const SquadTab(
      {super.key, this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  ConsumerState<SquadTab> createState() => _SquadTabState();
}

class _SquadTabState extends ConsumerState<SquadTab> {
  @override
  void initState() {
    super.initState();
    // Set selectedSquadId if chatGroupId is provided
    if (widget.chatGroupId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(sn.squadNotifierProvider.notifier)
            .setSelectedSquadId(widget.chatGroupId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SquadTabContent(
        lobbyId: widget.lobbyId,
        gameName: widget.gameName,
        game: widget.game,
        chatGroupId: widget.chatGroupId);
  }
}

class _SquadTabContent extends ConsumerStatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const _SquadTabContent(
      {this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  _SquadTabContentState createState() => _SquadTabContentState();
}

class _SquadTabContentState extends ConsumerState<_SquadTabContent> {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentContext = context;

    // Set currentGame if gameName is provided but currentGame is not set or doesn't match
    if (widget.game != null) {
      // If we have the full game object, use it directly
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sn.squadNotifierProvider.notifier).setCurrentGame(widget.game);
      });
    } else if (widget.gameName != null) {
      final squadStateAsync = ref.read(sn.squadNotifierProvider);
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
              final squadStateAsync = ref.read(sn.squadNotifierProvider);
              final currentGame = squadStateAsync.maybeWhen(
                data: (state) => state.currentGame,
                orElse: () => null,
              );
              // Only update if currentGame is still the basic fallback (has empty summary)
              if (currentGame?['summary'] == '' &&
                  currentGame?['name'] == widget.gameName) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref
                      .read(sn.squadNotifierProvider.notifier)
                      .setCurrentGame(searchResults.first);
                });
              }
            }
          }).catchError((e) {
            print('Error searching for game ${widget.gameName}: $e');
          });
        } else {
          // Set the found game
          ref.read(sn.squadNotifierProvider.notifier).setCurrentGame(game);
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
          ref.read(sn.squadNotifierProvider.notifier).setCurrentGame(game);
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
      final squadStateAsync = ref.read(sn.squadNotifierProvider);
      final selectedSquadId = squadStateAsync.maybeWhen(
        data: (state) => state.selectedSquadId,
        orElse: () => null,
      );
      if (selectedSquadId == null) return;

      final chatGroupDoc = await FirebaseFirestore.instance
          .collection('squads')
          .doc(selectedSquadId)
          .collection('chat_groups')
          .doc(widget.chatGroupId)
          .get();

      if (chatGroupDoc.exists && mounted) {
        final data = chatGroupDoc.data();
        final members = List<String>.from(data?['members'] ?? []);
        setState(() {
          _chatGroupMembers = members;
        });
      }
    } catch (e) {
      print('Error fetching chat group members: $e');
    }
  }

  Future<void> _fetchCircle() async {
    if (widget.lobbyId == null) return;

    try {
      final peacockDoc = await FirebaseFirestore.instance
          .collection('peacocks')
          .doc(widget.lobbyId)
          .get();

      if (peacockDoc.exists && mounted) {
        final data = peacockDoc.data();
        final circle = data?['circle'] as String?;
        setState(() {
          _circle = circle;
        });
      }
    } catch (e) {
      print('Error fetching circle: $e');
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
      final availabilityManager =
          p.Provider.of<AvailabilityManager>(_currentContext, listen: false);

      if (pinnedGames.isNotEmpty) {
        _suggestedLobbies =
            await availabilityManager.suggestLobbies(pinnedGames);
      } else {
        _suggestedLobbies = [];
      }

      _lastSuggestionFetch = DateTime.now();
    } catch (e) {
      print('Error fetching quick join suggestions: $e');
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

  List<String> _getMembersForCircle() {
    if (_circle == null) {
      // Default to chat group members if circle not loaded yet
      return _chatGroupMembers.isNotEmpty ? _chatGroupMembers : [];
    }

    switch (_circle) {
      case 'Squad':
        return _chatGroupMembers.isNotEmpty ? _chatGroupMembers : [];
      case 'Friends':
        return _friends;
      case 'Public':
        // Show friends plus anyone who has joined spots
        final squadStateAsync = ref.read(sn.squadNotifierProvider);
        final squadState = squadStateAsync.maybeWhen(
          data: (state) => state,
          orElse: () => null,
        );
        if (squadState == null) return [];
        final gameName = widget.gameName ?? '';
        final gameSquadSpots = squadState.gameSquadSpots[gameName] ?? [];
        final joinedUsers = gameSquadSpots
            .where((spot) => spot != null)
            .map((spot) => ref
                .read(sn.squadNotifierProvider.notifier)
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
        final squadAsync = ref.watch(sn.squadNotifierProvider);
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.indigo],
          ),
        ),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header with navigation and game selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SquadHeader(lobbyId: widget.lobbyId),
              ),
            ),

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
                      onPressed:
                          pinnedGames.isNotEmpty ? _handleQuickJoin : null,
                      icon: _isLoadingSuggestions
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.electric_bolt,
                              color: Colors.white),
                      label: Text(
                        _isLoadingSuggestions
                            ? 'Finding Lobbies...'
                            : 'Quick Join',
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

            // Squad spots grid
            SquadGrid(),

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
            SquadControls(),

            // Game alerts display
            const GameAlertsDisplay(),

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
              child: const SizedBox(height: 80.0),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.lobbyId != null
          ? ClaimSpotFAB(
              lobbyId: widget.lobbyId,
              callSpot: _callSpot,
              lockSpot: _lockSpot,
            )
          : null,
    );
  }

  void _togglePeacockMember(String member, bool isInPeacock) {
    if (isInPeacock) {
      ref.read(sn.squadNotifierProvider.notifier).removeFromPeacock(member);
    } else {
      ref.read(sn.squadNotifierProvider.notifier).addToPeacock(member);
    }
    setState(() {});
  }

  void _showBlockDialog(BuildContext context, String player, WidgetRef ref) {
    SquadDialogs.showBlockDialog(context, player, ref);
  }

  void _showComplaintDialog(BuildContext context,
      ScaffoldMessengerState messenger, WidgetRef ref, String player) {
    SquadDialogs.showComplaintDialog(context, messenger, ref, player);
  }

  Future<void> _callSpot(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.gameName == null) return;

    final squadState = ref.watch(sn.squadNotifierProvider).value;
    if (squadState == null) return;

    final spots = squadState.gameSquadSpots[widget.gameName!] ?? [];
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
      final squadNotifier = ref.read(sn.squadNotifierProvider.notifier);
      await squadNotifier.callSpotForGame(availableSpot, widget.gameName!);

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.lobbyId == null) return;

    try {
      final squadNotifier = ref.read(sn.squadNotifierProvider.notifier);
      await squadNotifier.lockPeacockSpot(
          widget.lobbyId!, user.uid, widget.gameName!);

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
