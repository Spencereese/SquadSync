import 'package:flutter/material.dart';
import 'dart:async';
import '../../squad_state.dart';

/// Service responsible for message processing, caching, and display name resolution
class ChatMessageProcessor {
  // Cache for user display names to avoid FutureBuilder in ListView
  final Map<String, String> _userDisplayNameCache = {};
  bool _isLoadingUserNames = false;

  // Cache for processed messages to avoid expensive operations in build
  List<dynamic> _processedMessages = [];
  final Map<String, List<String>> _lastReadByCache = {};
  bool _needsMessageProcessing = true;

  // Getters for external access
  Map<String, String> get userDisplayNameCache => _userDisplayNameCache;
  List<dynamic> get processedMessages => _processedMessages;
  Map<String, List<String>> get lastReadByCache => _lastReadByCache;
  bool get needsMessageProcessing => _needsMessageProcessing;

  /// Load user display names for better performance
  Future<void> loadUserDisplayNames(BuildContext context) async {
    if (_isLoadingUserNames) return;
    _isLoadingUserNames = true;

    try {
      // Implementation for pre-loading user display names
      // This improves performance by avoiding FutureBuilder in the message list
      // TODO: Implement actual display name loading from Firestore
    } catch (e) {
      debugPrint('Error loading user display names: $e');
    } finally {
      _isLoadingUserNames = false;
    }
  }

  /// Process messages for display (filtering, deduplication, etc.)
  void processMessages(List<dynamic> messages) {
    if (!_needsMessageProcessing) return;

    // Implementation for message processing
    // This would handle filtering, deduplication, and caching
    _processedMessages = messages;
    _needsMessageProcessing = false;
  }

  /// Get display name for a user UID with caching
  String getDisplayNameForUid(String uid, SquadState squadState) {
    if (_userDisplayNameCache.containsKey(uid)) {
      return _userDisplayNameCache[uid]!;
    }

    // Fallback to squad state display name resolution
    final displayName = squadState.getDisplayNameForUid(uid);
    return displayName.isNotEmpty ? displayName : 'Unknown User';
  }

  /// Mark messages as needing reprocessing
  void markNeedsProcessing() {
    _needsMessageProcessing = true;
  }

  /// Clear caches when switching chats
  void clearCaches() {
    _userDisplayNameCache.clear();
    _processedMessages.clear();
    _lastReadByCache.clear();
    _needsMessageProcessing = true;
  }
}
