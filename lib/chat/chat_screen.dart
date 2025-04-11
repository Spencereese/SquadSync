import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart' as record_package;
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'chat_service.dart';
import 'chat_state.dart';
import 'message_bubble.dart';
import 'chat_input_bar.dart';
import '../../app_theme.dart';
import '../squad_state.dart';
import 'chat_settings_menu.dart';

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
  int _messageLimit = 20;
  bool _isMuted = false;

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
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        mounted) {
      setState(() => _messageLimit += 20);
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
    if (!mounted) return;
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
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMuted = prefs.getBool('chat_muted') ?? false;
    });
  }

  Future<void> _toggleNotifications() async {
    if (!mounted) return;
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
      _checkFirstMessage();
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
      await _chatService.sendMessage(
        sender: sender,
        text: '',
        videoUrl: isVideo ? downloadUrl : null,
        imageUrl: !isVideo ? downloadUrl : null,
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
            const SnackBar(content: Text('Microphone permission denied')));
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
      await _chatService.sendMessage(
        sender: sender,
        text: '',
        audioUrl: downloadUrl,
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

  void _showMessageDetails(DocumentSnapshot message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Message Details'),
        content: Semantics(
          label:
              'Message sent at ${DateFormat('MMMM d, yyyy, HH:mm:ss').format((message['timestamp'] as Timestamp).toDate())}',
          child: Text(
            'Sent: ${DateFormat('MMM d, yyyy, HH:mm:ss').format((message['timestamp'] as Timestamp).toDate())}',
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
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.black, Colors.indigo],
            ),
          ),
          child: Consumer<ChatState>(
            builder: (context, chatState, _) => Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () => ChatSettingsMenu.showChatOptions(
                                context: context,
                                onSearchMessages: () =>
                                    ChatSettingsMenu.showSearchBar(
                                  context: context,
                                  firestore: _firestore,
                                  searchQuery: _searchQuery,
                                  onSearchQueryChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                ),
                                onChangeChatName: () =>
                                    ChatSettingsMenu.showChangeChatNameDialog(
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
                                      if (mounted) {
                                        setState(() => _chatName = newName);
                                      }
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
                                  final XFile? image = await _picker.pickImage(
                                      source: ImageSource.gallery);
                                  if (image != null && mounted) {
                                    try {
                                      File file = File(image.path);
                                      String fileName =
                                          'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                                      Reference ref = FirebaseStorage.instance
                                          .ref()
                                          .child('chat_images/$fileName');
                                      UploadTask uploadTask = ref.putFile(file);
                                      final snapshot =
                                          await uploadTask.whenComplete(() {});
                                      String downloadUrl =
                                          await snapshot.ref.getDownloadURL();
                                      await _firestore
                                          .collection('chat_metadata')
                                          .doc('chat_config')
                                          .set({
                                        'imageUrl': downloadUrl,
                                        'timestamp':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));
                                      if (mounted) {
                                        setState(
                                            () => _chatImageUrl = downloadUrl);
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
                                              content: Text('Chat cleared')));
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
                                    ChatSettingsMenu.showQuickReactionPicker(
                                  context: context,
                                  onEmojiSelected: (emoji) {
                                    Provider.of<ChatState>(context,
                                            listen: false)
                                        .setQuickReactionEmoji(emoji);
                                  },
                                ),
                                onToggleNotifications: _toggleNotifications,
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
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: CircleAvatar(
                                          radius: 20,
                                          backgroundImage:
                                              NetworkImage(_chatImageUrl!),
                                        ),
                                      )
                                    else
                                      const Padding(
                                        padding: EdgeInsets.only(right: 8.0),
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
                                int onlineCount = squadState.statuses.values
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
                      ).animate().fadeIn(),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _chatService
                              .getChatMessages()
                              .map((event) => event..docs.take(_messageLimit)),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(
                                  child: Text('Error loading chat'));
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            var messages = snapshot.data!.docs;
                            if (messages.isEmpty) {
                              return const Center(
                                  child: Text('No messages yet'));
                            }

                            Map<String, List<String>> lastReadBy = {};
                            for (var doc in messages) {
                              var data = doc.data() as Map<String, dynamic>;
                              if (data['read'] == true) {
                                String sender = data['sender'];
                                String uid = _auth.currentUser!.uid;
                                if (!lastReadBy.containsKey(sender)) {
                                  lastReadBy[sender] = [];
                                }
                                if (!lastReadBy[sender]!.contains(uid)) {
                                  lastReadBy[sender]!.add(uid);
                                }
                              }
                            }

                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                var message = messages[index];
                                String? myName = _squadState.displayName;
                                bool isMe = message['sender'] ==
                                    (_auth.currentUser!.displayName ??
                                        myName ??
                                        'User');
                                if (!isMe && !(message['delivered'] ?? false)) {
                                  _chatService.markAsDelivered(message.id);
                                }
                                bool showSender = !isMe &&
                                    (index == messages.length - 1 ||
                                        messages[index + 1]['sender'] !=
                                            message['sender']);
                                bool showAvatar = !isMe &&
                                    (index == 0 ||
                                        messages[index - 1]['sender'] !=
                                            message['sender']);
                                bool showTimestamp = index > 0 &&
                                    messages[index - 1]['timestamp'] != null &&
                                    message['timestamp'] != null &&
                                    (messages[index - 1]['timestamp']
                                                as Timestamp)
                                            .toDate()
                                            .difference((message['timestamp']
                                                    as Timestamp)
                                                .toDate())
                                            .inMinutes >
                                        30;
                                bool showReadIndicator = !isMe &&
                                    lastReadBy[message['sender']]?.contains(
                                            _auth.currentUser!.uid) ==
                                        true;

                                return MessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  showSender: showSender,
                                  showAvatar: showAvatar,
                                  showTimestamp: showTimestamp,
                                  showReadIndicator: showReadIndicator,
                                  onTap: () => _showMessageDetails(message),
                                  onLongPress:
                                      () {}, // Removed ChatSettingsMenu call
                                  sendingStatus: chatState.sendingStatus,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    if (chatState.typingUser != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            Semantics(
                              label: '${chatState.typingUser} is typing',
                              child: Text('${chatState.typingUser} is typing',
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic)),
                            ),
                            const SizedBox(width: 8),
                            Animate(
                              effects: const [
                                FadeEffect(
                                    duration: Duration(milliseconds: 500)),
                                ScaleEffect(
                                    begin: Offset(0.8, 0.8),
                                    end: Offset(1.0, 1.0)),
                              ],
                              child: Semantics(
                                label: 'Typing indicator',
                                child: const Text('...'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Semantics(
                      label: 'Chat input bar',
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
                          String? sender = _squadState.displayName ?? 'User';
                          _chatService.updateTypingStatus(
                              context, sender, value.isNotEmpty);
                        },
                        quickReactionEmoji: chatState.quickReactionEmoji,
                      ),
                    ),
                  ],
                ),
                if (_showJumpToBottom)
                  Positioned(
                    bottom: 80,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _scrollToBottom,
                      mini: true,
                      backgroundColor: AppTheme.accentColor,
                      tooltip: 'Jump to latest messages',
                      child: const Icon(Icons.arrow_downward),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
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
}
