import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/current_squad_notifier.dart';
import '../presentation/notifiers/chat_notifier.dart' as cn;
import '../models/public_squad.dart';
import '../chat/chat_input_bar.dart';
import '../widgets/spots_lobby_bar.dart';
import '../domain/entities/message.dart' show ChatType, MessageType;

class SquadDetailScreen extends ConsumerStatefulWidget {
  const SquadDetailScreen({super.key});

  @override
  ConsumerState<SquadDetailScreen> createState() => _SquadDetailScreenState();
}

class _SquadDetailScreenState extends ConsumerState<SquadDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final squadAsync = ref.watch(currentLobbyProvider);

        if (squadAsync.hasError) return const Text('Error');
        if (squadAsync.isLoading || squadAsync.value == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final squad = squadAsync.value!;

        return Scaffold(
          appBar: AppBar(
            title: Text(squad.name),
            leading: const BackButton(), // back to squads list
            actions: [
              IconButton(
                icon: const Icon(Icons
                    .mic_off), // TODO: squad.isVoiceEnabled ? Icons.mic : Icons.mic_off
                onPressed: () => _toggleVoice(ref, squad.id),
              ),
              PopupMenuButton<String>(
                onSelected: (value) =>
                    _handleMenuAction(context, ref, value, squad),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'set_game', child: Text('Set Game')),
                  const PopupMenuItem(
                      value: 'make_public', child: Text('Make Public')),
                  const PopupMenuItem(
                      value: 'invite_code', child: Text('Invite Code')),
                  const PopupMenuItem(
                      value: 'leave_squad', child: Text('Leave Squad')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Spots lobby bar (only if game set)
              if (squad.maxSpots != null) SpotsLobbyBar(squad: squad),

              // Chat messages
              Expanded(
                child: _buildChatMessagesList(ref, squad.id),
              ),

              // Input bar
              _buildChatInputBar(ref, squad.id),
            ],
          ),
        );
      },
    );
  }

  void _toggleVoice(WidgetRef ref, String squadId) {
    // TODO: Implement voice toggle with squadId
  }

  void _handleMenuAction(
      BuildContext context, WidgetRef ref, String action, PublicSquad squad) {
    switch (action) {
      case 'set_game':
        // TODO: Navigate to game selection
        break;
      case 'make_public':
        // TODO: Toggle public status
        break;
      case 'invite_code':
        // TODO: Show invite code dialog
        break;
      case 'leave_squad':
        // TODO: Leave squad logic
        break;
    }
  }

  Widget _buildChatMessagesList(WidgetRef ref, String squadId) {
    return ref.watch(cn.chatNotifierProvider).when(
          data: (chatState) {
            final messages = chatState.chatMessages[squadId] ?? [];
            return ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ListTile(
                  title: Text(message.senderId),
                  subtitle: Text(message.text),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
        );
  }

  Widget _buildChatInputBar(WidgetRef ref, String squadId) {
    final chatState = ref.watch(cn.chatNotifierProvider).valueOrNull;

    return ChatInputBar(
      controller: _messageController,
      focusNode: _inputFocusNode,
      isRecording: chatState?.isRecording ?? false,
      isUploading: chatState?.isUploading ?? false,
      onSend: () => _sendMessage(ref, squadId),
      onMedia: () => _sendMedia(ref, squadId),
      onRecordStart: () => _startRecording(ref, squadId),
      onRecordStop: () => _stopRecording(ref, squadId),
      onPlusMenu: () => _showPlusMenu(context, ref, squadId),
      onTextChanged: (value) => _onTextChanged(ref, squadId, value),
      quickReactionEmoji: chatState?.quickReactionEmoji ?? '👍',
      hintText: chatState?.replyToMessage != null ? 'Reply' : 'Message',
    );
  }

  void _sendMessage(WidgetRef ref, String squadId) {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      ref.read(cn.chatNotifierProvider.notifier).sendMessage(
            ref,
            squadId,
            content,
            MessageType.text,
            ChatType.squad,
          );
      _messageController.clear();
    }
  }

  void _sendMedia(WidgetRef ref, String squadId) {
    // TODO: Implement media sending
  }

  void _startRecording(WidgetRef ref, String squadId) {
    // TODO: Implement recording start
  }

  void _stopRecording(WidgetRef ref, String squadId) {
    // TODO: Implement recording stop
  }

  void _showPlusMenu(BuildContext context, WidgetRef ref, String squadId) {
    // TODO: Implement plus menu
  }

  void _onTextChanged(WidgetRef ref, String squadId, String value) {
    // TODO: Implement typing indicators
  }
}
