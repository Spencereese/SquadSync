import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart' as record_package;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert'; // Added for utf8
import 'dart:async'; // Added for StreamSubscription
import 'package:cod_squad_app/app_theme.dart';
import '../squad_state.dart';
import 'chat_input_bar.dart';
import 'chat_service.dart';
import 'chat_settings_menu.dart';
import 'chat_state.dart';
import 'sqlite_helper.dart';
import 'squad_sheet.dart';
import 'message_bubble.dart';
import '../no_squad_screen.dart';
import '../screens/squad_tab_screen.dart';
import 'peacock_modal.dart';
import 'poll_creation_dialog.dart';
// import 'available_squads_widget.dart'; // Removed - no longer used

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  final String? chatGroupId;
  final String? chatGroupName;
  const ChatScreen(
      {super.key, this.initialMessage, this.chatGroupId, this.chatGroupName});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final record_package.AudioRecorder _audioRecorder =
      record_package.AudioRecorder();
  late AnimationController _animationController;
  String? _audioPath;
  String _searchQuery = '';
  String _chatName = 'Squad Chat';
  String? _chatImageUrl;
  final ChatService _chatService = ChatService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();
  late SquadState _squadState;
  bool _showJumpToBottom = false;
  bool _isMuted = false;
  final List<Map<String, dynamic>> _historicalMessages = []; // Made final
  StreamSubscription<String?>? _typingSubscription;

  // Pagination state
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  int _currentOffset = 0;
  static const int _messagesPerPage = 50;

  // Cache for user display names to avoid FutureBuilder in ListView
  final Map<String, String> _userDisplayNameCache = {};
  bool _isLoadingUserNames = false;

  // Cache for processed messages to avoid expensive operations in build
  List<dynamic> _processedMessages = [];
  Map<String, List<String>> _lastReadByCache = {};
  bool _needsMessageProcessing = true;

  Future<void> _initializeChat() async {
    // Update online status
    _updateOnlineStatus(true);

    // Load chat details
    await _loadChatDetails();

    // Load notification settings
    await _loadNotificationSettings();

    // Load quick reaction emoji
    await Provider.of<ChatState>(context, listen: false)
        .loadQuickReactionEmoji();

    // Load user display names for better performance
    await _loadUserDisplayNames();

    // Load initial historical messages
    await _loadMoreMessages();

    // Check for handoff draft
    await _checkHandoffDraft();

    // Handle initial message if provided
    if (widget.initialMessage != null && mounted) {
      _messageController.text = widget.initialMessage!;
      _sendMessage();
    }

    // Scroll to bottom after everything is loaded
    _scrollToBottom();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _squadState = Provider.of<SquadState>(context, listen: false);

    // Set chat name from widget parameters if provided (for chat groups)
    if (widget.chatGroupName != null) {
      _chatName = widget.chatGroupName!;
    }

    // Defer heavy operations to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Batch all initialization operations
      _initializeChat();
    });

    // Add listeners immediately for responsiveness
    _squadState.addListener(_updateTyping);
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _updateOnlineStatus(false);
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _messageController.dispose();
    _animationController.dispose();
    _audioRecorder.dispose();
    _squadState.removeListener(_updateTyping);
    _typingSubscription?.cancel();
    _saveDraftForHandoff();
    super.dispose();
  }

  void _scrollListener() {
    final shouldShow = _scrollController.offset > 100;
    if (shouldShow != _showJumpToBottom) {
      // Use Future.microtask to debounce setState calls
      Future.microtask(() => setState(() => _showJumpToBottom = shouldShow));
    }

    // Load more messages when scrolling near the top
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    setState(() => _isLoadingMore = true);

    try {
      final moreMessages = await _chatService.loadMoreMessages(
        offset: _currentOffset,
        limit: _messagesPerPage,
      );

      if (moreMessages.isEmpty || moreMessages.length < _messagesPerPage) {
        _hasMoreMessages = false;
      }

      setState(() {
        _historicalMessages.addAll(moreMessages);
        _currentOffset += moreMessages.length;
        _isLoadingMore = false;
        _needsMessageProcessing = true; // Trigger reprocessing
      });
    } catch (e) {
      debugPrint('Failed to load more messages: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  void _updateTyping() {
    if (mounted) {
      // Cancel previous subscription to prevent memory leaks
      _typingSubscription?.cancel();

      // Use ChatService.getTypingUser for chat-specific typing
      _typingSubscription = _chatService
          .getTypingUser(context, chatGroupId: widget.chatGroupId)
          .listen((typingUser) {
        if (mounted) {
          String? myName = _squadState.displayName;
          Provider.of<ChatState>(context, listen: false).setTypingUser(
            typingUser != null && typingUser != myName ? typingUser : null,
          );
        }
      });
    }
  }

  void _updateOnlineStatus(bool isOnline) {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      String displayName = _squadState.displayName ??
          _auth.currentUser?.displayName ??
          'Anonymous';
      if (displayName == 'User' || displayName.isEmpty) {
        displayName = _auth.currentUser?.displayName ?? 'Anonymous';
      }
      debugPrint('Updating online status: uid=$uid, displayName=$displayName');
      _firestore.collection('users').doc(uid).set({
        'displayName': displayName,
        'profileImage': _squadState.profileImage,
        'lastOnline': FieldValue.serverTimestamp(),
        'online': isOnline,
      }, SetOptions(merge: true));
    } else {
      debugPrint('No authenticated user');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadChatDetails() async {
    if (!mounted) return;
    final squadState = Provider.of<SquadState>(context, listen: false);
    final squadId = squadState.selectedSquadId;
    try {
      if (widget.chatGroupId != null) {
        // Load group chat details
        final groupDoc = await _firestore
            .collection('squads')
            .doc(squadId)
            .collection('chat_groups')
            .doc(widget.chatGroupId)
            .get();
        if (groupDoc.exists && mounted) {
          final groupData = groupDoc.data() as Map<String, dynamic>;
          setState(() {
            _chatName = groupData['name'] ?? 'Group Chat';
            _chatImageUrl = groupData['imageUrl'];
          });
        }
        return;
      }

      // Load squad chat details
      final doc =
          await _firestore.collection('chat_metadata').doc('chat_config').get();
      if (doc.exists && mounted) {
        setState(() {
          _chatName = doc.data()?['name'] ?? 'Squad Chat';
          _chatImageUrl = doc.data()?['imageUrl'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load chat details: $e')));
      }
    }
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isMuted = prefs.getBool('chat_muted') ?? false;
      });
    }
  }

  Future<void> _toggleNotifications() async {
    if (!mounted) return;
    final wasMuted = _isMuted;
    setState(() {
      _isMuted = !_isMuted;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('chat_muted', _isMuted);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _isMuted ? 'Notifications muted' : 'Notifications unmuted')),
        );
      }
    } catch (e) {
      // Revert state on error
      if (mounted) {
        setState(() {
          _isMuted = wasMuted;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    if (!mounted) return;

    // Handle commands
    if (_messageController.text.startsWith('/')) {
      await _handleCommand(_messageController.text);
      _messageController.clear();
      return;
    }

    final chatState = Provider.of<ChatState>(context, listen: false);
    final displayName = _squadState.displayName ?? 'Anonymous';
    String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    chatState.updateSendingStatus(tempId, true);

    // Get reply information
    final replyTo = chatState.replyToMessage?['id'] as String?;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final result = await _chatService.sendMessage(context,
          senderUid: user.uid,
          text: _messageController.text,
          replyTo: replyTo,
          chatGroupId: widget.chatGroupId);

      if (result.success) {
        if (result.isOffline && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Message queued for sending when online')),
          );
        }
        chatState.removeSendingStatus(tempId);
        _messageController.clear();
        // Clear reply after sending
        chatState.clearReplyToMessage();
        await _chatService.updateTypingStatus(context, displayName, false,
            chatGroupId: widget.chatGroupId);
        _scrollToBottom();
        await _checkFirstMessage();
      } else {
        // Handle failure
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.errorMessage ?? 'Send failed')),
          );
          chatState.updateSendingStatus(tempId, false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
        chatState.updateSendingStatus(tempId, false);
      }
    }
  }

  Future<void> _handleCommand(String command) async {
    if (command.toLowerCase().startsWith('/peacock')) {
      _showPeacockModal(context);
    }
    // Add other commands here if needed
  }

  Future<void> _sendMedia() async {
    if (!mounted) return;
    final chatState = Provider.of<ChatState>(context, listen: false);
    try {
      final XFile? media = await _picker.pickMedia();
      if (media == null) return;
      chatState.setUploading(true);
      File file = File(media.path);
      bool isVideo = media.mimeType?.startsWith('video/') ?? false;
      final user = _auth.currentUser;
      if (user == null) return;
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.${isVideo ? 'mp4' : 'jpg'}';
      String downloadUrl =
          await _chatService.uploadMedia(file, fileName, isVideo);
      final timestampMs = DateTime.now().millisecondsSinceEpoch;
      await _chatService.sendMessage(
        context,
        senderUid: user.uid,
        text: '',
        photos: !isVideo
            ? [
                {'uri': downloadUrl, 'creation_timestamp': timestampMs}
              ]
            : [],
        videos: isVideo
            ? [
                {'uri': downloadUrl, 'creation_timestamp': timestampMs}
              ]
            : [],
        chatGroupId: widget.chatGroupId,
      );
      chatState.setUploading(false);
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Media upload failed: $e')));
        chatState.setUploading(false);
      }
    }
  }

  Future<void> _startRecording() async {
    if (!mounted) return;
    final chatState = Provider.of<ChatState>(context, listen: false);
    if (await _audioRecorder.hasPermission()) {
      try {
        final directory = Directory.systemTemp;
        final path =
            '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const record_package.RecordConfig(),
            path: path);
        chatState.setRecording(true);
        _animationController.repeat();
        HapticFeedback.mediumImpact();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Recording failed: $e')));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission Denied')));
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!mounted) return;
    final chatState = Provider.of<ChatState>(context, listen: false);
    try {
      String? path = await _audioRecorder.stop();
      _animationController.stop();
      chatState.setRecording(false);
      if (path != null) {
        _audioPath = path;
        if (mounted) await _uploadAudio();
      }
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to stop recording: $e')));
      }
    }
  }

  Future<void> _uploadAudio() async {
    if (!mounted) return;
    final chatState = Provider.of<ChatState>(context, listen: false);
    if (_audioPath == null) return;
    chatState.setUploading(true);
    try {
      File file = File(_audioPath!);
      final user = _auth.currentUser;
      if (user == null) return;
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${user.uid}.m4a';
      String downloadUrl = await _chatService.uploadAudio(file, fileName);
      final timestampMs = DateTime.now().millisecondsSinceEpoch;
      await _chatService.sendMessage(
        context,
        senderUid: user.uid,
        text: '',
        audio: [
          {'uri': downloadUrl, 'creation_timestamp': timestampMs}
        ],
        chatGroupId: widget.chatGroupId,
      );
      chatState.setUploading(false);
      _audioPath = null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Audio upload failed: $e')));
        chatState.setUploading(false);
      }
    }
  }

  Future<void> _forwardMessage(String messageText) async {
    if (!mounted) return;
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _chatService.sendMessage(
        context,
        senderUid: user.uid,
        text: 'Forwarded: $messageText',
        chatGroupId: widget.chatGroupId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Message forwarded')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to forward message: $e')));
      }
    }
  }

  void _showMessageDetails(dynamic message) {
    if (!mounted) return;
    Map<String, dynamic> data;
    int timestampMillis;

    if (message is DocumentSnapshot) {
      data = message.data() as Map<String, dynamic>? ?? {};
      timestampMillis = data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).millisecondsSinceEpoch
          : data['timestamp_ms'] as int? ??
              DateTime.now().millisecondsSinceEpoch;
    } else if (message is Map<String, dynamic>) {
      data = message;
      timestampMillis =
          data['timestamp_ms'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    } else {
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black, // Replaced AppTheme.backgroundColor
        title: const Text('Message Details'),
        content: Semantics(
          label:
              'Message sent at ${DateFormat('MMMM d, yyyy, HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(timestampMillis))}',
          child: Text(
            'Sent: ${DateFormat('MMM d, yyyy, HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(timestampMillis))}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('OK', style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkFirstMessage() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('first_message_sent')) {
        await prefs.setBool('first_message_sent', true);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
                  const SnackBar(content: Text('🎉 First message sent!')))
              .closed
              .then((_) => Animate(
                    effects: const [
                      FadeEffect(duration: Duration(milliseconds: 500))
                    ],
                    child: const Text(''),
                  ));
        }
      }
    } catch (e) {
      // Silently handle error - this is not critical
    }
  }

  Future<void> _checkHandoffDraft() async {
    final prefs = await SharedPreferences.getInstance();
    String? draft = prefs.getString('chat_draft');
    if (draft != null && mounted) {
      _messageController.text = draft;
      await _chatService.updateTypingStatus(
          context, _squadState.displayName ?? 'User', true,
          chatGroupId: widget.chatGroupId);
    }
  }

  Future<void> _saveDraftForHandoff() async {
    final prefs = await SharedPreferences.getInstance();
    if (_messageController.text.isNotEmpty) {
      await prefs.setString('chat_draft', _messageController.text);
    } else {
      await prefs.remove('chat_draft');
    }
  }

  void _viewGroupInfo() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Group Info')),
          body: Center(child: Text('Group Info for $_chatName')),
        ),
      ),
    );
  }

  void _reportBug() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug report submitted')),
    );
  }

  void _leaveGroup() async {
    if (!mounted) return;
    try {
      await _squadState.leaveSquad();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have left the squad')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave squad: $e')),
        );
      }
    }
  }

  void _showPlusMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black, // Replaced AppTheme.backgroundColor
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Location'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.poll),
            title: const Text('Poll'),
            onTap: () {
              Navigator.pop(context);
              PollCreationDialog.show(context, chatGroupId: widget.chatGroupId);
            },
          ),
          ListTile(
            leading: const Icon(Icons.flash_on),
            title: const Text('Squad Up'),
            onTap: () {
              Navigator.pop(context);
              _showPeacockModal(context);
            },
          ),
        ],
      ),
    );
  }

  void _showMessageActionMenu(
      BuildContext context, dynamic message, bool isMe) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply, color: Colors.blue),
            title: const Text('Reply'),
            onTap: () {
              Navigator.pop(context);
              _setReplyToMessage(message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.forward, color: Colors.green),
            title: const Text('Forward'),
            onTap: () {
              Navigator.pop(context);
              final text = _getMessageText(message);
              _forwardMessage(text);
            },
          ),
          if (isMe)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
        ],
      ),
    );
  }

  void _setReplyToMessage(dynamic message) {
    // Store the message to reply to in chat state
    final chatState = Provider.of<ChatState>(context, listen: false);
    final messageData = message is DocumentSnapshot
        ? message.data() as Map<String, dynamic>
        : message as Map<String, dynamic>;
    chatState.setReplyToMessage(messageData);
    HapticFeedback.lightImpact();
  }

  String _getMessageText(dynamic message) {
    final data = message is DocumentSnapshot
        ? message.data() as Map<String, dynamic>
        : message as Map<String, dynamic>;
    return data['text'] ?? data['content'] ?? '';
  }

  void _deleteMessage(dynamic message) async {
    if (!mounted) return;

    try {
      // Extract message ID
      final messageId =
          message is DocumentSnapshot ? message.id : message['id']?.toString();
      if (messageId == null || messageId.isEmpty) {
        debugPrint(
            'Delete failed: Invalid message ID - message: $message, type: ${message.runtimeType}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to delete message: Invalid message ID')),
          );
        }
        return;
      }

      // Determine collection path based on chat type
      final squadId = _squadState.selectedSquadId;
      if (squadId == null) {
        debugPrint('Delete failed: No squad ID available');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to delete message: No squad context')),
          );
        }
        return;
      }

      final collectionPath = widget.chatGroupId != null
          ? 'squads/$squadId/chat_groups/${widget.chatGroupId}/messages'
          : 'squads/$squadId/chat';

      debugPrint('Deleting message: ID=$messageId, collection=$collectionPath');

      await _firestore.collection(collectionPath).doc(messageId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }

      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Error deleting message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete message: $e')),
        );
      }
    }
  }

  void _showPeacockModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: PeacockModal(),
        );
      },
    );
  }

  int? _getTimestampMs(dynamic message) {
    if (message is DocumentSnapshot) {
      final data = message.data() as Map<String, dynamic>?;
      if (data?['timestamp'] is Timestamp) {
        return (data?['timestamp'] as Timestamp).millisecondsSinceEpoch;
      }
      return data?['timestamp_ms'] as int?;
    } else if (message is Map<String, dynamic>) {
      return message['timestamp_ms'] as int?;
    }
    return null;
  }

  String? _getSender(dynamic message) {
    if (message is DocumentSnapshot) {
      final data = message.data() as Map<String, dynamic>?;
      return data?['senderUid'] as String?;
    } else if (message is Map<String, dynamic>) {
      return message['senderUid'] as String?;
    }
    return null;
  }

  void _processMessages(List<dynamic> rawMessages) {
    if (rawMessages.isEmpty) {
      _processedMessages = [];
      _lastReadByCache = {};
      return;
    }

    // Deduplicate by ID (optimized)
    final seenIds = <String>{};
    final deduplicated = rawMessages.where((msg) {
      final id = msg is DocumentSnapshot ? msg.id : msg['id']?.toString() ?? '';
      if (seenIds.contains(id)) return false;
      seenIds.add(id);
      return true;
    }).toList();

    // Filter messages to only show from squad members (pre-filtered)
    final filteredMembers = _squadState.getFilteredMembers;
    final filtered = deduplicated.where((msg) {
      final data = msg is DocumentSnapshot
          ? msg.data() as Map<String, dynamic>?
          : msg as Map<String, dynamic>;
      if (data == null) return false;
      final senderUid = data['senderUid'] ?? '';
      final senderDisplayName = _squadState.getDisplayNameForUid(senderUid);
      return filteredMembers.contains(senderDisplayName);
    }).toList();

    // Sort by timestamp (only if needed)
    filtered.sort((a, b) {
      final aTs = _getTimestampMs(a) ?? 0;
      final bTs = _getTimestampMs(b) ?? 0;
      return bTs.compareTo(aTs);
    });

    // Cap at 500 messages
    _processedMessages = filtered.take(500).toList();

    // Pre-calculate read status (optimized)
    _lastReadByCache = {};
    for (var message in _processedMessages) {
      final data = message is DocumentSnapshot
          ? message.data() as Map<String, dynamic>?
          : message as Map<String, dynamic>;
      if (data == null || data['read'] != true) continue;

      String sender = data['sender'] ?? '';
      String uid = _auth.currentUser!.uid;
      _lastReadByCache[sender] ??= [];
      if (!_lastReadByCache[sender]!.contains(uid)) {
        _lastReadByCache[sender]!.add(uid);
      }
    }

    _needsMessageProcessing = false;
  }

  Future<void> _loadUserDisplayNames() async {
    if (_isLoadingUserNames) return;
    _isLoadingUserNames = true;

    try {
      // Get all unique user IDs from current squad members
      final memberUids = _squadState.getFilteredMembers
          .map((displayName) => _squadState.getUidForDisplayName(displayName))
          .where((uid) => uid != null)
          .cast<String>()
          .toSet();

      // Load display names for users we don't have cached
      final uidsToLoad = memberUids
          .where((uid) => !_userDisplayNameCache.containsKey(uid))
          .toList();

      if (uidsToLoad.isNotEmpty) {
        final userDocs = await Future.wait(uidsToLoad
            .map((uid) => _firestore.collection('users').doc(uid).get()));

        for (int i = 0; i < uidsToLoad.length; i++) {
          final uid = uidsToLoad[i];
          final doc = userDocs[i];
          if (doc.exists) {
            final displayName =
                doc.data()?['displayName'] as String? ?? 'Unknown';
            _userDisplayNameCache[uid] = displayName;
          }
        }

        // Trigger rebuild to update cached names
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error loading user display names: $e');
    } finally {
      _isLoadingUserNames = false;
    }
  }

  String _cleanText(String text) {
    // Force UTF-8 decoding if needed, but since from Firestore, replace common garbled patterns
    try {
      // If text is garbled, attempt to re-encode/decode
      final bytes = latin1.encode(text); // Assume wrong encoding
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {}
    // Manual replacements for common Messenger corruptions
    return text
        .replaceAll('â’', "'") // Curly apostrophe
        .replaceAll('â“', '"') // Left double quote
        .replaceAll('â”', '"') // Right double quote
        .replaceAll('â’', "'") // Right single quote
        .replaceAll('â€', '-') // Em dash
        .replaceAll('â…', '...') // Ellipsis
        .replaceAll('ðŸ‘�', '👍') // Thumbs up
        .replaceAll('ðŸ˜‚', '😂') // Laughing
        .replaceAll('ðŸ˜¢', '😢') // Sad
        .replaceAll('ðŸ˜¡', '😡') // Angry
        .replaceAll('â�¤ï¸�', '❤️') // Heart
        .replaceAll('ð', '👍') // Generic corrupted emoji fallback
        .replaceAll('ð®', '❤️'); // Another common corruption
  }

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);
    if (squadState.selectedSquadId == null) {
      return const NoSquadScreen();
    }
    return SafeArea(
      top: true,
      bottom: false,
      child: Scaffold(
        body: Consumer<ChatState>(
          builder: (context, chatState, _) {
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            final bottomPadding = keyboardHeight > 0 ? keyboardHeight : 2.0;
            return MediaQuery.removePadding(
              context: context,
              removeBottom: keyboardHeight > 0,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black, Colors.indigo],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: AnimatedOpacity(
                              opacity: 1.0,
                              duration: const Duration(milliseconds: 300),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () =>
                                        ChatSettingsMenu.showChatOptions(
                                      context: context,
                                      onSearchMessages: () =>
                                          ChatSettingsMenu.showSearchBar(
                                        context: context,
                                        firestore: _firestore,
                                        searchQuery: _searchQuery,
                                        onSearchQueryChanged: (value) =>
                                            setState(
                                                () => _searchQuery = value),
                                      ),
                                      onChangeChatName: () => ChatSettingsMenu
                                          .showChangeChatNameDialog(
                                        context: context,
                                        currentName: _chatName,
                                        onSave: (newName) async {
                                          // ignore: use_build_context_synchronously
                                          if (!mounted) return;
                                          try {
                                            await _firestore
                                                .collection('chat_metadata')
                                                .doc('chat_config')
                                                .set({
                                              'name': newName,
                                              'timestamp':
                                                  FieldValue.serverTimestamp(),
                                            }, SetOptions(merge: true));
                                            // ignore: use_build_context_synchronously
                                            if (mounted) {
                                              setState(
                                                  () => _chatName = newName);
                                            }
                                          } catch (e) {
                                            // ignore: use_build_context_synchronously
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          'Failed to update chat name: $e')));
                                            }
                                          }
                                        },
                                      ),
                                      onChangeChatImage: () async {
                                        // ignore: use_build_context_synchronously
                                        if (!mounted) return;
                                        final XFile? image =
                                            await _picker.pickImage(
                                                source: ImageSource.gallery);
                                        if (image == null) return;
                                        try {
                                          File file = File(image.path);
                                          String fileName =
                                              'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                          String downloadUrl =
                                              await _chatService.uploadMedia(
                                                  file, fileName, false);
                                          await _firestore
                                              .collection('chat_metadata')
                                              .doc('chat_config')
                                              .set({
                                            'imageUrl': downloadUrl,
                                            'timestamp':
                                                FieldValue.serverTimestamp(),
                                          }, SetOptions(merge: true));
                                          // ignore: use_build_context_synchronously
                                          if (mounted) {
                                            setState(() =>
                                                _chatImageUrl = downloadUrl);
                                            HapticFeedback.lightImpact();
                                          }
                                        } catch (e) {
                                          // ignore: use_build_context_synchronously
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Image upload failed: $e')));
                                          }
                                        }
                                      },
                                      onClearChat: () async {
                                        // ignore: use_build_context_synchronously
                                        if (!mounted) return;
                                        try {
                                          // Determine collection path based on chat type
                                          final squadId =
                                              _squadState.selectedSquadId;
                                          if (squadId == null)
                                            return; // Should not happen in squad context
                                          final collectionPath = widget
                                                      .chatGroupId !=
                                                  null
                                              ? 'squads/$squadId/chat_groups/${widget.chatGroupId}/messages'
                                              : 'squads/$squadId/chat';

                                          final snapshot = await _firestore
                                              .collection(collectionPath)
                                              .get();
                                          for (var doc in snapshot.docs) {
                                            await doc.reference.delete();
                                          }
                                          // ignore: use_build_context_synchronously
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content:
                                                        Text('Chat cleared')));
                                          }
                                        } catch (e) {
                                          // ignore: use_build_context_synchronously
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Failed to clear chat: $e')));
                                          }
                                        }
                                      },
                                      onQuickReactionPicker: () =>
                                          ChatSettingsMenu
                                              .showQuickReactionPicker(
                                        context: context,
                                        onEmojiSelected: (emoji) {
                                          Provider.of<ChatState>(context,
                                                  listen: false)
                                              .setQuickReactionEmoji(emoji);
                                        },
                                      ),
                                      onToggleNotifications:
                                          _toggleNotifications,
                                      isMuted: _isMuted,
                                      onViewGroupInfo: _viewGroupInfo,
                                      onReportBug: _reportBug,
                                      onLeaveGroup: _leaveGroup,
                                    ),
                                    child: Semantics(
                                      label: 'Chat options',
                                      child: Row(
                                        children: [
                                          // Add back button for chat groups
                                          if (widget.chatGroupId != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8.0),
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.arrow_back,
                                                  color: Colors.cyanAccent,
                                                  size: 24,
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                tooltip: 'Back to groups',
                                              ),
                                            ),
                                          if (_chatImageUrl != null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 8.0),
                                              child: CircleAvatar(
                                                radius: 20,
                                                backgroundImage: NetworkImage(
                                                    _chatImageUrl!),
                                              ),
                                            )
                                          else
                                            const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: CircleAvatar(
                                                radius: 20,
                                                child: Icon(Icons.group,
                                                    color: Colors.cyanAccent),
                                              ),
                                            ),
                                          Text(
                                            _chatName,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.accentColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Consumer<SquadState>(
                                    builder: (context, squadState, _) {
                                      int onlineCount = squadState
                                          .statuses.values
                                          .where((status) =>
                                              status == 'Strutting' ||
                                              status == 'Walking' ||
                                              status == 'Ready')
                                          .length;
                                      return GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const SquadTabScreen()));
                                        },
                                        child: Semantics(
                                          label:
                                              '$onlineCount members online, tap to view squad',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  'Online: $onlineCount',
                                                  style: TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.7),
                                                  size: 16,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(),
                        // Active Squad Header Card
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('peacocks')
                              .where('hostUid',
                                  isEqualTo: _auth.currentUser?.uid)
                              .where('timer', isGreaterThan: Timestamp.now())
                              .orderBy('timer', descending: false)
                              .limit(1)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData ||
                                snapshot.data!.docs.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final peacock = snapshot.data!.docs.first.data()
                                as Map<String, dynamic>;
                            final gameName =
                                peacock['game']?['name'] ?? 'Unknown Game';
                            final maxSpots = peacock['spots'] ?? 4;
                            final claimed =
                                (peacock['filled'] as List<dynamic>?)?.length ??
                                    0;
                            return GestureDetector(
                              onTap: () => SquadSheet.show(context),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.cyanAccent
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.flash_on,
                                        color: Colors.cyanAccent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Your Active Squad: $gameName - $claimed/$maxSpots spots',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios,
                                        color: Colors.white70, size: 16),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // Available Squads Widget
                        // const AvailableSquadsWidget(), // Removed - keeping only "Your Active Squad" widget
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _chatService.getChatMessages(context,
                                chatGroupId: widget.chatGroupId),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return const Center(
                                    child: Text('Error loading chat'));
                              }
                              if (!snapshot.hasData &&
                                  _historicalMessages.isEmpty) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              }

                              // Process messages only when data changes
                              List<dynamic> allMessages = [];
                              if (snapshot.hasData) {
                                allMessages.addAll(snapshot.data!.docs);
                              }
                              allMessages.addAll(_historicalMessages);

                              // Only process if messages changed
                              if (_needsMessageProcessing ||
                                  allMessages.length !=
                                      _processedMessages.length) {
                                _processMessages(allMessages);
                              }

                              if (_processedMessages.isEmpty) {
                                return const Center(
                                    child: Text('No messages yet'));
                              }

                              return ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                itemCount: _processedMessages.length +
                                    (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  // Show loading indicator at the top (index 0 since reverse: true)
                                  if (index == 0 && _isLoadingMore) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.cyanAccent,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  // Adjust index for loading indicator
                                  final messageIndex =
                                      _isLoadingMore ? index - 1 : index;
                                  var message =
                                      _processedMessages[messageIndex];
                                  final data = message is DocumentSnapshot
                                      ? message.data() as Map<String, dynamic>?
                                      : message as Map<String, dynamic>;
                                  if (data == null) {
                                    return const SizedBox.shrink();
                                  }

                                  // Clean text only once per message (cached)
                                  final cleanedData =
                                      Map<String, dynamic>.from(data);
                                  if (cleanedData['content'] != null) {
                                    cleanedData['content'] =
                                        _cleanText(cleanedData['content']);
                                  }
                                  if (cleanedData['text'] != null) {
                                    cleanedData['text'] =
                                        _cleanText(cleanedData['text']);
                                  }
                                  if (cleanedData['reactions'] is List) {
                                    final reactions =
                                        cleanedData['reactions'] as List;
                                    for (var reaction in reactions) {
                                      if (reaction is Map &&
                                          reaction['reaction'] != null) {
                                        reaction['reaction'] =
                                            _cleanText(reaction['reaction']);
                                      }
                                    }
                                  }

                                  bool isMe = cleanedData['senderUid'] ==
                                      _auth.currentUser?.uid;
                                  if (!isMe &&
                                      !(cleanedData['delivered'] ?? false)) {
                                    if (message is DocumentSnapshot) {
                                      _chatService.markAsDelivered(message.id);
                                    }
                                  }

                                  String? currentSender = _getSender(message);
                                  String? nextSender =
                                      index < _processedMessages.length - 1
                                          ? _getSender(
                                              _processedMessages[index + 1])
                                          : null;
                                  String? prevSender = index > 0
                                      ? _getSender(
                                          _processedMessages[index - 1])
                                      : null;

                                  bool showSender = !isMe &&
                                      (index == _processedMessages.length - 1 ||
                                          currentSender != nextSender);
                                  bool showAvatar = !isMe &&
                                      (index == 0 ||
                                          currentSender != prevSender);

                                  int? currentTimestamp =
                                      _getTimestampMs(message);
                                  int? prevTimestamp = index > 0
                                      ? _getTimestampMs(
                                          _processedMessages[index - 1])
                                      : null;
                                  bool showTimestamp = index > 0 &&
                                      currentTimestamp != null &&
                                      prevTimestamp != null &&
                                      DateTime.fromMillisecondsSinceEpoch(
                                                  prevTimestamp)
                                              .difference(DateTime
                                                  .fromMillisecondsSinceEpoch(
                                                      currentTimestamp))
                                              .inMinutes >
                                          30;

                                  bool showReadIndicator = !isMe &&
                                      _lastReadByCache[
                                                  cleanedData['senderUid'] ??
                                                      '']
                                              ?.contains(
                                                  _auth.currentUser!.uid) ==
                                          true;

                                  final senderUid =
                                      cleanedData['senderUid'] as String?;
                                  final displayName = senderUid != null
                                      ? _userDisplayNameCache[senderUid] ??
                                          _squadState
                                              .getDisplayNameForUid(senderUid)
                                      : 'Unknown';

                                  cleanedData['sender'] = displayName;

                                  return GestureDetector(
                                    onLongPress: () => _showMessageActionMenu(
                                        context, message, isMe),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: MessageBubble(
                                        message: cleanedData,
                                        isMe: isMe,
                                        showSender: showSender,
                                        showAvatar: showAvatar,
                                        showTimestamp: showTimestamp,
                                        showReadIndicator: showReadIndicator,
                                        onTap: () =>
                                            _showMessageDetails(message),
                                        onLongPress: () => _forwardMessage(
                                            cleanedData['text'] ??
                                                cleanedData['content'] ??
                                                ''),
                                        sendingStatus: chatState.sendingStatus,
                                        chatGroupId: widget.chatGroupId,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        // Reply preview
                        if (chatState.replyToMessage != null)
                          _buildReplyPreview(context, chatState),
                        Semantics(
                          label: 'Chat input bar',
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: bottomPadding,
                              left: 8.0,
                              right: 8.0,
                            ),
                            child: ChatInputBar(
                              controller: _messageController,
                              isRecording: chatState.isRecording,
                              isUploading: chatState.isUploading,
                              onSend: _sendMessage,
                              onMedia: _sendMedia,
                              onRecordStart: _startRecording,
                              onRecordStop: _stopRecording,
                              onPlusMenu: () => _showPlusMenu(context),
                              onTextChanged: (value) {
                                String? sender =
                                    _squadState.displayName ?? 'User';
                                _chatService.updateTypingStatus(
                                    context, sender, value.isNotEmpty,
                                    chatGroupId: widget.chatGroupId);
                              },
                              quickReactionEmoji: chatState.quickReactionEmoji,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showJumpToBottom)
                      Positioned(
                        bottom: bottomPadding + 80,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: _scrollToBottom,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.8),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_downward,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        // Removed floating action button for peacock - now only in squad lobbies
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context, ChatState chatState) {
    final replyMessage = chatState.replyToMessage!;
    final sender = replyMessage['sender'] ?? 'Unknown';
    final text = replyMessage['text'] ?? replyMessage['content'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to $sender',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[200],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text.length > 100 ? '${text.substring(0, 100)}...' : text,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: Colors.white70),
            onPressed: () {
              chatState.clearReplyToMessage();
              HapticFeedback.lightImpact();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, String sender) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isBlocked = _squadState.userBlocks[uid]?.containsKey(sender) ?? false;
    final action = isBlocked ? 'Unblock' : 'Block Player';
    final message = isBlocked
        ? 'Unblock $sender? You will see each other again.'
        : 'Hide $sender from your view? This is mutual—they won\'t see you either.';

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$action $sender'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (isBlocked) {
                await _squadState.unblockUser(sender);
              } else {
                await _squadState.blockUser(sender);
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
