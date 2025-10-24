import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatState extends ChangeNotifier {
  String? _typingUser;
  bool _isRecording = false;
  bool _isUploading = false;
  final Map<String, bool> _sendingStatus = {};
  String _quickReactionEmoji = '👍';
  Map<String, dynamic>? _replyToMessage;
  bool _isDMView = false; // New: DM view filter state
  int _dmUnreadCount = 0; // New: DM unread count

  String? get typingUser => _typingUser;
  bool get isRecording => _isRecording;
  bool get isUploading => _isUploading;
  Map<String, bool> get sendingStatus => Map.unmodifiable(_sendingStatus);
  bool get hasPendingMessages => _sendingStatus.isNotEmpty;
  String get quickReactionEmoji => _quickReactionEmoji;
  Map<String, dynamic>? get replyToMessage => _replyToMessage;
  bool get isDMView => _isDMView; // New getter
  int get dmUnreadCount => _dmUnreadCount; // New getter

  void setTypingUser(String? user) {
    if (_typingUser != user) {
      _typingUser = user;
      notifyListeners();
    }
  }

  void setRecording(bool value) {
    if (_isRecording != value) {
      _isRecording = value;
      notifyListeners();
    }
  }

  void toggleRecording() {
    _isRecording = !_isRecording;
    notifyListeners();
  }

  void setUploading(bool value) {
    if (_isUploading != value) {
      _isUploading = value;
      notifyListeners();
    }
  }

  void updateSendingStatus(String tempId, bool isSending) {
    try {
      _validateTempId(tempId);
      if (isSending) {
        _sendingStatus[tempId] = true;
      } else {
        _sendingStatus.remove(tempId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating sending status: $e');
    }
  }

  void removeSendingStatus(String tempId) {
    try {
      _validateTempId(tempId);
      if (_sendingStatus.remove(tempId) != null) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error removing sending status: $e');
    }
  }

  bool isMessageSending(String tempId) {
    try {
      _validateTempId(tempId);
      return _sendingStatus[tempId] ?? false;
    } catch (e) {
      debugPrint('Error checking sending status: $e');
      return false;
    }
  }

  void clearSendingStatus() {
    if (_sendingStatus.isNotEmpty) {
      _sendingStatus.clear();
      notifyListeners();
    }
  }

  void reset() {
    _typingUser = null;
    _isRecording = false;
    _isUploading = false;
    _sendingStatus.clear();
    _replyToMessage = null;
    _isDMView = false; // Reset DM view
    _dmUnreadCount = 0; // Reset DM unread count
    notifyListeners();
  }

  void setReplyToMessage(Map<String, dynamic>? message) {
    _replyToMessage = message;
    notifyListeners();
  }

  void clearReplyToMessage() {
    _replyToMessage = null;
    notifyListeners();
  }

  void setDMView(bool value) {
    // New method
    if (_isDMView != value) {
      _isDMView = value;
      notifyListeners();
    }
  }

  void setDMUnreadCount(int count) {
    // New method
    if (_dmUnreadCount != count) {
      _dmUnreadCount = count;
      notifyListeners();
    }
  }

  void _validateTempId(String tempId) {
    if (tempId.isEmpty || tempId.trim().isEmpty) {
      throw ArgumentError('tempId cannot be empty or null');
    }
  }

  Future<void> setQuickReactionEmoji(String emoji) async {
    try {
      _quickReactionEmoji = emoji;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quick_reaction_emoji', emoji);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting quick reaction emoji: $e');
    }
  }

  Future<void> loadQuickReactionEmoji() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _quickReactionEmoji = prefs.getString('quick_reaction_emoji') ?? '👍';
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading quick reaction emoji: $e');
    }
  }

  void toggleDMView() {
    _isDMView = !_isDMView;
    notifyListeners();
  }

  void incrementDMUnreadCount() {
    _dmUnreadCount++;
    notifyListeners();
  }

  void decrementDMUnreadCount() {
    _dmUnreadCount--;
    notifyListeners();
  }

  @override
  void dispose() {
    _sendingStatus.clear();
    super.dispose();
  }
}
