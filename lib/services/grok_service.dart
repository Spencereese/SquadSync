import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for integrating xAI's Grok AI into the chat
class GrokService {
  static const String _apiKeyKey = 'grok_api_key';
  static const String _baseUrl = 'https://api.x.ai/v1';

  SharedPreferences? _storage;

  /// Initialize the service with SharedPreferences
  Future<void> _ensureStorage() async {
    _storage ??= await SharedPreferences.getInstance();
  }

  /// Store Grok credentials securely (call once during dev setup)
  Future<void> storeApiKey() async {
    await _ensureStorage();
    const apiKey = 'REMOVED_FOR_SECURITY';
    await _storage!.setString(_apiKeyKey, apiKey);
    print('Grok API key stored securely');
  }

  /// Get stored API key
  Future<String?> getApiKey() async {
    await _ensureStorage();
    return _storage!.getString(_apiKeyKey);
  }

  /// Check if a message is directed at Grok
  bool isMessageForGrok(String message) {
    final lowerMessage = message.toLowerCase().trim();
    return lowerMessage.startsWith('@grok') ||
        lowerMessage.startsWith('grok') ||
        lowerMessage.contains('@grok') ||
        lowerMessage.startsWith('hey grok') ||
        lowerMessage.startsWith('hi grok');
  }

  /// Clean message by removing Grok mentions
  String cleanGrokMessage(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.startsWith('@grok ')) {
      return message.substring(6).trim();
    } else if (lowerMessage.startsWith('grok ')) {
      return message.substring(5).trim();
    } else if (lowerMessage.startsWith('hey grok ')) {
      return message.substring(8).trim();
    } else if (lowerMessage.startsWith('hi grok ')) {
      return message.substring(7).trim();
    }
    return message.replaceAll('@grok', '').trim();
  }

  /// Get AI response from Grok for gaming/squad related queries
  Future<String> getGrokResponse(
    String userMessage, {
    String? context,
    List<String>? recentMessages,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null) {
      return "Sorry, I'm not properly configured yet. Please contact the admin to set up my API access.";
    }

    try {
      // Build context-aware prompt for gaming squad assistance
      final systemPrompt = '''
You are Grok, a helpful AI assistant integrated into SquadSync, a gaming squad management app.
You help gamers with:
- Game strategy and tips
- Squad formation and team composition
- Game recommendations
- Tournament information
- Gaming terminology and mechanics
- General gaming advice

Keep responses concise, helpful, and gaming-focused. Be friendly and engaging.
If asked about non-gaming topics, politely redirect to gaming-related help.
''';

      final userContext = context != null ? '\nContext: $context' : '';
      final recentContext = recentMessages != null && recentMessages.isNotEmpty
          ? '\nRecent chat messages: ${recentMessages.take(3).join(' | ')}'
          : '';

      final fullPrompt =
          '$systemPrompt\n\nUser message: $userMessage$userContext$recentContext';

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'model': 'grok-beta',
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': fullPrompt,
            }
          ],
          'max_tokens': 500,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices']?[0]?['message']?['content'] ?? '';

        // Clean up the response
        return content.trim().isNotEmpty
            ? content.trim()
            : "I understand your question, but I'm having trouble formulating a response right now. Try asking about game strategies or squad management!";
      } else {
        print('Grok API error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      print('Error calling Grok API: $e');
      return _getFallbackResponse(userMessage);
    }
  }

  /// Provide fallback responses when API is unavailable
  String _getFallbackResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();

    if (lowerMessage.contains('strategy') || lowerMessage.contains('tips')) {
      return "I'd love to help with game strategies! Try asking about specific games like 'Warzone strategies' or 'Apex Legends tips'. My API connection seems to be down right now.";
    } else if (lowerMessage.contains('squad') ||
        lowerMessage.contains('team')) {
      return "Squad management is my specialty! I can help with team composition, player roles, and coordination strategies. What game are you playing?";
    } else if (lowerMessage.contains('recommend') ||
        lowerMessage.contains('suggest')) {
      return "I can recommend games based on your preferences! Tell me what genres you like (FPS, RPG, Battle Royale, etc.) and I'll suggest some great options.";
    } else {
      return "I'm here to help with gaming and squad management! Ask me about game strategies, team composition, or game recommendations. My API connection is temporarily down.";
    }
  }

  /// Clear stored API key (for testing/debugging)
  Future<void> clearStoredApiKey() async {
    await _ensureStorage();
    await _storage!.remove(_apiKeyKey);
    print('Grok API key cleared');
  }
}
