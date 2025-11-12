import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import '../../utils.dart';
import '../../widgets/base_dialog.dart';

/// Enhanced dialog for joining groups via codes, links, or QR scanning
/// Now uses the unified BaseDialog system for consistent iOS-style design
class JoinGroupDialog extends BaseDialog {
  const JoinGroupDialog({super.key});

  @override
  BaseDialogState<BaseDialog> createState() => _JoinGroupDialogState();

  @override
  String? get title => 'Join Group';

  @override
  bool get showCloseButton => true;

  @override
  bool get dismissible => true;

  @override
  double? get maxWidth => 500;

  @override
  double? get maxHeight => 600;

  @override
  Widget buildContent(BuildContext context) {
    final state = context.findAncestorStateOfType<_JoinGroupDialogState>();
    return state?.buildContent(context) ?? const SizedBox();
  }
}

class _JoinGroupDialogState extends BaseDialogState<BaseDialog> {
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
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text?.isNotEmpty ?? false) {
      setState(() {
        _codeController.text = clipboardData!.text!;
      });
      context.lightImpact();
    }
  }

  Future<void> _joinGroupWithCode(String code) async {
    if (code.trim().isEmpty) {
      showSnackBar(context, 'Please enter a code or paste a link');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Handle different code formats (direct codes or invite links)
      String groupId = code.trim();

      // If it's a full URL, extract the code from it
      if (code.contains('codsquadapp://') || code.contains('join/')) {
        final uri = Uri.parse(code);
        if (uri.pathSegments.contains('join') && uri.pathSegments.length > 1) {
          groupId = uri.pathSegments[1];
        }
      }

      // Try to find the group by ID first
      final groupDoc = await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        await _joinGroup(groupId, null);
        return;
      }

      // If not found by ID, try searching by invite code
      final inviteQuery = await FirebaseFirestore.instance
          .collectionGroup('invites')
          .where('code', isEqualTo: groupId)
          .where('expiresAt', isGreaterThan: DateTime.now().toIso8601String())
          .limit(1)
          .get();

      if (inviteQuery.docs.isNotEmpty) {
        final inviteDoc = inviteQuery.docs.first;
        final groupId = inviteDoc.reference.parent.parent!.id;
        await _joinGroup(groupId, inviteDoc.id);
        return;
      }

      if (mounted) {
        showSnackBar(context, 'Invalid or expired invite code');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error joining group: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _joinGroup(String groupId, String? inviteId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final groupRef =
          FirebaseFirestore.instance.collection('chat_groups').doc(groupId);
      final groupDoc = await groupRef.get();

      if (!groupDoc.exists) {
        throw 'Group not found';
      }

      final groupData = groupDoc.data()!;
      final members = List<String>.from(groupData['members'] ?? []);

      if (members.contains(currentUser.uid)) {
        if (mounted) {
          showSnackBar(context, 'You are already a member of this group');
          Navigator.pop(context);
        }
        return;
      }

      // Add user to group
      await groupRef.update({
        'members': FieldValue.arrayUnion([currentUser.uid]),
        'memberCount': FieldValue.increment(1),
      });

      // Update invite usage if applicable
      if (inviteId != null) {
        await groupRef.collection('invites').doc(inviteId).update({
          'uses': FieldValue.increment(1),
        });
      }

      if (mounted) {
        showSnackBar(context,
            'Successfully joined ${groupData['name'] ?? 'the group'}!');
        Navigator.pop(context);

        // Navigate to the group chat
        Navigator.pushNamed(
          context,
          '/chat',
          arguments: {
            'chatGroupId': groupId,
            'chatGroupName': groupData['name'] ?? 'Group Chat',
            'chatType': 'group',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error joining group: $e');
      }
    }
  }

  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Code', icon: Icon(Icons.code)),
              Tab(text: 'Scan QR', icon: Icon(Icons.qr_code_scanner)),
              Tab(text: 'Browse', icon: Icon(Icons.explore)),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            indicator: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
          ),
        ),

        const SizedBox(height: 16),

        // Tab Content
        Expanded(
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
                  color: Theme.of(context).colorScheme.onSurface,
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
              fillColor:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
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
                    onPressed: () => setState(() => _codeController.clear()),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
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
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to get an invite code:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Ask a group member to share an invite code\n'
                  '• Check your messages or notifications\n'
                  '• Scan a QR code if available\n'
                  '• Browse public groups in the "Browse" tab',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.8),
                      ),
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
                    cutOutSize: MediaQuery.of(context).size.width * 0.7,
                  ),
                )
              : Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.3),
                      width: 1,
                    ),
                  ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
                color: Theme.of(context).dividerColor.withOpacity(0.3),
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
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scanned: $_scannedCode',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _scannedCode = null),
                        tooltip: 'Clear scanned code',
                      ),
                    ],
                  ),
                ),
              if (_scannedCode != null) const SizedBox(height: 16),
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
                      label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () async {
                      await qrController?.toggleFlash();
                      context.lightImpact();
                    },
                    icon: const Icon(Icons.flashlight_on),
                    tooltip: 'Toggle flash',
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_scannedCode != null)
                    IconButton(
                      onPressed: () => _joinGroupWithCode(_scannedCode!),
                      icon: const Icon(Icons.check),
                      tooltip: 'Join with scanned code',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading groups',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final groups = snapshot.data?.docs ?? [];

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.explore_off,
                  size: 48,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No public groups available',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Check back later or create your own group!',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index].data() as Map<String, dynamic>;
            final groupId = groups[index].id;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: group['imageUrl'] != null
                      ? NetworkImage(group['imageUrl'])
                      : null,
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  child: group['imageUrl'] == null
                      ? Text(
                          group['name']?.isNotEmpty == true
                              ? group['name'][0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  group['name'] ?? 'Unnamed Group',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${group['memberCount'] ?? 0} members',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
                trailing: ElevatedButton(
                  onPressed: () => _joinGroup(groupId, null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Join'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
