import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/presence_badges.dart';
import '../../../widgets/presence_badge_row.dart';
import 'chat_info_widgets.dart';

/// Members section displaying horizontal scrollable list of squad members
///
/// Features:
/// - Horizontal scrollable member avatars
/// - Online status indicators
/// - Role badges (admin, mod)
/// - Add member button
/// - Member tap interactions
class ChatInfoMembersSection extends StatelessWidget {
  final String squadId;
  final List<Map<String, dynamic>> members;
  final Color neonColor;
  final VoidCallback onAddMemberPressed;

  const ChatInfoMembersSection({
    super.key,
    required this.squadId,
    required this.members,
    required this.neonColor,
    required this.onAddMemberPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Use placeholder data if members list is empty
    final displayMembers = members.isEmpty
        ? [
            {'uid': '1', 'name': 'Player 1', 'isOnline': true, 'role': 'admin'},
            {'uid': '2', 'name': 'Player 2', 'isOnline': true},
            {'uid': '3', 'name': 'Player 3', 'isOnline': false},
            {'uid': '4', 'name': 'Player 4', 'isOnline': true, 'role': 'mod'},
          ]
        : members;

    return SizedBox(
      height: 128,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: displayMembers.length + 1, // +1 for "Add Member" button
        itemBuilder: (context, index) {
          if (index == displayMembers.length) {
            return _buildAddMemberButton(context);
          }

          final member = displayMembers[index];
          final isOnline = member['isOnline'] as bool? ?? false;
          final role = member['role'] as String?;
          final uid = presenceUserIdFrom(member);

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ChatInfoMemberAvatar(
              name: member['name'] as String? ?? 'User',
              avatarUrl: member['avatarUrl'] as String?,
              isOnline: isOnline,
              role: role,
              neonColor: neonColor,
              presenceBadges: uid == null
                  ? null
                  : PresenceBadgesHost(userId: uid, compact: true),
            ),
          );
        },
      ),
    );
  }

  /// Add member button with glassmorphic design
  Widget _buildAddMemberButton(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
              border: Border.all(
                color: neonColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAddMemberPressed,
                customBorder: const CircleBorder(),
                child: Icon(
                  Icons.person_add,
                  color: neonColor,
                  size: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: neonColor.withOpacity(0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
