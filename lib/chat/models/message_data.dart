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
  final ClipMessageData? clipData;
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
    this.clipData,
    this.shouldShowTimestamp = false,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Factory constructor to create MessageData from Map
  factory MessageData.fromMap(Map<String, dynamic> data,
      {Map<String, String>? uidToDisplayName}) {
    final id = data['id']?.toString() ?? '';
    final isAiResponse = data['isAiResponse'] ?? false;
    final senderUid =
        data['senderId'] ?? data['senderUid'] ?? data['sender_id'] ?? '';

    // Resolve display name from UID using provided map
    String resolvedSenderName;
    if (isAiResponse && senderUid == 'grok-ai') {
      resolvedSenderName = 'Grok 🤖';
    } else if (uidToDisplayName != null &&
        uidToDisplayName.containsKey(senderUid)) {
      resolvedSenderName = uidToDisplayName[senderUid] ?? 'Unknown';
    } else {
      // Fallback to data fields or 'Unknown'
      resolvedSenderName = data['sender'] ?? data['sender_name'] ?? 'Unknown';
    }

    return MessageData(
      id: id,
      sender: resolvedSenderName,
      senderUid: senderUid,
      text: _parseTextField(data, 'content') ??
          _parseTextField(data, 'text') ??
          '',
      content:
          _parseTextField(data, 'content') ?? _parseTextField(data, 'text'),
      photos: _parsePhotos(data['photos']),
      videoUrl: data['videoUrl'] ?? _parseVideoUrl(data['videos']),
      audioUrl: data['audioUrl'] ?? _parseAudioUrl(data['audio']),
      timestamp: data['timestamp_ms'] is int && data['timestamp_ms'] != 0
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp_ms'])
          : (data['timestamp'] is String
              ? DateTime.parse(data['timestamp'])
              : DateTime.now()),
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
      editedAt:
          data['editedAt'] is String ? DateTime.parse(data['editedAt']) : null,
      replyTo: data['replyTo'],
      clipData: data['clipData'] != null
          ? ClipMessageData.fromJson(data['clipData'] as Map<String, dynamic>)
          : null,
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

  /// Parse text field which might be a String or Map
  static String? _parseTextField(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;

    // If it's already a String, return it
    if (value is String) return value;

    // If it's a Map, it might be a rich text object - extract the plain text
    if (value is Map<String, dynamic>) {
      // Try common text field names in rich text objects
      if (value['text'] is String) return value['text'] as String;
      if (value['plainText'] is String) return value['plainText'] as String;
      if (value['content'] is String) return value['content'] as String;
      // If we can't extract text, return empty string to avoid errors
      return '';
    }

    // For any other type, convert to string
    return value.toString();
  }

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

    // If it's a Map
    if (reactionsData is Map) {
      final mapData = reactionsData as Map<dynamic, dynamic>;
      if (mapData.isEmpty) return [];

      // Check format by looking at first value
      final firstValue = mapData.values.firstOrNull;
      
      if (firstValue is List) {
        // New format: Map<emoji, List<userId>>
        // Convert to List<Map<String, dynamic>> with individual user reactions
        final List<Map<String, dynamic>> result = [];
        for (final entry in mapData.entries) {
          final emoji = entry.key.toString();
          final users = entry.value as List;
          for (final userId in users) {
            result.add({
              'emoji': emoji,
              'userId': userId.toString(),
              'reaction': emoji, // Legacy field name support
            });
          }
        }
        return result;
      } else if (firstValue is int) {
        // Aggregated format: Map<emoji, count>
        return mapData.entries
            .map((entry) => {
                  'emoji': entry.key.toString(),
                  'count': entry.value is int ? entry.value : 1,
                  'reaction': entry.key.toString(), // Legacy field name support
                })
            .toList();
      }
    }

    // If it's already a list of maps, filter and cast
    if (reactionsData is List) {
      return reactionsData.whereType<Map<String, dynamic>>().toList();
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
      'clipData': clipData?.toJson(),
    };
  }
}

/// Clip message metadata
class ClipMessageData {
  final String videoUrl;
  final String thumbnailUrl;
  final int durationSec;
  final int views;
  final List<String> hypeReactions; // UIDs who hyped
  final String clipId;
  final int width;
  final int height;

  ClipMessageData({
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.durationSec,
    this.views = 0,
    this.hypeReactions = const [],
    required this.clipId,
    this.width = 0,
    this.height = 0,
  });

  factory ClipMessageData.fromJson(Map<String, dynamic> json) {
    return ClipMessageData(
      videoUrl: json['videoUrl'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      durationSec: json['durationSec'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      hypeReactions: (json['hypeReactions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      clipId: json['clipId'] as String? ?? '',
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'durationSec': durationSec,
        'views': views,
        'hypeReactions': hypeReactions,
        'clipId': clipId,
        'width': width,
        'height': height,
      };

  ClipMessageData copyWith({
    String? videoUrl,
    String? thumbnailUrl,
    int? durationSec,
    int? views,
    List<String>? hypeReactions,
    String? clipId,
    int? width,
    int? height,
  }) {
    return ClipMessageData(
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationSec: durationSec ?? this.durationSec,
      views: views ?? this.views,
      hypeReactions: hypeReactions ?? this.hypeReactions,
      clipId: clipId ?? this.clipId,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

enum MessageType { text, image, video, audio, poll, clip, system }

enum MessageStatus { sending, sent, delivered, read, failed }
