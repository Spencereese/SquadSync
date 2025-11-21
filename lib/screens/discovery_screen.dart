import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../providers.dart';
import '../services/firestore_service.dart';
import '../services/grok_service.dart';
import '../managers/notification_manager.dart';
import '../chat/sqlite_helper.dart';
import '../app_theme.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _currentSearchTerm = '';
  final String _selectedGame = 'All Games'; // Default to all games
  bool _hasIndexError = false;
  String? _indexErrorUrl;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Groups'),
        backgroundColor: theme.primaryColor,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: theme.brightness == Brightness.dark
              ? AppTheme.darkGradient
              : AppTheme.lightGradient,
        ),
        child: Column(
          children: [
            // Search Bar with Game Filter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search groups...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _currentSearchTerm.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  if (_currentSearchTerm.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.smart_toy,
                            size: 16, color: theme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Powered by Grok AI',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Error Banner for Index Issues
            if (_hasIndexError && _indexErrorUrl != null)
              Container(
                color: Colors.orange,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Search optimized—create index for better performance',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: _openIndexUrl,
                      child: const Text(
                        'CREATE INDEX',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            // Groups Stream
            Expanded(
              child: _buildGroupsStream(),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentSearchTerm = '';
      _hasIndexError = false;
    });
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _currentSearchTerm = query.trim();
        _hasIndexError = false;
      });
    });
  }

  Future<void> _openIndexUrl() async {
    if (_indexErrorUrl != null) {
      final uri = Uri.parse(_indexErrorUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Widget _buildGroupsStream() {
    return Consumer(
      builder: (context, ref, child) {
        final firestoreService = ref.watch(firestoreServiceProvider);
        final grokService = ref.watch(grokServiceProvider);
        final notificationManager = ref.watch(notificationManagerProvider);
        final sqliteHelper = ref.watch(sqliteHelperProvider);

        return FutureBuilder<Stream<List<Map<String, dynamic>>>>(
          future: _currentSearchTerm.isEmpty
              ? _getDefaultGroupsStream(firestoreService, grokService,
                  notificationManager, sqliteHelper)
              : firestoreService.queryBuilder.buildSuggestedGroupsQuery(
                  _currentSearchTerm,
                  _selectedGame == 'All Games' ? '' : _selectedGame,
                  grokService,
                  notificationManager,
                  sqliteHelper,
                ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoading();
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final stream = snapshot.data;
            if (stream == null) {
              return const Center(child: Text('No data'));
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildSkeletonLoading();
                }

                if (snapshot.hasError) {
                  // Check if it's an index error
                  if (snapshot.error
                      .toString()
                      .contains('failed-precondition')) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _hasIndexError = true;
                        _indexErrorUrl = _generateIndexUrl();
                      });
                    });
                  }

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final groups = snapshot.data ?? [];
                return _buildGroupsList(context, groups);
              },
            );
          },
        );
      },
    );
  }

  Future<Stream<List<Map<String, dynamic>>>> _getDefaultGroupsStream(
    FirestoreService firestoreService,
    GrokService grokService,
    NotificationManager notificationManager,
    SQLiteHelper sqliteHelper,
  ) async {
    // For default view, show recent public groups
    return firestoreService.queryBuilder.buildSuggestedGroupsQuery(
      '',
      '',
      grokService,
      notificationManager,
      sqliteHelper,
    );
  }

  String _generateIndexUrl() {
    final projectId = 'your-project-id'; // TODO: Get from Firebase options
    return 'https://console.firebase.google.com/project/$projectId/firestore/indexes?create_composite=isPublic%20ASCENDING%2CmemberCount%20DESCENDING%2ClastMessageTime%20DESCENDING';
  }

  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 20,
                  width: 200,
                  color: Colors.grey[300],
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1000.ms),
                const SizedBox(height: 8),
                Container(
                  height: 14,
                  width: 300,
                  color: Colors.grey[300],
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1000.ms),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 12,
                      width: 80,
                      color: Colors.grey[300],
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 1000.ms),
                    Container(
                      height: 32,
                      width: 60,
                      color: Colors.grey[300],
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 1000.ms),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupsList(
      BuildContext context, List<Map<String, dynamic>> groups) {
    if (groups.isEmpty) {
      return const Center(
        child: Text('No groups found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _GroupCard(group: group);
      },
    );
  }
}

class _GroupCard extends StatefulWidget {
  final Map<String, dynamic> group;

  const _GroupCard({required this.group});

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  bool _isJoining = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              group['name'] ?? 'Unnamed Group',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (group['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                group['description'],
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${group['memberCount'] ?? 0} members',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                ElevatedButton(
                  onPressed: _isJoining ? null : () => _joinGroup(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Join'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinGroup(BuildContext context) async {
    setState(() => _isJoining = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in first')),
        );
        return;
      }

      final groupId = widget.group['id'];

      // Check if user is already a member
      final groupDoc = await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        final groupData = groupDoc.data()!;
        final members = List<String>.from(groupData['members'] ?? []);
        if (members.contains(currentUser.uid)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You are already a member')),
          );
          setState(() => _isJoining = false);
          return;
        }
      }

      // Add user to group
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayUnion([currentUser.uid]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add group to user's groups list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'chatGroups': FieldValue.arrayUnion([groupId]),
      });

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${widget.group['name']}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }
}
