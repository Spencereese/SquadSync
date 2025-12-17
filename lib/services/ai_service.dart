import 'supabase_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:logger/logger.dart';
import '../domain/entities/lobby_state.dart';
import '../services/grok_service.dart';
import '../chat/sqlite_helper.dart';
import '../domain/entities/message.dart';

/// Service responsible for AI/Grok integration in chat functionality.
/// Handles AI response generation, context gathering, and message processing.
class AiService {
  final Logger _logger = Logger();
  final GrokService _grokService = GrokService();
  final SQLiteHelper _sqliteHelper = SQLiteHelper();

  /// Generate AI response from Grok for messages directed at it
  Future<void> generateGrokResponse(LobbyState squadState, String userMessage,
      String senderUid, String? squadId, String? chatGroupId,
      {required ChatType chatType}) async {
    try {
      // Clean the message by removing Grok mentions
      final cleanMessage = _grokService.cleanGrokMessage(userMessage);

      // Get context about the current squad/game
      final currentGame = squadState.currentGame;
      final gameContext = currentGame != null
          ? 'Currently playing: ${currentGame['name']} (${currentGame['genres']?.join(', ') ?? 'Unknown genre'})'
          : 'No specific game selected';

      // Get recent messages for context (last 5 messages)
      final recentMessages = await _getRecentMessages(squadId, chatGroupId,
          limit: 5, chatType: chatType, userId: senderUid);

      // Generate Grok response
      final grokResponse = await _grokService.getGrokResponse(
        cleanMessage,
        context: gameContext,
        recentMessages: recentMessages,
      );

      // Create Grok's response message
      final grokMsgId = Uuid().v4();

      final grokMessageData = {
        'id': grokMsgId,
        'sender_id':
            senderUid, // Use the original sender's UID to satisfy FK constraint
        'chat_id': chatGroupId,
        'text': grokResponse,
        'message_type': 'text',
        'ai_response': grokResponse, // Store AI response
        'timestamp': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      // Send Grok's response to Supabase
      await SupabaseService.client
          .from('chat_messages')
          .insert(grokMessageData);

      // Cache locally
      await _sqliteHelper.insertMessage(grokMessageData,
          chatGroupId: chatGroupId);
    } catch (e) {
      _logger.e('Failed to generate Grok response: $e');
      // Don't show error to user, just log it
    }
  }

  /// Get recent messages for context
  Future<List<String>> _getRecentMessages(String? squadId, String? chatGroupId,
      {int limit = 5, required ChatType chatType, String? userId}) async {
    try {
      if (chatGroupId == null) return [];

      final response = await SupabaseService.client
          .from('chat_messages')
          .select('text, ai_response')
          .eq('chat_id', chatGroupId)
          .order('timestamp', ascending: false)
          .limit(limit * 2); // Get more to filter out AI responses

      final messages = response
          .where((row) => row['ai_response'] == null) // Exclude AI responses
          .take(limit)
          .map((row) => row['text'] as String?)
          .where((text) => text != null && text.isNotEmpty)
          .cast<String>()
          .toList();

      return messages.reversed.toList(); // Return in chronological order
    } catch (e) {
      _logger.e('Failed to get recent messages: $e');
      return [];
    }
  }

  /// Check if a message should trigger an AI response
  bool shouldGenerateAiResponse(String message) {
    return _grokService.isMessageForGrok(message);
  }

  /// Generate AI-powered poll options based on a poll question
  Future<List<String>> generatePollOptions(String pollQuestion,
      {String? context}) async {
    try {
      final prompt = '''
Generate 4-6 creative and relevant poll options for this question: "$pollQuestion"

${context != null ? 'Context: $context' : ''}

Requirements:
- Options should be diverse and engaging
- Keep each option under 50 characters
- Make them specific and actionable
- Avoid generic options like "Other" or "None"
- Focus on general conversation and decision-making

Return only the options as a JSON array of strings, no other text.
Example: ["Option 1", "Option 2", "Option 3", "Option 4"]
''';

      final response = await _grokService.getGrokResponse(
        prompt,
        context: 'Generating poll options for a general chat conversation',
      );

      // Try to parse as JSON array
      try {
        final cleanedResponse = response.trim();
        // Remove markdown code blocks if present
        final jsonStart = cleanedResponse.indexOf('[');
        final jsonEnd = cleanedResponse.lastIndexOf(']') + 1;
        if (jsonStart >= 0 && jsonEnd > jsonStart) {
          final jsonStr = cleanedResponse.substring(jsonStart, jsonEnd);
          final options = json.decode(jsonStr) as List<dynamic>;
          return options.map((e) => e.toString()).toList();
        }
      } catch (e) {
        _logger.e('Failed to parse poll options JSON: $e');
      }

      // Fallback: extract options from text response
      final lines = response
          .split('\n')
          .map((line) => line.trim())
          .where((line) =>
              line.isNotEmpty &&
              !line.startsWith('[') &&
              !line.startsWith(']') &&
              !line.contains('Example:') &&
              !line.contains('Return only'))
          .take(6)
          .toList();

      return lines
          .where((line) => line.isNotEmpty && line.length < 50)
          .toList();
    } catch (e) {
      _logger.e('Error generating poll options: $e');
      return [];
    }
  }
}
