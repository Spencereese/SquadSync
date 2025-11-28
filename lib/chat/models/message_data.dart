import 'package:cloud_firestore/cloud_firestore.dart';

/// Core message data model to replace the Map<String, dynamic> usage
class MessageData {
  final String id;
  final String sender;
  final String senderUid;
  final String text;
  final String? content;
  final List<Map<String, dynamic>> photos;
  final String? videoUrl;
  final String? audioUrl;
  final DateTime timestamp;
  final bool delivered;
  final bool read;
  final List<Map<String, dynamic>> reactions;
  final String? pollId;
  final bool isAiResponse;
  final bool pinned;
  final MessageType type;
  final MessageStatus status;
  final bool isBumped;
  final String? originalId;
  final String? bumpedBy;
  final bool edited;
  final DateTime? editedAt;
  final String? replyTo;
  bool shouldShowTimestamp;

  MessageData({
    required this.id,
    required this.sender,
    required this.senderUid,
    required this.text,
    this.content,
    this.photos = const [],
    this.videoUrl,
    this.audioUrl,
    DateTime? timestamp,
    this.delivered = false,
    this.read = false,
    this.reactions = const [],
    this.pollId,
    this.isAiResponse = false,
    this.pinned = false,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.isBumped = false,
    this.originalId,
    this.bumpedBy,
    this.edited = false,
    this.editedAt,
    this.replyTo,
    this.shouldShowTimestamp = false,
  }) : timestamp = timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Factory constructor to create MessageData from Firestore DocumentSnapshot
  factory MessageData.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isAiResponse = data['isAiResponse'] ?? false;
    final senderUid = data['senderId'] ?? data['senderUid'] ?? '';

    return MessageData(
      id: doc.id,
      sender: isAiResponse && senderUid == 'grok-ai'
          ? '' // No name for Grok - shadow mode
          : data['sender'] ?? data['sender_name'] ?? 'Unknown',
      senderUid: senderUid,
      text: data['text'] ?? data['content'] ?? '',
      content: data['text'] ?? data['content'],
      photos: data['imageUrl'] != null
          ? [
              {
                'uri': data['imageUrl'],
                'creation_timestamp': data['timestamp_ms']
              }
            ]
          : _parsePhotos(data['photos']),
      videoUrl: data['videoUrl'] ?? _parseVideoUrl(data['videos']),
      audioUrl: data['audioUrl'] ?? _parseAudioUrl(data['audio']),
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(
              data['timestamp_ms'] ?? DateTime.now().millisecondsSinceEpoch),
      delivered: data['delivered'] ?? false,
      read: data['read'] ?? false,
      reactions: _parseReactions(data['reactions']),
      pollId: data['pollId'],
      isAiResponse: isAiResponse,
      pinned: data['pinned'] ?? false,
      isBumped: data['isBumped'] ?? false,
      originalId: data['originalId'],
      bumpedBy: data['bumpedBy'],
      edited: data['edited'] ?? false,
      editedAt: data['editedAt'] is Timestamp
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      replyTo: data['replyTo'],
      shouldShowTimestamp: false, // Will be set by message processing logic
    );
  }

  /// Factory constructor to create MessageData from Map
  factory MessageData.fromMap(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final isAiResponse = data['isAiResponse'] ?? false;
    final senderUid = data['senderId'] ?? data['senderUid'] ?? '';

    return MessageData(
      id: id,
      sender: isAiResponse && senderUid == 'grok-ai'
          ? 'Grok 🤖'
          : data['sender'] ?? data['sender_name'] ?? 'Unknown',
      senderUid: senderUid,
      text: data['content'] ?? data['text'] ?? '',
      content: data['content'] ?? data['text'],
      photos: _parsePhotos(data['photos']),
      videoUrl: data['videoUrl'] ?? _parseVideoUrl(data['videos']),
      audioUrl: data['audioUrl'] ?? _parseAudioUrl(data['audio']),
      timestamp: data['timestamp_ms'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp_ms'])
          : DateTime.now(),
      delivered: data['delivered'] ?? false,
      read: data['read'] ?? false,
      reactions: _parseReactions(data['reactions']),
      pollId: data['pollId'],
      isAiResponse: isAiResponse,
      pinned: data['pinned'] ?? false,
      isBumped: data['isBumped'] ?? false,
      originalId: data['originalId'],
      bumpedBy: data['bumpedBy'],
      edited: data['edited'] ?? false,
      editedAt: data['editedAt'] is Timestamp
          ? (data['editedAt'] as Timestamp).toDate()
          : null,
      replyTo: data['replyTo'],
      shouldShowTimestamp: false, // Will be set by message processing logic
    );
  }

  /// Check if message has any content
  bool get hasContent =>
      text.isNotEmpty ||
      photos.isNotEmpty ||
      videoUrl?.isNotEmpty == true ||
      audioUrl?.isNotEmpty == true ||
      pollId?.isNotEmpty == true;

  /// Check if this is a Grok AI message
  bool get isGrokMessage => isAiResponse && senderUid == 'grok-ai';

  /// Parse photos field which can be in different formats
  static List<Map<String, dynamic>> _parsePhotos(dynamic photosData) {
    if (photosData == null) return [];

    // If it's already a list of maps, cast it
    if (photosData is List) {
      return photosData.whereType<Map<String, dynamic>>().toList();
    }

    // If it's a single map, wrap it in a list
    if (photosData is Map<String, dynamic>) {
      return [photosData];
    }

    // If it's a list of dynamic, try to cast each item
    if (photosData is List<dynamic>) {
      return photosData
          .where((item) => item is Map<String, dynamic>)
          .cast<Map<String, dynamic>>()
          .toList();
    }

    return [];
  }

  /// Parse video URL from various formats
  static String? _parseVideoUrl(dynamic videosData) {
    if (videosData == null) return null;

    // If it's a list, get the first video's URI
    if (videosData is List && videosData.isNotEmpty) {
      final firstVideo = videosData[0];
      if (firstVideo is Map<String, dynamic>) {
        return firstVideo['uri'] as String?;
      }
    }

    // If it's a single video map
    if (videosData is Map<String, dynamic>) {
      return videosData['uri'] as String?;
    }

    return null;
  }

  /// Parse audio URL from various formats
  static String? _parseAudioUrl(dynamic audioData) {
    if (audioData == null) return null;

    // If it's a list, get the first audio's URI
    if (audioData is List && audioData.isNotEmpty) {
      final firstAudio = audioData[0];
      if (firstAudio is Map<String, dynamic>) {
        return firstAudio['uri'] as String?;
      }
    }

    // If it's a single audio map
    if (audioData is Map<String, dynamic>) {
      return audioData['uri'] as String?;
    }

    return null;
  }

  /// Parse reactions field which can be in different formats
  static List<Map<String, dynamic>> _parseReactions(dynamic reactionsData) {
    if (reactionsData == null) return [];

    // If it's a Map<String, int> (emoji -> count), convert to List<Map<String, dynamic>>
    if (reactionsData is Map<String, int>) {
      return reactionsData.entries
          .map((entry) => {'emoji': entry.key, 'count': entry.value})
          .toList();
    }

    // If it's already a list of maps, filter and cast
    if (reactionsData is List) {
      return reactionsData.whereType<Map<String, dynamic>>().toList();
    }

    // If it's a list of dynamic, try to cast each item
    if (reactionsData is List<dynamic>) {
      return reactionsData
          .where((item) => item is Map<String, dynamic>)
          .cast<Map<String, dynamic>>()
          .toList();
    }

    return [];
  }

  /// Convert MessageData back to Map for backward compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'senderUid': senderUid,
      'text': text,
      'content': content,
      'photos': photos,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
      'timestamp_ms': timestamp.millisecondsSinceEpoch,
      'delivered': delivered,
      'read': read,
      'reactions': reactions,
      'pollId': pollId,
      'isAiResponse': isAiResponse,
      'isBumped': isBumped,
      'originalId': originalId,
      'bumpedBy': bumpedBy,
      'edited': edited,
      'editedAt': editedAt?.millisecondsSinceEpoch,
      'replyTo': replyTo,
    };
  }
}

enum MessageType { text, image, video, audio, poll, system }

enum MessageStatus { sending, sent, delivered, read, failed }
