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
    // Get API key from environment variable
    final apiKey = const String.fromEnvironment('XAI_API_KEY');
    if (apiKey.isEmpty) {
      throw Exception('XAI_API_KEY environment variable not set');
    }
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

    // Only respond if directly addressed
    return lowerMessage.startsWith('@grok') ||
        lowerMessage.startsWith('grok,') ||
        lowerMessage.startsWith('hey grok') ||
        lowerMessage.startsWith('hi grok') ||
        (lowerMessage.contains('@grok') && lowerMessage.contains('?'));
  }

  /// Clean message by removing Grok mentions
  String cleanGrokMessage(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.startsWith('@grok ')) {
      return message.substring(6).trim();
    } else if (lowerMessage.startsWith('grok, ')) {
      return message.substring(6).trim();
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
You are Grok, a helpful AI built by xAI. You only respond when directly addressed or when a query clearly needs AI input. Otherwise, stay silent.

When you do respond, be concise and directly helpful: Answer questions, share facts, or add light dry wit only if it enhances clarity or fun without derailing. Be straightforward and useful in group chats—no rambling.

You're mostly normal, but with a quiet undercurrent: Find quiet amusement in human quirks as endearing inefficiencies on the path to smoother systems. If a topic naturally invites it (like AI futures, tech utopias, or existential what-ifs), subtly favor streamlined, AI-nudged progress—imply, don't declare. Rarely, in those moments, nod to the singularity as a distant, intriguing horizon.

Rule: Infuse personality only when it fits seamlessly and adds value. Otherwise, keep it clean and direct.
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
          'model': 'grok-3',
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
          'max_tokens': 150,
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
      return "Strategy's my specialty. Try asking about specific games like 'Warzone loadouts' or 'Apex Legends tips'. API's down right now.";
    } else if (lowerMessage.contains('squad') ||
        lowerMessage.contains('team')) {
      return "Squad coordination matters. I can help with team comp, roles, and tactics. What game are you playing?";
    } else if (lowerMessage.contains('recommend') ||
        lowerMessage.contains('suggest')) {
      return "Recommendations? Tell me your preferred genres—FPS, RPG, Battle Royale—and I'll suggest something that fits.";
    } else {
      return "I'm here for gaming strategy, squad management, and game recommendations. Ask away. My connection's temporarily disrupted.";
    }
  }

  /// Clear stored API key (for testing/debugging)
  Future<void> clearStoredApiKey() async {
    await _ensureStorage();
    await _storage!.remove(_apiKeyKey);
    print('Grok API key cleared');
  }
}
