import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatState extends ChangeNotifier {
  String? _typingUser;
  bool _isRecording = false;
  bool _isUploading = false;
  final Map<String, bool> _sendingStatus = {};
  String _quickReactionEmoji = '👍';

  String? get typingUser => _typingUser;
  bool get isRecording => _isRecording;
  bool get isUploading => _isUploading;
  Map<String, bool> get sendingStatus => Map.unmodifiable(_sendingStatus);
  bool get hasPendingMessages => _sendingStatus.isNotEmpty;
  String get quickReactionEmoji => _quickReactionEmoji;

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
    notifyListeners();
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

  void setDMView(bool isDMView) {
    // This method can be used to track DM view state
    // Implementation can be added as needed
  }

  @override
  void dispose() {
    _sendingStatus.clear();
    super.dispose();
  }
}
