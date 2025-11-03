import 'package:flutter/material.dart';
import '../chat_service.dart';

/// Service responsible for scroll management and message pagination
class ChatScrollController {
  final ScrollController scrollController = ScrollController();
  final ChatService _chatService = ChatService();

  // Pagination state
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  int _currentOffset = 0;
  static const int _messagesPerPage = 50;

  // UI state
  bool _showJumpToBottom = false;
  final List<Map<String, dynamic>> _historicalMessages = [];

  // Getters for external access
  bool get showJumpToBottom => _showJumpToBottom;
  bool get isLoadingMore => _isLoadingMore;
  List<Map<String, dynamic>> get historicalMessages => _historicalMessages;

  /// Initialize scroll listeners
  void initialize({
    required VoidCallback onScrollChanged,
    required VoidCallback onLoadMoreMessages,
  }) {
    scrollController.addListener(() {
      _handleScroll(onScrollChanged, onLoadMoreMessages);
    });
  }

  void _handleScroll(
      VoidCallback onScrollChanged, VoidCallback onLoadMoreMessages) {
    final shouldShow = scrollController.offset > 100;
    if (shouldShow != _showJumpToBottom) {
      // Use Future.microtask to debounce setState calls
      Future.microtask(() {
        _showJumpToBottom = shouldShow;
        onScrollChanged();
      });
    }

    // Load more messages when scrolling near the top
    if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreMessages) {
      onLoadMoreMessages();
    }
  }

  /// Load more messages with pagination
  Future<void> loadMoreMessages({
    required String? chatGroupId,
    required VoidCallback onStateChanged,
  }) async {
    if (_isLoadingMore || !_hasMoreMessages) return;

    _isLoadingMore = true;
    onStateChanged();

    try {
      final moreMessages = await _chatService.loadMoreMessages(
        offset: _currentOffset,
        limit: _messagesPerPage,
        chatGroupId: chatGroupId,
      );

      if (moreMessages.isEmpty || moreMessages.length < _messagesPerPage) {
        _hasMoreMessages = false;
      }

      _historicalMessages.addAll(moreMessages);
      _currentOffset += moreMessages.length.toInt();
      _isLoadingMore = false;

      onStateChanged();
    } catch (e) {
      debugPrint('Failed to load more messages: $e');
      _isLoadingMore = false;
      onStateChanged();
    }
  }

  /// Scroll to bottom of chat
  void scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Dispose resources
  void dispose() {
    scrollController.dispose();
  }
}
