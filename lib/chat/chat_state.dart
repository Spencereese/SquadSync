import 'package:flutter/material.dart';

/// Manages the state of a chat interface with typing, recording, and message sending status.
class ChatState extends ChangeNotifier {
  // Private state variables
  String? _typingUser;
  bool _isRecording = false;
  bool _isUploading = false;
  final Map<String, bool> _sendingStatus = {};

  // Public getters
  String? get typingUser => _typingUser;
  bool get isRecording => _isRecording;
  bool get isUploading => _isUploading;
  Map<String, bool> get sendingStatus => Map.unmodifiable(_sendingStatus);
  bool get hasPendingMessages => _sendingStatus.isNotEmpty;

  /// Sets the currently typing user and notifies listeners.
  /// [user] can be null to indicate no one is typing.
  void setTypingUser(String? user) {
    if (_typingUser != user) {
      _typingUser = user;
      notifyListeners();
    }
  }

  /// Updates recording state and notifies listeners.
  /// [value] indicates whether recording is active.
  void setRecording(bool value) {
    if (_isRecording != value) {
      _isRecording = value;
      notifyListeners();
    }
  }

  /// Updates uploading state and notifies listeners.
  /// [value] indicates whether uploading is in progress.
  void setUploading(bool value) {
    if (_isUploading != value) {
      _isUploading = value;
      notifyListeners();
    }
  }

  /// Updates the sending status for a message with given [tempId].
  /// [isSending] indicates whether the message is currently sending.
  /// Throws [ArgumentError] if tempId is empty or null.
  void updateSendingStatus(String tempId, bool isSending) {
    _validateTempId(tempId);

    if (isSending) {
      _sendingStatus[tempId] = true;
    } else {
      _sendingStatus.remove(tempId);
    }
    notifyListeners();
  }

  /// Removes sending status for a specific message.
  /// [tempId] is the temporary identifier of the message to remove.
  /// Throws [ArgumentError] if tempId is empty or null.
  void removeSendingStatus(String tempId) {
    _validateTempId(tempId);
    if (_sendingStatus.remove(tempId) != null) {
      notifyListeners();
    }
  }

  /// Checks if a specific message is in sending state.
  /// Returns false if the message ID doesn't exist.
  bool isMessageSending(String tempId) {
    _validateTempId(tempId);
    return _sendingStatus[tempId] ?? false;
  }

  /// Clears all sending status entries.
  void clearSendingStatus() {
    if (_sendingStatus.isNotEmpty) {
      _sendingStatus.clear();
      notifyListeners();
    }
  }

  /// Resets all chat state to initial values.
  void reset() {
    _typingUser = null;
    _isRecording = false;
    _isUploading = false;
    _sendingStatus.clear();
    notifyListeners();
  }

  // Private validation helper
  void _validateTempId(String tempId) {
    if (tempId.isEmpty) {
      throw ArgumentError('tempId cannot be empty');
    }
  }

  @override
  void dispose() {
    _sendingStatus.clear();
    super.dispose();
  }
}
