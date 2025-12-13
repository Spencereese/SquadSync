import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:retry/retry.dart';

/// Custom exception for rate limiting
class RateLimitException implements Exception {}

/// Smart reply response with sentiment analysis and emoji suggestions
class SmartReplyResponse {
  final List<String> replies;
  final String sentiment;
  final List<String> emojis;

  SmartReplyResponse({
    required this.replies,
    required this.sentiment,
    required this.emojis,
  });

  factory SmartReplyResponse.fromJson(Map<String, dynamic> json) {
    return SmartReplyResponse(
      replies: List<String>.from(json['replies'] ?? []),
      sentiment: json['sentiment'] ?? 'neutral',
      emojis: List<String>.from(json['emojis'] ?? ['😊', '👍', '🎮']),
    );
  }
}

/// AI matchmaking recommendation
class LobbyRecommendation {
  final String lobbyId;
  final double score;
  final String reason;

  LobbyRecommendation({
    required this.lobbyId,
    required this.score,
    required this.reason,
  });

  factory LobbyRecommendation.fromJson(Map<String, dynamic> json) {
    return LobbyRecommendation(
      lobbyId: json['lobbyId'] ?? '',
      score: (json['score'] ?? 0.0).toDouble(),
      reason: json['reason'] ?? '',
    );
  }
}

/// AI matchmaking response with recommendations and insights
class AiMatchmakingResponse {
  final List<LobbyRecommendation> recommendations;
  final String insights;

  AiMatchmakingResponse({
    required this.recommendations,
    required this.insights,
  });

  factory AiMatchmakingResponse.fromJson(Map<String, dynamic> json) {
    final recList = json['recommendations'] as List<dynamic>?;
    return AiMatchmakingResponse(
      recommendations: recList
              ?.map((e) =>
                  LobbyRecommendation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      insights: json['insights'] ?? '',
    );
  }
}

/// Service for integrating xAI's Grok AI into the chat via backend
class GrokService {
  static final Logger _logger = Logger();
  static const String _backendUrl = String.fromEnvironment('BACKEND_URL',
      defaultValue:
          'https://lobbiesync-backend-756172684661.us-central1.run.app');

  static const int _maxRetries = 3;
  static const int _baseDelayMs = 1000;

  // Cache for smart replies (1 minute TTL)
  final Map<String, _CachedReplies> _smartReplyCache = {};

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

  /// Get smart reply suggestions with sentiment analysis and emoji suggestions
  Future<SmartReplyResponse> getSmartRepliesWithSentiment(
      List<String> lastFiveMessages) async {
    if (lastFiveMessages.isEmpty) {
      return SmartReplyResponse(
        replies: [],
        sentiment: 'neutral',
        emojis: ['😊', '👍', '🎮'],
      );
    }

    // Simple cache with 1 minute TTL
    final cacheKey = lastFiveMessages.join('|');
    final now = DateTime.now();
    if (_smartReplyCache.containsKey(cacheKey)) {
      final cached = _smartReplyCache[cacheKey]!;
      if (now.difference(cached.timestamp).inMinutes < 1) {
        // Return cached response with sentiment data
        return SmartReplyResponse(
          replies: cached.replies,
          sentiment: cached.sentiment ?? 'neutral',
          emojis: cached.emojis ?? ['😊', '👍', '🎮'],
        );
      }
    }

    try {
      final response = await _callWithBackoff(() async {
        final result = await http.post(
          Uri.parse('$_backendUrl/smart-replies'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'messages': lastFiveMessages}),
        );
        return result;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final smartReply = SmartReplyResponse.fromJson(data);
        // Cache the result with sentiment data
        _smartReplyCache[cacheKey] = _CachedReplies(
          now,
          smartReply.replies,
          sentiment: smartReply.sentiment,
          emojis: smartReply.emojis,
        );
        return smartReply;
      } else {
        _logger.e(
            'Smart replies API error: ${response.statusCode} - ${response.body}');
        return SmartReplyResponse(
          replies: _getFallbackSmartReplies(lastFiveMessages),
          sentiment: 'neutral',
          emojis: ['😊', '👍', '🎮'],
        );
      }
    } catch (e) {
      _logger.e('Error getting smart replies: $e');
      return SmartReplyResponse(
        replies: _getFallbackSmartReplies(lastFiveMessages),
        sentiment: 'neutral',
        emojis: ['😊', '👍', '🎮'],
      );
    }
  }

  /// Get smart reply suggestions (legacy method - returns only replies)
  Future<List<String>> getSmartReplies(List<String> lastFiveMessages) async {
    final response = await getSmartRepliesWithSentiment(lastFiveMessages);
    return response.replies;
  }

  /// AI Matchmaking: Get lobby recommendations based on pinned games and preferences
  Future<AiMatchmakingResponse> getAiMatchmaking({
    required List<Map<String, dynamic>> pinnedGames,
    Map<String, dynamic>? userPreferences,
    List<Map<String, dynamic>>? availableLobbies,
  }) async {
    if (pinnedGames.isEmpty) {
      return AiMatchmakingResponse(
        recommendations: [],
        insights:
            'No pinned games found. Pin some games to get personalized recommendations!',
      );
    }

    try {
      final response = await _callWithBackoff(() async {
        final result = await http.post(
          Uri.parse('$_backendUrl/ai-matchmaking'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'pinnedGames': pinnedGames,
            'userPreferences': userPreferences ?? {},
            'availableLobbies': availableLobbies ?? [],
          }),
        );
        return result;
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return AiMatchmakingResponse.fromJson(data);
      } else {
        _logger.e(
            'AI matchmaking API error: ${response.statusCode} - ${response.body}');
        return AiMatchmakingResponse(
          recommendations: [],
          insights:
              'Unable to get AI recommendations at this time. Try browsing hot lobbies!',
        );
      }
    } catch (e) {
      _logger.e('Error getting AI matchmaking: $e');
      return AiMatchmakingResponse(
        recommendations: [],
        insights:
            'Unable to get AI recommendations. Check your connection and try again.',
      );
    }
  }

  /// Suggest lobbies for pinned games using Grok AI (legacy method)
  Future<String> suggestLobbiesForPinnedGames(
      List<Map<String, dynamic>> pinnedGames) async {
    final response = await getAiMatchmaking(pinnedGames: pinnedGames);
    return response.insights;
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

  /// Call API with exponential backoff for rate limits using retry package
  Future<T> _callWithBackoff<T>(Future<T> Function() call) async {
    final retryOptions = RetryOptions(
      maxAttempts: _maxRetries,
      delayFactor: Duration(milliseconds: _baseDelayMs),
      randomizationFactor: 0.25, // Add jitter to avoid thundering herd
      maxDelay: const Duration(seconds: 10),
    );

    return retryOptions.retry(
      call,
      retryIf: (e) => e is RateLimitException || e is http.ClientException,
      onRetry: (e) {
        _logger.w('Retrying API call after error: ${e.toString()}');
      },
    );
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

  /// Fallback smart replies when API is unavailable
  List<String> _getFallbackSmartReplies(List<String> lastFiveMessages) {
    final lastMessage =
        lastFiveMessages.isNotEmpty ? lastFiveMessages.last.toLowerCase() : '';

    if (lastMessage.contains('ready') || lastMessage.contains('in')) {
      return ['Sounds good!', 'Count me in!', 'Let\'s do this!'];
    } else if (lastMessage.contains('game') || lastMessage.contains('play')) {
      return ['What game?', 'I\'m down!', 'Let\'s play!'];
    } else if (lastMessage.contains('?')) {
      return ['Good question!', 'I\'m not sure', 'Ask Grok!'];
    } else {
      return ['Nice!', 'Agreed!', 'LOL'];
    }
  }
}

/// Cached smart replies with timestamp, sentiment, and emojis
class _CachedReplies {
  final DateTime timestamp;
  final List<String> replies;
  final String? sentiment;
  final List<String>? emojis;

  _CachedReplies(
    this.timestamp,
    this.replies, {
    this.sentiment,
    this.emojis,
  });
}
