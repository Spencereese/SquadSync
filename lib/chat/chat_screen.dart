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
import '../../app_theme.dart';
import '../squad_state.dart';
import 'chat_input_bar.dart';
import 'chat_service.dart';
import 'chat_settings_menu.dart';
import 'chat_state.dart';
import 'sqlite_helper.dart';
import 'message_bubble.dart';
import '../no_squad_screen.dart';

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
      _updateOnlineStatus(true);
      _loadChatDetails();
      _scrollToBottom();
      _checkHandoffDraft();
      Provider.of<ChatState>(context, listen: false).loadQuickReactionEmoji();
      if (widget.initialMessage != null && mounted) {
        _messageController.text = widget.initialMessage!;
        _sendMessage();
      }
      _loadNotificationSettings();
      // Clear cache and reset offset
      _sqliteHelper.clearMessages(chatGroupId: widget.chatGroupId);
      _historicalMessages.clear();
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
    if (_scrollController.offset > 100 && !_showJumpToBottom) {
      setState(() => _showJumpToBottom = true);
    } else if (_scrollController.offset <= 100 && _showJumpToBottom) {
      setState(() => _showJumpToBottom = false);
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
    try {
      if (widget.chatGroupId != null) {
        // Load group chat details
        final squadState = Provider.of<SquadState>(context, listen: false);
        final groupDoc = await _firestore
            .collection('squads')
            .doc(squadState.selectedSquadId)
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
    setState(() {
      _isMuted = !_isMuted;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_muted', _isMuted);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                _isMuted ? 'Notifications muted' : 'Notifications unmuted')),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    final chatState = Provider.of<ChatState>(context, listen: false);
    String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    chatState.updateSendingStatus(tempId, true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _chatService.sendMessage(context,
          senderUid: user.uid,
          text: _messageController.text,
          chatGroupId: widget.chatGroupId);
      chatState.removeSendingStatus(tempId);
      _messageController.clear();
      await _chatService.updateTypingStatus(
          context, _squadState.displayName ?? 'Anonymous', false,
          chatGroupId: widget.chatGroupId);
      _scrollToBottom();
      await _checkFirstMessage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
        chatState.updateSendingStatus(tempId, false);
      }
    }
  }

  Future<void> _sendMedia() async {
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
            leading: const Icon(Icons.file_present),
            title: const Text('Share a file'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Location'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.poll),
            title: const Text('Poll'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Photo/Video'),
            onTap: () {
              Navigator.pop(context);
              _sendMedia();
            },
          ),
        ],
      ),
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
                                            setState(() => _chatName = newName);
                                          } catch (e) {
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
                                          if (mounted) {
                                            setState(() =>
                                                _chatImageUrl = downloadUrl);
                                            HapticFeedback.lightImpact();
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Image upload failed: $e')));
                                          }
                                        }
                                      },
                                      onClearChat: () async {
                                        if (!mounted) return;
                                        try {
                                          final snapshot = await _firestore
                                              .collection('chat')
                                              .get();
                                          for (var doc in snapshot.docs) {
                                            await doc.reference.delete();
                                          }
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content:
                                                        Text('Chat cleared')));
                                          }
                                        } catch (e) {
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
                                      return Semantics(
                                        label: '$onlineCount members online',
                                        child: Text(
                                          'Online: $onlineCount',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors
                                                  .white), // Replaced AppTheme.textColor
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ).animate().fadeIn(),
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
                              List<dynamic> allMessages = [];
                              if (snapshot.hasData) {
                                allMessages.addAll(snapshot.data!.docs);
                              }
                              allMessages.addAll(_historicalMessages);

                              if (allMessages.isEmpty) {
                                return const Center(
                                    child: Text('No messages yet'));
                              }

// Deduplicate by ID
                              final seenIds = <String>{};
                              allMessages = allMessages.where((msg) {
                                final id = msg is DocumentSnapshot
                                    ? msg.id
                                    : msg['id']?.toString() ?? '';
                                if (seenIds.contains(id)) return false;
                                seenIds.add(id);
                                return true;
                              }).toList();

// Filter messages to only show from squad members (all messages in squad are from members)
                              final filteredMembers =
                                  _squadState.getFilteredMembers;
                              allMessages = allMessages.where((msg) {
                                final data = msg is DocumentSnapshot
                                    ? msg.data() as Map<String, dynamic>?
                                    : msg as Map<String, dynamic>;
                                if (data == null) return false;
                                final senderUid = data['senderUid'] ?? '';
                                final senderDisplayName =
                                    _squadState.getDisplayNameForUid(senderUid);
                                return filteredMembers
                                    .contains(senderDisplayName);
                              }).toList();

// Sort by timestamp_ms (newest first)
                              allMessages.sort((a, b) {
                                final aTs = _getTimestampMs(a) ?? 0;
                                final bTs = _getTimestampMs(b) ?? 0;
                                return bTs.compareTo(aTs);
                              });

// Cap live messages at 500 total
                              allMessages = allMessages.take(500).toList();
                              // debugPrint(
                              //     'Merged allMessages: ${allMessages.length} messages, IDs: ${seenIds.toList().take(10)}');

// Track read status
                              Map<String, List<String>> lastReadBy = {};
                              for (var message in allMessages) {
                                final data = message is DocumentSnapshot
                                    ? message.data() as Map<String, dynamic>?
                                    : message as Map<String, dynamic>;
                                if (data == null || data['read'] != true) {
                                  continue;
                                }
                                String sender = data['sender'] ?? '';
                                String uid = _auth.currentUser!.uid;
                                lastReadBy[sender] ??= [];
                                if (!lastReadBy[sender]!.contains(uid)) {
                                  lastReadBy[sender]!.add(uid);
                                }
                              }

                              return ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0, vertical: 4.0),
                                itemCount: allMessages.length,
                                itemBuilder: (context, index) {
                                  var message = allMessages[index];
                                  final data = message is DocumentSnapshot
                                      ? message.data() as Map<String, dynamic>?
                                      : message as Map<String, dynamic>;
                                  if (data == null) {
                                    // debugPrint(
                                    //     'Skipping null message at index $index');
                                    return const SizedBox.shrink();
                                  }
                                  // Clean garbled text
                                  if (data['content'] != null) {
                                    data['content'] =
                                        _cleanText(data['content']);
                                  }
                                  if (data['text'] != null) {
                                    data['text'] = _cleanText(data['text']);
                                  }
                                  // Clean reactions if present
                                  if (data['reactions'] is List) {
                                    final reactions = data['reactions'] as List;
                                    for (var reaction in reactions) {
                                      if (reaction is Map &&
                                          reaction['reaction'] != null) {
                                        reaction['reaction'] =
                                            _cleanText(reaction['reaction']);
                                      }
                                    }
                                  }
                                  // debugPrint(
                                  //     'Message data at index $index: $data');
                                  bool isMe = data['senderUid'] ==
                                      _auth.currentUser?.uid;
                                  if (!isMe && !(data['delivered'] ?? false)) {
                                    if (message is DocumentSnapshot) {
                                      _chatService.markAsDelivered(message.id);
                                    }
                                  }
                                  String? currentSender = _getSender(message);
                                  String? nextSender =
                                      index < allMessages.length - 1
                                          ? _getSender(allMessages[index + 1])
                                          : null;
                                  String? prevSender = index > 0
                                      ? _getSender(allMessages[index - 1])
                                      : null;
                                  bool showSender = !isMe &&
                                      (index == allMessages.length - 1 ||
                                          currentSender != nextSender);
                                  bool showAvatar = !isMe &&
                                      (index == 0 ||
                                          currentSender != prevSender);
                                  int? currentTimestamp =
                                      _getTimestampMs(message);
                                  int? prevTimestamp = index > 0
                                      ? _getTimestampMs(allMessages[index - 1])
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
                                      lastReadBy[data['senderUid'] ?? '']
                                              ?.contains(
                                                  _auth.currentUser!.uid) ==
                                          true;

                                  // debugPrint(
                                  //     'Rendering message at index $index: $data');
                                  return FutureBuilder<DocumentSnapshot>(
                                    future: _firestore
                                        .collection('users')
                                        .doc(data['senderUid'])
                                        .get(),
                                    builder: (context, userSnapshot) {
                                      final displayName =
                                          (userSnapshot.data?.data() as Map<
                                                  String,
                                                  dynamic>?)?['displayName'] ??
                                              'Unknown';
                                      final updatedData =
                                          Map<String, dynamic>.from(data);
                                      updatedData['sender'] = displayName;
                                      return GestureDetector(
                                        onLongPress: () => _showBlockDialog(
                                            context, displayName),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4.0),
                                          child: MessageBubble(
                                            message: updatedData,
                                            isMe: isMe,
                                            showSender: showSender,
                                            showAvatar: showAvatar,
                                            showTimestamp: showTimestamp,
                                            showReadIndicator:
                                                showReadIndicator,
                                            onTap: () =>
                                                _showMessageDetails(message),
                                            onLongPress: () => _forwardMessage(
                                                data['text'] ??
                                                    data['content'] ??
                                                    ''),
                                            sendingStatus:
                                                chatState.sendingStatus,
                                            chatGroupId: widget.chatGroupId,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
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
                        bottom: 80,
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
            onPressed: () {
              if (isBlocked) {
                _squadState.unblockUser(sender);
              } else {
                _squadState.blockUser(sender);
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
