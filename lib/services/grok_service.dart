import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'dart:math';

/// Custom exception for rate limiting
class RateLimitException implements Exception {}

/// Service for integrating xAI's Grok AI into the chat via backend
class GrokService {
  static final Logger _logger = Logger();
  static const String _backendUrl = String.fromEnvironment('BACKEND_URL',
      defaultValue:
          'https://squadsync-backend-756172684661.us-central1.run.app');

  static const int _maxRetries = 3;
  static const int _baseDelayMs = 1000;

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
        _logger.e('Backend error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      _logger.e('Error calling backend Grok API: $e');
      return _getFallbackResponse(userMessage);
    }
  }

  /// Suggest squads for pinned games using Grok AI
  Future<String> suggestSquadsForPinnedGames(
      List<Map<String, dynamic>> pinnedGames) async {
    final gameNames = pinnedGames.map((g) => g['name'] as String).join(', ');
    final prompt = 'Suggest squads for my pinned games: [$gameNames]';

    return getGrokResponse(prompt);
  }

  /// Get vector embeddings for group data using Grok API
  Future<List<double>> getGroupEmbeddings(
      Map<String, dynamic> groupData) async {
    final text =
        '${groupData['name'] ?? ''} ${groupData['description'] ?? ''}'.trim();
    if (text.isEmpty) return [];

    return _callWithBackoff(() async {
      final response = await http.post(
        Uri.parse('$_backendUrl/embeddings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'text': text}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<double>.from(data['embedding'] ?? []);
      } else if (response.statusCode == 429) {
        throw RateLimitException();
      } else {
        throw Exception('Embedding API error: ${response.statusCode}');
      }
    });
  }

  /// Call API with exponential backoff for rate limits
  Future<T> _callWithBackoff<T>(Future<T> Function() call) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        return await call();
      } on RateLimitException {
        if (attempt == _maxRetries - 1) rethrow;
        final delay = _baseDelayMs * pow(2, attempt).toInt();
        await Future.delayed(Duration(milliseconds: delay));
        attempt++;
      }
    }
    throw Exception('Max retries exceeded');
  }

  /// Score relevance of group names to a search term
  Future<Map<String, double>> scoreRelevance(
      String searchTerm, List<String> candidates) async {
    if (candidates.isEmpty) return {};

    final prompt =
        'Score the relevance of each group name to the search term "$searchTerm" on a scale of 0-1. Return as JSON map: {name: score}. Names: ${candidates.join(', ')}';

    try {
      final response = await getGrokResponse(prompt);
      // Parse JSON response
      final scores = <String, double>{};
      // Simple parsing, assume response is JSON
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        final jsonStr = response.substring(jsonStart, jsonEnd + 1);
        final Map<String, dynamic> parsed = json.decode(jsonStr);
        parsed.forEach((key, value) {
          scores[key] = (value as num).toDouble();
        });
      }
      return scores;
    } catch (e) {
      // Fallback to simple string matching
      return Map.fromEntries(candidates.map((name) => MapEntry(name,
          name.toLowerCase().contains(searchTerm.toLowerCase()) ? 1.0 : 0.0)));
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
