import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart' as record_package;
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'chat_service.dart';
import 'chat_state.dart';
import 'message_bubble.dart';
import 'chat_input_bar.dart';
import '../../app_theme.dart';
import '../squad_state.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
  }

  @override
  void dispose() {
    _updateOnlineStatus(false);
    _scrollController.dispose();
    _messageController.dispose();
    _animationController.dispose();
    _audioRecorder.dispose();
    _squadState.removeListener(_updateTyping);
    super.dispose();
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
        'profileImage': _squadState.profileImage, // Sync profile image
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
    final doc =
        await _firestore.collection('chat_metadata').doc('chat_config').get();
    if (doc.exists && mounted) {
      setState(() {
        _chatName = doc.data()?['name'] ?? 'Squad Chat';
        _chatImageUrl = doc.data()?['imageUrl'];
      });
    }
  }

  Future<void> _changeChatName(String newName) async {
    if (mounted) {
      await _firestore.collection('chat_metadata').doc('chat_config').set({
        'name': newName,
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      setState(() {
        _chatName = newName;
      });
    }
  }

  Future<void> _uploadChatImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      try {
        File file = File(image.path);
        String fileName =
            'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference ref =
            FirebaseStorage.instance.ref().child('chat_images/$fileName');
        UploadTask uploadTask = ref.putFile(file);
        final snapshot = await uploadTask.whenComplete(() {});
        String downloadUrl = await snapshot.ref.getDownloadURL();
        await _firestore.collection('chat_metadata').doc('chat_config').set({
          'imageUrl': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        if (mounted) {
          setState(() {
            _chatImageUrl = downloadUrl;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e')),
          );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Media upload failed: $e')),
        );
        chatState.setUploading(false);
      }
    }
  }

  Future<void> _startRecording() async {
    final chatState = Provider.of<ChatState>(context, listen: false);
    if (await _audioRecorder.hasPermission()) {
      final directory = Directory.systemTemp;
      final path =
          '${directory.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const record_package.RecordConfig(),
          path: path);
      chatState.setRecording(true);
      _animationController.repeat();
    }
  }

  Future<void> _stopRecording() async {
    final chatState = Provider.of<ChatState>(context, listen: false);
    String? path = await _audioRecorder.stop();
    _animationController.stop();
    chatState.setRecording(false);
    if (path != null) {
      _audioPath = path;
      if (mounted) await _uploadAudio();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio upload failed: $e')),
        );
        chatState.setUploading(false);
      }
    }
  }

  void showChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Image.asset('assets/images/info_icon.png',
                width: 24, height: 24),
            title: const Text('View Group Info'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Image.asset('assets/images/notifications_off_icon.png',
                width: 24, height: 24),
            title: const Text('Mute Notifications'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Image.asset('assets/images/delete_sweep_icon.png',
                width: 24, height: 24),
            title: const Text('Clear Chat',
                style: TextStyle(color: AppTheme.errorColor)),
            onTap: () {
              Navigator.pop(context);
              _clearChat();
            },
          ),
          ListTile(
            leading: Image.asset('assets/images/exit_icon.png',
                width: 24, height: 24),
            title: const Text('Leave Group',
                style: TextStyle(color: AppTheme.errorColor)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Image.asset('assets/images/search_icon.png',
                width: 24, height: 24),
            title: const Text('Search Messages'),
            onTap: () {
              Navigator.pop(context);
              showSearchBar();
            },
          ),
          ListTile(
            leading: Image.asset('assets/images/search_icon.png',
                width: 24, height: 24),
            title: const Text('Change Chat Name'),
            onTap: () {
              Navigator.pop(context);
              _showChangeChatNameDialog();
            },
          ),
          ListTile(
            leading: Image.asset('assets/images/image_icon.png',
                width: 24, height: 24),
            title: const Text('Change Chat Image'),
            onTap: () {
              Navigator.pop(context);
              _uploadChatImage();
            },
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    _firestore.collection('chat').get().then((snapshot) {
      for (var doc in snapshot.docs) {
        doc.reference.delete();
      }
    });
  }

  void showSearchBar() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search messages...',
                hintStyle: TextStyle(color: AppTheme.hintColor),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chat')
                    .orderBy('timestamp', descending: true)
                    .where('text', isGreaterThanOrEqualTo: _searchQuery)
                    .where('text', isLessThan: '$_searchQuery\uf8ff')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                        child: Text('Error loading search results'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var messages = snapshot.data!.docs;
                  if (messages.isEmpty) {
                    return const Center(child: Text('No results found'));
                  }
                  return ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      var message = messages[index];
                      Map<String, dynamic> data =
                          message.data() as Map<String, dynamic>;
                      return ListTile(
                        title: Text(data['text'] ?? ''),
                        subtitle: Text(
                          "${message['sender']} - ${DateFormat('MMM d, yyyy, HH:mm').format((message['timestamp'] as Timestamp).toDate())}",
                          style: const TextStyle(color: AppTheme.hintColor),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeChatNameDialog() {
    final TextEditingController nameController =
        TextEditingController(text: _chatName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Change Chat Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
              hintText: 'Enter new chat name...',
              hintStyle: TextStyle(color: AppTheme.hintColor)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.hintColor))),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _changeChatName(nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save',
                style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }

  void _showMessageDetails(DocumentSnapshot message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Message Details'),
        content: Text(
            'Sent: ${DateFormat('MMM d, yyyy, HH:mm:ss').format((message['timestamp'] as Timestamp).toDate())}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK',
                  style: TextStyle(color: AppTheme.accentColor))),
        ],
      ),
    );
  }

  void _showMessageOptions(
      BuildContext context, String docId, String currentText, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        List<Widget> menuItems = [
          ListTile(
            leading: Image.asset('assets/images/copy_icon.png',
                width: 24, height: 24),
            title: const Text('Copy'),
            onTap: () async {
              if (mounted) {
                await Clipboard.setData(ClipboardData(text: currentText));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')));
              }
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Image.asset('assets/images/forward_icon.png',
                width: 24, height: 24),
            title: const Text('Forward'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Image.asset('assets/images/delete_icon.png',
                width: 24, height: 24),
            title: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
            onTap: () {
              Navigator.pop(context);
              _showDeleteDialog(context, docId);
            },
          ),
          ListTile(
            leading: Image.asset('assets/images/emoji_icon.png',
                width: 24, height: 24),
            title: const Text('React'),
            onTap: () {
              Navigator.pop(context);
              _showReactionPicker(context, docId);
            },
          ),
        ];

        if (isMe) {
          menuItems.insert(
            0,
            ListTile(
              leading: Image.asset('assets/images/edit_icon.png',
                  width: 24, height: 24),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, docId, currentText);
              },
            ),
          );
        }

        return Column(mainAxisSize: MainAxisSize.min, children: menuItems);
      },
    );
  }

  void _showReactionPicker(BuildContext context, String docId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Wrap(
        children: ['👍', '❤️', '😂', '😮', '😢', '😡'].map((emoji) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                _addReaction(docId, emoji);
                Navigator.pop(context);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _addReaction(String docId, String emoji) async {
    final user =
        _auth.currentUser!.displayName ?? _squadState.displayName ?? 'User';
    final querySnapshot = await _firestore
        .collection('chat')
        .doc(docId)
        .collection('reactions')
        .where('user', isEqualTo: user)
        .get();
    for (var doc in querySnapshot.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('chat').doc(docId).collection('reactions').add({
      'emoji': emoji,
      'user': user,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _showEditDialog(BuildContext context, String docId, String currentText) {
    TextEditingController editController =
        TextEditingController(text: currentText);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
              hintText: 'Edit your message...',
              hintStyle: TextStyle(color: AppTheme.hintColor)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.hintColor))),
          TextButton(
            onPressed: () {
              _editMessage(docId, editController.text);
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(color: AppTheme.accentColor)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(color: AppTheme.hintColor))),
          TextButton(
            onPressed: () {
              _deleteMessage(docId);
              Navigator.pop(context);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  void _editMessage(String docId, String newText) {
    _firestore
        .collection('chat')
        .doc(docId)
        .update({'text': newText, 'edited': true});
  }

  void _deleteMessage(String docId) {
    _firestore.collection('chat').doc(docId).delete();
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
            builder: (context, chatState, _) => Column(
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
                          onTap: showChatOptions,
                          child: Row(
                            children: [
                              if (_chatImageUrl != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
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
                                    color: AppTheme.accentColor),
                              ),
                            ],
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
                            return Text(
                              'Online: $onlineCount',
                              style: const TextStyle(
                                  fontSize: 14, color: AppTheme.textColor),
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
                      stream: _chatService.getChatMessages(),
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
                          return const Center(child: Text('No messages yet'));
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
                                (messages[index - 1]['timestamp'] as Timestamp)
                                        .toDate()
                                        .difference(
                                            (message['timestamp'] as Timestamp)
                                                .toDate())
                                        .inMinutes >
                                    30;
                            bool showReadIndicator = !isMe &&
                                lastReadBy[message['sender']]
                                        ?.contains(_auth.currentUser!.uid) ==
                                    true;

                            return MessageBubble(
                              message: message,
                              isMe: isMe,
                              showSender: showSender,
                              showAvatar: showAvatar,
                              showTimestamp: showTimestamp,
                              showReadIndicator: showReadIndicator,
                              onTap: () => _showMessageDetails(message),
                              onLongPress: () => _showMessageOptions(
                                context,
                                message.id,
                                (message.data()
                                        as Map<String, dynamic>)['text'] ??
                                    '',
                                isMe,
                              ),
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
                        Text('${chatState.typingUser} is typing',
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                        const SizedBox(width: 8),
                        Animate(
                          effects: const [
                            FadeEffect(duration: Duration(milliseconds: 500)),
                            ScaleEffect(
                                begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0)),
                          ],
                          child: const Text('...'),
                        ),
                      ],
                    ),
                  ),
                ChatInputBar(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPlusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
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
        ],
      ),
    );
  }
}
