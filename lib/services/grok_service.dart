import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for integrating xAI's Grok AI into the chat via backend
class GrokService {
  static const String _backendUrl = 'http://localhost:8080'; // Replace with your deployed backend URL

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

  /// Get AI response from Grok for gaming/squad related queries via backend
  Future<String> getGrokResponse(
    String userMessage, {
    String? context,
    List<String>? recentMessages,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/grok'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': userMessage,
          'context': context,
          'recentMessages': recentMessages,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['response'] ?? _getFallbackResponse(userMessage);
      } else {
        print('Backend error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      print('Error calling backend Grok API: $e');
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
}
