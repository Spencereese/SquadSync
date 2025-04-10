import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart' as record_package;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'chat_service.dart';
import 'chat_state.dart';
import 'chat_input_bar.dart';
import '../squad_state.dart';
import 'message_list.dart';
import 'chat_modals.dart';
import '../../app_theme.dart';

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
  final ChatService _chatService = ChatService();
  late AnimationController _animationController;
  String? _audioPath;
  String _chatName = 'Squad Chat';
  String? _chatImageUrl;
  bool _showJumpToBottom = false;
  int _messageLimit = 20;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _updateOnlineStatus(true);
    _loadChatDetails();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    Provider.of<SquadState>(context, listen: false).addListener(_updateTyping);
    _scrollController.addListener(_scrollListener);
    _checkHandoffDraft();
    if (widget.initialMessage != null && mounted) {
      _messageController.text = widget.initialMessage!;
      _sendMessage();
    }
  }

  @override
  void dispose() {
    _updateOnlineStatus(false);
    _scrollController.dispose();
    _messageController.dispose();
    _animationController.dispose();
    _audioRecorder.dispose();
    Provider.of<SquadState>(context, listen: false)
        .removeListener(_updateTyping);
    _saveDraftForHandoff();
    super.dispose();
  }

  void _scrollListener() {
    setState(() {
      _showJumpToBottom = _scrollController.offset > 100;
    });
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        mounted) {
      setState(() => _messageLimit += 20);
    }
  }

  void _updateTyping() {
    if (mounted) {
      String? typingUser =
          Provider.of<SquadState>(context, listen: false).getTypingUser();
      String? myName =
          Provider.of<SquadState>(context, listen: false).displayName;
      Provider.of<ChatState>(context, listen: false).setTypingUser(
          typingUser != null && typingUser != myName ? typingUser : null);
    }
  }

  void _updateOnlineStatus(bool isOnline) {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      String? displayName =
          Provider.of<SquadState>(context, listen: false).displayName;
      _firestore.collection('users').doc(uid).set({
        'displayName': displayName ?? 'User',
        'profileImage':
            Provider.of<SquadState>(context, listen: false).profileImage,
        'lastOnline': FieldValue.serverTimestamp(),
        'online': isOnline,
      }, SetOptions(merge: true));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
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

  Future<void> _changeChatName(String newName) async {
    try {
      await _firestore.collection('chat_metadata').doc('chat_config').set({
        'name': newName,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() => _chatName = newName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update chat name: $e')));
      }
    }
  }

  Future<void> _uploadChatImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      try {
        File file = File(image.path);
        String fileName =
            'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String downloadUrl =
            await _chatService.uploadMedia(file, fileName, false);
        await _firestore.collection('chat_metadata').doc('chat_config').set({
          'imageUrl': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          setState(() => _chatImageUrl = downloadUrl);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Image upload failed: $e')));
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    final chatState = Provider.of<ChatState>(context, listen: false);
    String tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    chatState.updateSendingStatus(tempId, true);
    try {
      String? sender = _auth.currentUser!.displayName ??
          Provider.of<SquadState>(context, listen: false).displayName ??
          'User';
      final replyData =
          chatState.replyToMessage?.data() as Map<String, dynamic>?;
      await _chatService.sendMessage(
        sender: sender,
        text: _messageController.text,
        replyToMessageId: chatState.replyToMessage?.id,
        replyToContent: replyData?['text'],
      );
      chatState.removeSendingStatus(tempId);
      _messageController.clear();
      await _chatService.updateTypingStatus(context, sender, false);
      chatState.setReplyToMessage(null);
      _scrollToBottom();
      await _checkFirstMessage();
    } catch (e) {
      chatState.updateSendingStatus(tempId, false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
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
      String sender = _auth.currentUser!.displayName ??
          Provider.of<SquadState>(context, listen: false).displayName ??
          'User';
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_$sender.${isVideo ? 'mp4' : 'jpg'}';
      String downloadUrl =
          await _chatService.uploadMedia(file, fileName, isVideo);
      await _chatService.sendMessage(
          sender: sender,
          text: '',
          videoUrl: isVideo ? downloadUrl : null,
          imageUrl: !isVideo ? downloadUrl : null);
      chatState.setUploading(false);
    } catch (e) {
      chatState.setUploading(false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Media upload failed: $e')));
      }
    }
  }

  Future<void> _startRecording() async {
    final chatState = Provider.of<ChatState>(context, listen: false);
    if (await _audioRecorder.hasPermission()) {
      try {
        final path =
            '${Directory.systemTemp.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const record_package.RecordConfig(),
            path: path);
        chatState.setRecording(true);
        _animationController.repeat();
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
      String sender = _auth.currentUser!.displayName ??
          Provider.of<SquadState>(context, listen: false).displayName ??
          'User';
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_$sender.m4a';
      String downloadUrl = await _chatService.uploadAudio(file, fileName);
      await _chatService.sendMessage(
          sender: sender, text: '', audioUrl: downloadUrl);
      chatState.setUploading(false);
      _audioPath = null;
    } catch (e) {
      chatState.setUploading(false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Audio upload failed: $e')));
      }
    }
  }

  void _clearChat() {
    try {
      _firestore.collection('chat').get().then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Chat cleared')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to clear chat: $e')));
      }
    }
  }

  Future<void> _checkFirstMessage() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('first_message_sent')) {
      await prefs.setBool('first_message_sent', true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🎉 First message sent!')));
      }
    }
  }

  Future<void> _checkHandoffDraft() async {
    final prefs = await SharedPreferences.getInstance();
    String? draft = prefs.getString('chat_draft');
    if (draft != null && mounted) {
      _messageController.text = draft;
      await _chatService.updateTypingStatus(
          context,
          Provider.of<SquadState>(context, listen: false).displayName ?? 'User',
          true);
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.black, Colors.indigo])),
          child: Consumer<ChatState>(
            builder: (context, chatState, _) => Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => ChatModals.showChatOptions(
                                context,
                                _clearChat,
                                () => ChatModals.showChangeChatNameDialog(
                                    context, _chatName, _changeChatName),
                                _uploadChatImage),
                            child: Semantics(
                              label: 'Chat options',
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Builder(
                                      builder: (context) {
                                        try {
                                          if (_chatImageUrl != null &&
                                              _chatImageUrl!.isNotEmpty &&
                                              Uri.parse(_chatImageUrl!)
                                                  .isAbsolute) {
                                            return CircleAvatar(
                                              radius: 20,
                                              backgroundImage:
                                                  NetworkImage(_chatImageUrl!),
                                              onBackgroundImageError:
                                                  (exception, stackTrace) {
                                                debugPrint(
                                                    'Error loading chat image: $_chatImageUrl, $exception');
                                              },
                                            );
                                          }
                                          return CircleAvatar(
                                            radius: 20,
                                            child: Icon(Icons.group,
                                                color: Colors.cyanAccent),
                                          );
                                        } catch (e) {
                                          debugPrint(
                                              'Error rendering chat image: $e');
                                          return CircleAvatar(
                                            radius: 20,
                                            child: Icon(Icons.group,
                                                color: Colors.cyanAccent),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  Text(_chatName,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.accentColor)),
                                ],
                              ),
                            ),
                          ),
                          Consumer<SquadState>(
                            builder: (context, squadState, _) => Semantics(
                              label:
                                  '${squadState.statuses.values.where((status) => [
                                        'Strutting',
                                        'Walking',
                                        'Ready'
                                      ].contains(status)).length} members online',
                              child: Text(
                                'Online: ${squadState.statuses.values.where((status) => [
                                      'Strutting',
                                      'Walking',
                                      'Ready'
                                    ].contains(status)).length}',
                                style: const TextStyle(
                                    fontSize: 14, color: AppTheme.textColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.only(bottom: 60),
                            child: MessageList(
                                scrollController: _scrollController,
                                messageLimit: _messageLimit,
                                chatService: _chatService,
                                onScrollToBottom: _scrollToBottom))),
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
                                        fontStyle: FontStyle.italic))),
                            const SizedBox(width: 8),
                            Semantics(
                                label: 'Typing indicator',
                                child: const Text('...')),
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
                        onPlusMenu: () =>
                            ChatModals.showPlusMenu(context, _sendMedia),
                        onTextChanged: (value) =>
                            _chatService.updateTypingStatus(
                                context,
                                Provider.of<SquadState>(context, listen: false)
                                        .displayName ??
                                    'User',
                                value.isNotEmpty),
                        replyToMessage: chatState.replyToMessage,
                      ),
                    ),
                  ],
                ),
                if (_showJumpToBottom)
                  Positioned(
                    bottom: 80,
                    right: 16,
                    child: FloatingActionButton(
                      mini: true,
                      onPressed: _scrollToBottom,
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
}
