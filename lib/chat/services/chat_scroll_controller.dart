import 'package:flutter/material.dart';
import '../../services/message_service.dart';

/// Service responsible for scroll management and message pagination
class ChatScrollController {
  final ScrollController scrollController = ScrollController();
  final MessageService _chatService = MessageService();

  // Pagination state
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _listenerReady = false;
  int _currentOffset = 0;
  static const int _messagesPerPage = 50;

  // UI state
  bool _showJumpToBottom = false;
  final List<Map<String, dynamic>> _historicalMessages = [];

  // Getters for external access
  bool get showJumpToBottom => _showJumpToBottom;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreMessages => _hasMoreMessages;
  List<Map<String, dynamic>> get historicalMessages => _historicalMessages;

  /// Initialize scroll listeners
  void initialize({
    required VoidCallback onScrollChanged,
    required VoidCallback onLoadMoreMessages,
  }) {
    if (_listenerReady) return;
    _listenerReady = true;
    scrollController.addListener(() {
      _handleScroll(onScrollChanged, onLoadMoreMessages);
    });
  }

  void _handleScroll(
      VoidCallback onScrollChanged, VoidCallback onLoadMoreMessages) {
    // Show jump to bottom when scrolled up from bottom
    final distanceFromBottom =
        scrollController.position.maxScrollExtent - scrollController.offset;
    final shouldShow = distanceFromBottom > 100;
    if (shouldShow != _showJumpToBottom) {
      // Use Future.microtask to debounce setState calls
      Future.microtask(() {
        _showJumpToBottom = shouldShow;
        onScrollChanged();
      });
    }

    // Reversed list: offset 0 is the newest (bottom). Older history is
    // toward maxScrollExtent, so load when the user is near that edge.
    final distanceFromOlderEdge = scrollController.position.maxScrollExtent -
        scrollController.position.pixels;
    if (distanceFromOlderEdge <= 200 && !_isLoadingMore && _hasMoreMessages) {
      onLoadMoreMessages();
    }
  }

  void beginOlderPage() {
    _isLoadingMore = true;
  }

  void endOlderPage({required bool hasMore}) {
    _isLoadingMore = false;
    if (!hasMore) _hasMoreMessages = false;
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

  /// Scroll to bottom of chat (position 0 since ListView is reversed)
  void scrollToBottom() {
    try {
      if (scrollController.hasClients &&
          scrollController.position.hasContentDimensions) {
        scrollController.animateTo(
          0.0, // Position 0 is the bottom when reverse: true
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Scroll controller not ready yet, ignore
      debugPrint('Scroll controller not ready for scrollToBottom: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    scrollController.dispose();
  }
}
