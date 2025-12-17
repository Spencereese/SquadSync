import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../../services/supabase_service.dart';

/// Widget to display peacock queue members with "Waiting" badges
///
/// Shows users waiting in queue with their position number
/// Displays prominently above regular lobby members
class PeacockQueueSection extends ConsumerWidget {
  final String lobbyId;
  final String gameName;

  const PeacockQueueSection({
    super.key,
    required this.lobbyId,
    required this.gameName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchPeacockQueue(lobbyId, gameName),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final queue = snapshot.data!;
        final theme = Theme.of(context);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.orange.withValues(alpha: 0.1),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Peacock Queue',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${queue.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Queue members list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final member = queue[index];
                  return _buildQueueMemberCard(context, ref, member, index + 1);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQueueMemberCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> member,
    int position,
  ) {
    final userUid = member['user_uid'] as String;
    final joinedAt = member['joined_at'] as String?;

    return ref.watch(ln.lobbyNotifierProvider).when(
          data: (state) {
            final displayName = state.memberDisplayNames[userUid] ?? 'Unknown';

            // Calculate wait time
            String waitTime = 'Just now';
            if (joinedAt != null) {
              try {
                final joinedTime = DateTime.parse(joinedAt);
                final diff = DateTime.now().difference(joinedTime);
                if (diff.inMinutes < 1) {
                  waitTime = 'Just now';
                } else if (diff.inMinutes < 60) {
                  waitTime = '${diff.inMinutes}m ago';
                } else {
                  waitTime = '${diff.inHours}h ago';
                }
              } catch (e) {
                // Ignore parsing errors
              }
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              color: Colors.grey[850],
              child: ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.5),
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.grey[850]!,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          '$position',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                title: Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Waiting for spot',
                  style: TextStyle(
                    color: Colors.orange.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'WAITING',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      waitTime,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Card(
            child: ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Loading...'),
            ),
          ),
          error: (e, s) => const Card(
            child: ListTile(
              title: Text('Error loading member'),
            ),
          ),
        );
  }

  Future<List<Map<String, dynamic>>> _fetchPeacockQueue(
    String lobbyId,
    String gameName,
  ) async {
    try {
      final response = await SupabaseService.client
          .from('peacock_queue')
          .select('*')
          .eq('lobby_id', lobbyId)
          .eq('game_name', gameName)
          .order('position', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }
}
