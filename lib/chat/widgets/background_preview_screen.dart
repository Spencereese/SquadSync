import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/chat_notifier.dart' as cn;
import '../../domain/entities/chat_state.dart' as cs;
import '../services/chat_ui_manager.dart';
import '../services/chat_scroll_controller.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../domain/entities/lobby_state.dart';
import '../../domain/entities/message.dart' show ChatType, Message;
import 'neon_chat_app_bar.dart';

/// Full-screen background preview with swipeable color options
/// Displays actual chat screen with messages, navigation dots,
/// and selection controls (checkmark/X)
class BackgroundPreviewScreen extends ConsumerStatefulWidget {
  final String? themeName;
  final List<Map<String, dynamic>> variations;
  final String squadId;
  final String chatName;
  final String? chatImageUrl;
  final ChatType chatType;
  final Function(String presetId) onApply;

  const BackgroundPreviewScreen({
    super.key,
    this.themeName,
    required this.variations,
    required this.squadId,
    required this.chatName,
    this.chatImageUrl,
    required this.chatType,
    required this.onApply,
  });

  @override
  ConsumerState<BackgroundPreviewScreen> createState() =>
      _BackgroundPreviewScreenState();
}

class _BackgroundPreviewScreenState
    extends ConsumerState<BackgroundPreviewScreen> {
  late PageController _pageController;
  late ChatUIManager _uiManager;
  late ChatScrollController _scrollControllerService;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _uiManager = ChatUIManager();
    _scrollControllerService = ChatScrollController();
    // Initialize with dummy callbacks since we're just using it for display
    _scrollControllerService.initialize(
      onScrollChanged: () {},
      onLoadMoreMessages: () {},
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollControllerService.scrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    HapticFeedback.selectionClick();
  }

  void _applyBackground() {
    final currentVariation = widget.variations[_currentPage];
    final presetId = currentVariation['id'] as String;
    HapticFeedback.mediumImpact();
    widget.onApply(presetId);
  }

  void _cancelPreview() {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  Color _getBackgroundColorFromVariation(Map<String, dynamic> variation) {
    final gradient = variation['gradient'] as LinearGradient?;
    if (gradient != null && gradient.colors.isNotEmpty) {
      return gradient.colors.first;
    }
    final color = variation['color'] as Color?;
    if (color != null) {
      return color;
    }
    return const Color(0xFF0B0E14);
  }

  @override
  Widget build(BuildContext context) {
    final currentVariation = widget.variations[_currentPage];
    final variationName =
        currentVariation['name'] as String? ?? widget.themeName ?? 'Background';

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: ref.watch(ln.lobbyNotifierProvider).when(
            data: (squadState) {
              return ref.watch(cn.chatNotifierProvider).when(
                    data: (chatState) {
                      final messages =
                          chatState.chatMessages[widget.squadId] ?? [];

                      return Stack(
                        children: [
                          // Background PageView
                          PageView.builder(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            itemCount: widget.variations.length,
                            itemBuilder: (context, index) {
                              final variation = widget.variations[index];
                              return _buildBackgroundLayer(variation);
                            },
                          ),

                          // Messages list (scrollable)
                          Positioned.fill(
                            child: _buildMessagesList(
                                context, messages, squadState, chatState),
                          ),

                          // App bar at top with blur
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: ClipRect(
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.15),
                                        Colors.black.withOpacity(0.05),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: NeonChatAppBar(
                                    squadId: widget.squadId,
                                    squadName: widget.chatName,
                                    avatarUrl: widget.chatImageUrl,
                                    backgroundColor:
                                        _getBackgroundColorFromVariation(
                                            currentVariation),
                                    onBackPressed: _cancelPreview,
                                    onCenterTapped:
                                        () {}, // Disabled in preview
                                    hideBackButton: true,
                                    hideVoiceButton: true,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Control buttons positioned at 25% and 75%
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 16,
                            left:
                                screenWidth * 0.25 - 24, // Center button at 25%
                            child: _buildControlButton(
                              icon: Icons.close,
                              onPressed: _cancelPreview,
                            ),
                          ),
                          Positioned(
                            top: MediaQuery.of(context).padding.top + 16,
                            left:
                                screenWidth * 0.75 - 24, // Center button at 75%
                            child: _buildControlButton(
                              icon: Icons.check,
                              onPressed: _applyBackground,
                            ),
                          ),

                          // Navigation controls at bottom
                          if (widget.variations.length > 1)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: _buildNavigationControls(
                                  context, variationName),
                            ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        Center(child: Text('Error loading messages: $error')),
                  );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) =>
                Center(child: Text('Error loading squad data: $error')),
          ),
    );
  }

  Widget _buildBackgroundLayer(Map<String, dynamic> variation) {
    final gradient = variation['gradient'] as LinearGradient?;
    final color = variation['color'] as Color?;
    final imageUrl = variation['imageUrl'] as String?;

    if (imageUrl != null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (gradient != null) {
      return Container(
        decoration: BoxDecoration(gradient: gradient),
      );
    } else if (color != null) {
      return Container(color: color);
    } else {
      return Container(color: const Color(0xFF0B0E14));
    }
  }

  Widget _buildMessagesList(
    BuildContext context,
    List<dynamic> messages,
    LobbyState squadState,
    cs.ChatState chatState,
  ) {
    // Convert dynamic messages to Message objects (they should already be Message type from chatNotifier)
    final messageList = messages.whereType<Message>().toList();

    return Padding(
      padding: EdgeInsets.only(
        top: 120 + MediaQuery.of(context).padding.top,
        bottom: widget.variations.length > 1 ? 100 : 20,
      ),
      child: _uiManager.buildMessagesList(
        ref: ref,
        chatGroupId: widget.squadId,
        chatType: widget.chatType,
        scrollController: _scrollControllerService,
        messages: messageList,
        onMessageLongPress: () {},
        onMessageTap: () {},
        getSender: (message) {
          if (message is Map<String, dynamic>) {
            return message['senderUid'] as String?;
          }
          return null;
        },
        getTimestampMs: (message) {
          if (message is Map<String, dynamic>) {
            if (message['timestamp_ms'] != null) {
              return message['timestamp_ms'] as int?;
            }
            if (message['timestamp'] is String) {
              return DateTime.parse(message['timestamp'])
                  .millisecondsSinceEpoch;
            }
          }
          return null;
        },
        cleanText: (text) => text,
        uidToDisplayName: squadState.memberDisplayNames,
        disableSwipeForTimestamp:
            true, // Disable timestamp swipe in preview mode
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildNavigationControls(BuildContext context, String variationName) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.15), // Much lighter
                Colors.black.withOpacity(0.05), // Nearly transparent
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Variation name
              Text(
                variationName,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      offset: const Offset(0, 1),
                      blurRadius: 4,
                    ),
                    Shadow(
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Navigation dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.variations.length,
                  (index) => _buildDot(index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: isActive ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
          borderRadius: BorderRadius.circular(4),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
