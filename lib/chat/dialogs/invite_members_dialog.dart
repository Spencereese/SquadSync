import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../utils.dart';

/// Simplified dialog for inviting members to group chats
class InviteMembersDialog extends StatefulWidget {
  final String chatGroupId;
  final String chatGroupName;
  final bool isSquadGroup;

  const InviteMembersDialog({
    super.key,
    required this.chatGroupId,
    required this.chatGroupName,
    this.isSquadGroup = false,
  });

  @override
  State<InviteMembersDialog> createState() => _InviteMembersDialogState();
}

class _InviteMembersDialogState extends State<InviteMembersDialog> {
  String? _inviteCode;
  bool _isGeneratingCode = true;

  @override
  void initState() {
    super.initState();
    _generateInviteCode();
  }

  Future<void> _generateInviteCode() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Generate a unique invite code using group ID
      final code = widget.chatGroupId.substring(0, 8).toUpperCase();

      // Store the invite code in Firestore for tracking
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(widget.chatGroupId)
          .collection('invites')
          .doc(code)
          .set({
        'code': code,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'maxUses': 50,
        'uses': 0,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _inviteCode = code;
          _isGeneratingCode = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating invite code: $e');
      if (mounted) {
        setState(() => _isGeneratingCode = false);
        showSnackBar(context, 'Failed to generate invite code');
      }
    }
  }

  Future<void> _shareInviteCode() async {
    if (_inviteCode == null) return;

    // Create a shareable deep link
    final deepLink =
        'https://squadsync.app/join/${widget.chatGroupId}?code=$_inviteCode';

    final inviteMessage = 'Join "${widget.chatGroupName}" on SquadSync!\n\n'
        'Invite Code: $_inviteCode\n'
        'Or click this link: $deepLink\n\n'
        'Open SquadSync and go to Join Group to enter the code.';

    try {
      await Share.share(inviteMessage, subject: 'Join ${widget.chatGroupName}');
    } catch (e) {
      // Fallback to clipboard
      await Clipboard.setData(ClipboardData(text: inviteMessage));
      if (mounted) {
        showSnackBar(context, 'Invite message copied to clipboard');
      }
    }
  }

  Future<void> _copyInviteCode() async {
    if (_inviteCode != null) {
      await Clipboard.setData(ClipboardData(text: _inviteCode!));
      if (mounted) {
        showSnackBar(context, 'Invite code copied: $_inviteCode');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add,
                      color: Colors.cyanAccent, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Invite to ${widget.chatGroupName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // QR Code Section
                    if (_inviteCode != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data:
                              'codsquadapp://join/${widget.chatGroupId}?code=$_inviteCode',
                          version: QrVersions.auto,
                          size: 180.0,
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Invite Code Section
                    Text(
                      'Invite Code',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    if (_isGeneratingCode)
                      const CircularProgressIndicator(color: Colors.cyanAccent)
                    else if (_inviteCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyanAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                _inviteCode!,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy,
                                  color: Colors.cyanAccent),
                              onPressed: _copyInviteCode,
                              tooltip: 'Copy code',
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Share Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            _inviteCode != null ? _shareInviteCode : null,
                        icon: const Icon(Icons.share),
                        label: const Text('Share Invite'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share the code or link with friends to invite them.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Code expires in 7 days\n• Limited to 50 uses',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
