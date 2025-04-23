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
import '../../app_theme.dart';
import '../squad_state.dart';
import 'chat_input_bar.dart';
import 'chat_service.dart';
import 'chat_settings_menu.dart';
import 'chat_state.dart';
import 'message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String? initialMessage;
  const ChatScreen({super.key, this.initialMessage});

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
  late SquadState _squadState;
  bool _showJumpToBottom = false;
  bool _isMuted = false;
  // Mutable due to updates in _loadMoreMessages
  List<Map<String, dynamic>> _historicalMessages = [];
  int _offset = 0;
  final int _limit = 50;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _squadState = Provider.of<SquadState>(context, listen: false);
    _updateOnlineStatus(true);
    _loadChatDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _squadState.addListener(_updateTyping);
    _scrollController.addListener(_scrollListener);
    _checkHandoffDraft();
    Provider.of<ChatState>(context, listen: false).loadQuickReactionEmoji();
    if (widget.initialMessage != null && mounted) {
      _messageController.text = widget.initialMessage!;
      _sendMessage();
    }
    _loadNotificationSettings();
    _loadMoreMessages();
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
    _saveDraftForHandoff();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset > 100 && !_showJumpToBottom) {
      setState(() => _showJumpToBottom = true);
    } else if (_scrollController.offset <= 100 && _showJumpToBottom) {
      setState(() => _showJumpToBottom = false);
    }
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading) {
      _loadMoreMessages();
    }
  }

  void _updateTyping() {
    if (mounted) {
      String? typingUser = _squadState.getTypingUser();
      String? myName = _squadState.displayName;
      Provider.of<ChatState>(context, listen: false).setTypingUser(
        typingUser != null && typingUser != myName ? typingUser : null,
      );
    }
  }

  void _updateOnlineStatus(bool isOnline) {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      String? displayName = _squadState.displayName;
      _firestore.collection('users').doc(uid).set({
        'displayName': displayName ?? 'User',
        'profileImage': _squadState.profileImage,
        'lastOnline': FieldValue.serverTimestamp(),
        'online': isOnline,
      }, SetOptions(merge: true));
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

  Future<void> _loadMoreMessages() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final newMessages = await _chatService.loadMoreMessages(
        offset: _offset,
        limit: _limit,
      );
      if (mounted) {
        setState(() {
          _historicalMessages.addAll(newMessages);
          _offset += _limit;
        });
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      // Load from SQLite cache
      final cachedMessages =
          await _chatService.getCachedMessages(_offset, _limit);
      if (mounted) {
        setState(() {
          _historicalMessages.addAll(cachedMessages);
          _offset += _limit;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    final chatState = Provider.of<ChatState>(context, listen: false);
    String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    chatState.updateSendingStatus(tempId, true);

    try {
      String? sender =
          _auth.currentUser!.displayName ?? _squadState.displayName ?? 'User';
      await _chatService.sendMessage(
        sender: sender,
        text: _messageController.text,
      );
      chatState.removeSendingStatus(tempId);
      _messageController.clear();
      await _chatService.updateTypingStatus(context, sender, false);
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
      String sender =
          _auth.currentUser!.displayName ?? _squadState.displayName ?? 'User';
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$sender.${isVideo ? 'mp4' : 'jpg'}';
      String downloadUrl =
          await _chatService.uploadMedia(file, fileName, isVideo);
      final timestampMs = DateTime.now().millisecondsSinceEpoch;
      await _chatService.sendMessage(
        sender: sender,
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
      String sender =
          _auth.currentUser!.displayName ?? _squadState.displayName ?? 'User';
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_$sender.m4a';
      String downloadUrl = await _chatService.uploadAudio(file, fileName);
      final timestampMs = DateTime.now().millisecondsSinceEpoch;
      await _chatService.sendMessage(
        sender: sender,
        text: '',
        audio: [
          {'uri': downloadUrl, 'creation_timestamp': timestampMs}
        ],
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
      String? sender =
          _auth.currentUser!.displayName ?? _squadState.displayName ?? 'User';
      await _chatService.sendMessage(
        sender: sender,
        text: 'Forwarded: $messageText',
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
    final data = message is DocumentSnapshot
        ? message.data() as Map<String, dynamic>?
        : message as Map<String, dynamic>?;
    if (data == null) return;

    // Handle both Firestore (timestamp) and PostgreSQL (timestamp_ms) formats
    int timestampMillis;
    if (data['timestamp_ms'] != null) {
      timestampMillis = data['timestamp_ms'] as int;
    } else if (data['timestamp'] is Timestamp) {
      timestampMillis = (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
    } else {
      timestampMillis = DateTime.now().millisecondsSinceEpoch; // Fallback
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
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
          context, _squadState.displayName ?? 'User', true);
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
      String? uid = _auth.currentUser?.uid;
      if (uid != null) {
        await _firestore.collection('users').doc(uid).update({
          'group': FieldValue.delete(),
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the group')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to leave group: $e')),
        );
      }
    }
  }

  void _showPlusMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
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

  // Helper function to safely get sender from a message
  String? _getSender(dynamic message) {
    if (message is DocumentSnapshot) {
      final data = message.data() as Map<String, dynamic>?;
      return data?['sender'] as String?;
    } else if (message is Map<String, dynamic>) {
      return message['sender'] as String?;
    }
    return null;
  }

  // Helper function to safely get timestamp_ms from a message
  int? _getTimestampMs(dynamic message) {
    if (message is DocumentSnapshot) {
      final data = message.data() as Map<String, dynamic>?;
      if (data == null) return null;
      if (data['timestamp_ms'] != null) {
        return data['timestamp_ms'] as int?;
      } else if (data['timestamp'] is Timestamp) {
        return (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
      }
    } else if (message is Map<String, dynamic>) {
      return message['timestamp_ms'] as int?;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Scaffold(
        body: Consumer<ChatState>(
          builder: (context, chatState, _) {
            // Get the keyboard height
            final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
            // Use a small padding when keyboard is closed
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(
                                                        'Failed to update chat name: $e')));
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
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text('Chat cleared')));
                                        } catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(
                                                      'Failed to clear chat: $e')));
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
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: AppTheme.textColor),
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
                            stream: _chatService.getChatMessages(),
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
                              // Combine Firestore and historical messages
                              List<dynamic> allMessages = [];
                              if (snapshot.hasData) {
                                allMessages.addAll(snapshot.data!.docs);
                              }
                              allMessages.addAll(_historicalMessages);

                              if (allMessages.isEmpty) {
                                return const Center(
                                    child: Text('No messages yet'));
                              }

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
                                itemCount:
                                    allMessages.length + (_isLoading ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == allMessages.length &&
                                      _isLoading) {
                                    return const Center(
                                        child: CircularProgressIndicator());
                                  }
                                  var message = allMessages[index];
                                  final data = message is DocumentSnapshot
                                      ? message.data() as Map<String, dynamic>?
                                      : message as Map<String, dynamic>;
                                  if (data == null) {
                                    return const SizedBox.shrink();
                                  }
                                  String? myName = _squadState.displayName;
                                  bool isMe = data['sender'] ==
                                      (_auth.currentUser!.displayName ??
                                          myName ??
                                          'User');
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
                                      lastReadBy[data['sender'] ?? '']
                                              ?.contains(
                                                  _auth.currentUser!.uid) ==
                                          true;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    child: MessageBubble(
                                      message: message,
                                      isMe: isMe,
                                      showSender: showSender,
                                      showAvatar: showAvatar,
                                      showTimestamp: showTimestamp,
                                      showReadIndicator: showReadIndicator,
                                      onTap: () => _showMessageDetails(message),
                                      onLongPress: () =>
                                          _forwardMessage(data['text'] ?? ''),
                                      sendingStatus: chatState.sendingStatus,
                                    ),
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
                                    context, sender, value.isNotEmpty);
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
}
