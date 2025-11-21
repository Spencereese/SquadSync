import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../../utils.dart';
import '../../services/ai_service.dart';
import '../chat_screen.dart';

/// Enhanced dialog for joining groups via codes, links, or QR scanning
class JoinGroupDialog extends StatefulWidget {
  const JoinGroupDialog({super.key});

  @override
  State<JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends State<JoinGroupDialog>
    with TickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  bool _isLoading = false;
  bool _isScanning = false;
  late TabController _tabController;
  String? _scannedCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _tabController.dispose();
    qrController?.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      qrController = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && !_isLoading) {
        setState(() {
          _scannedCode = scanData.code;
          _isScanning = false;
        });
        qrController?.pauseCamera();
        _joinGroupWithCode(scanData.code!);
      }
    });
  }

  Future<void> _joinGroupWithCode(String code) async {
    // Extract group ID and invite code from various formats
    String groupId = code;
    String? inviteCode;

    // Handle different code formats
    if (code.contains('?code=')) {
      // Format: codsquadapp://join/GROUP_ID?code=INVITE_CODE
      final uri = Uri.parse(code);
      groupId = uri.pathSegments.last;
      inviteCode = uri.queryParameters['code'];
    } else if (code.contains('/')) {
      // Format: GROUP_ID/INVITE_CODE
      final parts = code.split('/');
      if (parts.length >= 2) {
        groupId = parts[0];
        inviteCode = parts[1];
      }
    } else if (code.length > 20) {
      // Assume it's a direct group ID
      groupId = code;
    } else {
      // Assume it's an invite code, need to look it up
      inviteCode = code;
      groupId = await _findGroupIdFromInviteCode(code);
      if (groupId.isEmpty) {
        if (mounted) {
          showSnackBar(context, 'Invalid invite code');
        }
        return;
      }
    }

    await _joinGroup(groupId, inviteCode);
  }

  Future<String> _findGroupIdFromInviteCode(String inviteCode) async {
    try {
      // Search for the invite code across all groups
      final querySnapshot = await FirebaseFirestore.instance
          .collectionGroup('invites')
          .where('code', isEqualTo: inviteCode)
          .where('expiresAt', isGreaterThan: DateTime.now().toIso8601String())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final inviteDoc = querySnapshot.docs.first;
        final groupId = inviteDoc.reference.parent.parent!.id;
        return groupId;
      }
    } catch (e) {
      debugPrint('Error finding group from invite code: $e');
    }
    return '';
  }

  Future<void> _joinGroup(String groupId, String? inviteCode) async {
    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        showSnackBar(context, 'Please sign in first');
        return;
      }

      // Validate invite code if provided
      if (inviteCode != null) {
        final isValid = await _validateInviteCode(groupId, inviteCode);
        if (!isValid) {
          if (mounted) {
            showSnackBar(context, 'Invalid or expired invite code');
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      // Get group details
      final groupDoc = await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .get();

      if (!groupDoc.exists) {
        if (mounted) {
          showSnackBar(context, 'Group not found');
        }
        setState(() => _isLoading = false);
        return;
      }

      final groupData = groupDoc.data()!;
      final isPrivate = groupData['isPrivate'] ?? false;

      // Check if user is already a member
      final members = List<String>.from(groupData['members'] ?? []);
      if (members.contains(currentUser.uid)) {
        if (mounted) {
          showSnackBar(context, 'You are already a member of this group');
        }
        setState(() => _isLoading = false);
        return;
      }

      // For private groups, require invite code
      if (isPrivate && inviteCode == null) {
        if (mounted) {
          showSnackBar(
              context, 'This is a private group. An invite code is required.');
        }
        setState(() => _isLoading = false);
        return;
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

      // Update invite usage if code was used
      if (inviteCode != null) {
        await _incrementInviteUsage(groupId, inviteCode);
      }

      // Add group to user's groups list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'chatGroups': FieldValue.arrayUnion([groupId]),
      });

      if (mounted) {
        showSnackBar(context, 'Successfully joined ${groupData['name']}!');
        Navigator.pop(context);
        // Navigate to the chat screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatType: ChatType.userGroup,
              chatGroupId: groupId,
              chatGroupName: groupData['name'] ?? 'Unnamed Group',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error joining group: $e');
      if (mounted) {
        showSnackBar(context, 'Failed to join group. Please try again.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _validateInviteCode(String groupId, String inviteCode) async {
    try {
      final inviteDoc = await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .collection('invites')
          .doc(inviteCode)
          .get();

      if (!inviteDoc.exists) return false;

      final inviteData = inviteDoc.data()!;
      final expiresAt = DateTime.parse(inviteData['expiresAt']);
      final maxUses = inviteData['maxUses'] ?? 50;
      final uses = inviteData['uses'] ?? 0;

      return DateTime.now().isBefore(expiresAt) && uses < maxUses;
    } catch (e) {
      debugPrint('Error validating invite code: $e');
      return false;
    }
  }

  Future<void> _incrementInviteUsage(String groupId, String inviteCode) async {
    try {
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .collection('invites')
          .doc(inviteCode)
          .update({
        'uses': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing invite usage: $e');
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      setState(() {
        _codeController.text = clipboardData!.text!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Container(
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
                    Text(
                      'Join Group',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Code', icon: Icon(Icons.code)),
                  Tab(text: 'Scan QR', icon: Icon(Icons.qr_code_scanner)),
                  Tab(text: 'Browse', icon: Icon(Icons.explore)),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),

              // Tab Content
              Flexible(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Code Entry Tab
                    _buildCodeEntryTab(),

                    // QR Scanner Tab
                    _buildQRScannerTab(),

                    // Browse Groups Tab
                    _buildBrowseGroupsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCodeEntryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter Invite Code',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste an invite code or link to join a group',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 20),

          // Code Input Field
          TextField(
            controller: _codeController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Enter code or paste link...',
              hintStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: _pasteFromClipboard,
                    tooltip: 'Paste from clipboard',
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _codeController.clear(),
                    tooltip: 'Clear',
                  ),
                ],
              ),
            ),
            maxLines: 3,
            minLines: 1,
          ),

          const SizedBox(height: 20),

          // Join Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () => _joinGroupWithCode(_codeController.text.trim()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Group'),
            ),
          ),

          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to get an invite code:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Ask a group member to share an invite code\n'
                  '• Check your messages or notifications\n'
                  '• Scan a QR code if available\n'
                  '• Browse public groups in the "Browse" tab',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRScannerTab() {
    return Column(
      children: [
        // Scanner Area
        Expanded(
          child: _isScanning
              ? QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Theme.of(context).colorScheme.primary,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: MediaQuery.of(context).size.width * 0.8,
                  ),
                )
              : Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_scanner,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'QR Scanner Ready',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),

        // Controls
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              if (_scannedCode != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Scanned: $_scannedCode',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _isScanning = !_isScanning);
                        if (_isScanning) {
                          qrController?.resumeCamera();
                        } else {
                          qrController?.pauseCamera();
                        }
                      },
                      icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                      label: Text(_isScanning ? 'Stop' : 'Start Scan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () async {
                      await qrController?.toggleFlash();
                    },
                    icon: const Icon(Icons.flashlight_on),
                    tooltip: 'Toggle flash',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBrowseGroupsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_groups')
          .where('isPublic', isEqualTo: true)
          .orderBy('memberCount', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading groups: ${snapshot.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data?.docs ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Text(
              'No public groups available',
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          );
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index].data() as Map<String, dynamic>;
            final groupId = groups[index].id;

            return ListTile(
              leading: CircleAvatar(
                backgroundImage: group['imageUrl'] != null
                    ? NetworkImage(group['imageUrl'])
                    : null,
                child: group['imageUrl'] == null
                    ? Text(group['name']?.isNotEmpty == true
                        ? group['name'][0].toUpperCase()
                        : '?')
                    : null,
              ),
              title: Text(group['name'] ?? 'Unnamed Group'),
              subtitle: Text('${group['memberCount'] ?? 0} members'),
              trailing: ElevatedButton(
                onPressed: () => _joinGroup(groupId, null),
                child: const Text('Join'),
              ),
            );
          },
        );
      },
    );
  }
}
