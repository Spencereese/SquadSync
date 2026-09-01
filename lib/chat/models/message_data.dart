import 'package:flutter/foundation.dart';

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
  final String? mediaUrl; // Direct URL for images/media
  final String? mediaType; // Type: image, video, audio
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
    this.mediaUrl,
    this.mediaType,
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
    if (kDebugMode) {
      print(
          '🔍 MessageData.fromMap called for id=${data['id']}, message_type=${data['message_type']}, media_url=${data['media_url']}, media_type=${data['media_type']}');
    }

    final id = data['id']?.toString() ?? '';
    final isAiResponse = data['isAiResponse'] ??
        (data['ai_response'] != null &&
            data['ai_response'].toString().isNotEmpty);
    final senderUid =
        data['senderId'] ?? data['senderUid'] ?? data['sender_id'] ?? '';

    // Resolve display name from UID using provided map
    String resolvedSenderName;
    if (isAiResponse) {
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
      photos: _parsePhotosFromData(data),
      videoUrl: _parseVideoFromData(data),
      audioUrl: _parseAudioFromData(data),
      mediaUrl: data['media_url'],
      mediaType: data['media_type'],
      timestamp: (() {
        DateTime parsedTimestamp;
        if (data['timestamp_ms'] is int && data['timestamp_ms'] != 0) {
          parsedTimestamp =
              DateTime.fromMillisecondsSinceEpoch(data['timestamp_ms']);
        } else if (data['timestamp'] is DateTime) {
          parsedTimestamp = data['timestamp'] as DateTime;
        } else if (data['timestamp'] is String &&
            (data['timestamp'] as String).isNotEmpty) {
          parsedTimestamp = DateTime.parse(data['timestamp']);
        } else if (data['created_at'] is String &&
            (data['created_at'] as String).isNotEmpty) {
          parsedTimestamp = DateTime.parse(data['created_at'] as String);
        } else {
          parsedTimestamp = DateTime.now();
        }
        print(
            '🕐 Timestamp parsed: id=${data['id']}, timestamp_ms=${data['timestamp_ms']}, parsedTimestamp=$parsedTimestamp');
        return parsedTimestamp;
      })(),
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
      replyTo: (() {
        final reply = data['replyTo'] ?? data['reply_to'];
        // debugPrint('💬 MessageData.fromMap: id=$id, replyTo field: $reply');
        return reply;
      })(),
      clipData: data['clipData'] != null
          ? ClipMessageData.fromJson(data['clipData'] as Map<String, dynamic>)
          : null,
      shouldShowTimestamp: false, // Will be set by message processing logic
      type: inferMessageDataType(data),
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
  bool get isGrokMessage => isAiResponse;

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

  /// Parse photos from media_url/media_type format
  static List<Map<String, dynamic>> _parsePhotosFromData(
      Map<String, dynamic> data) {
    final mediaUrl = data['media_url'];
    final mediaType = data['media_type'];
    final messageType = data['message_type'];

    if (kDebugMode) {
      print(
          '📸 _parsePhotosFromData: mediaUrl=$mediaUrl, mediaType=$mediaType, messageType=$messageType');
    }

    // Check if media_type is 'image', OR infer from URL extension, OR check message_type
    final isImage = mediaType == 'image' ||
        messageType == 'image' ||
        (mediaUrl is String &&
            (mediaUrl.contains('.jpg') ||
                mediaUrl.contains('.jpeg') ||
                mediaUrl.contains('.png') ||
                mediaUrl.contains('.gif') ||
                mediaUrl.contains('.webp')));

    if (mediaUrl != null &&
        mediaUrl is String &&
        isImage &&
        mediaUrl.isNotEmpty) {
      if (kDebugMode) {
        print('✅ Photo parsed: $mediaUrl');
      }
      return [
        {
          'uri': mediaUrl,
          'creation_timestamp':
              data['timestamp_ms'] ?? DateTime.now().millisecondsSinceEpoch,
        }
      ];
    }
    if (kDebugMode) {
      print('❌ No photo parsed');
    }
    return [];
  }

  /// Parse video from media_url/media_type format
  static String? _parseVideoFromData(Map<String, dynamic> data) {
    final mediaUrl = data['media_url'];
    final mediaType = data['media_type'];
    final messageType = data['message_type'];

    // Check if media_type is 'video', OR infer from URL extension, OR check message_type
    final isVideo = mediaType == 'video' ||
        messageType == 'video' ||
        (mediaUrl is String &&
            (mediaUrl.contains('.mp4') ||
                mediaUrl.contains('.mov') ||
                mediaUrl.contains('.avi') ||
                mediaUrl.contains('.webm')));

    if (mediaUrl != null &&
        mediaUrl is String &&
        isVideo &&
        mediaUrl.isNotEmpty) {
      return mediaUrl;
    }
    return null;
  }

  /// Parse audio from media_url/media_type format
  static String? _parseAudioFromData(Map<String, dynamic> data) {
    final mediaUrl = data['media_url'];
    final mediaType = data['media_type'];
    final messageType = data['message_type'];

    // Check if media_type is 'audio', OR infer from URL extension, OR check message_type
    final isAudio = mediaType == 'audio' ||
        messageType == 'audio' ||
        (mediaUrl is String &&
            (mediaUrl.contains('.mp3') ||
                mediaUrl.contains('.wav') ||
                mediaUrl.contains('.m4a') ||
                mediaUrl.contains('.ogg')));

    if (mediaUrl != null &&
        mediaUrl is String &&
        isAudio &&
        mediaUrl.isNotEmpty) {
      return mediaUrl;
    }
    return null;
  }

  /// Parse reactions field which can be in different formats
  static List<Map<String, dynamic>> _parseReactions(dynamic reactionsData) {
    // Fast path: Early return for null/empty (most common case)
    if (reactionsData == null) {
      return [];
    }

    // If it's a Map
    if (reactionsData is Map) {
      final mapData = reactionsData;
      if (mapData.isEmpty) {
        return [];
      }

      // Check format by looking at first value
      final firstValue = mapData.values.firstOrNull;

      if (firstValue is String) {
        // OLD format: Map<userId, emoji> - migrate to new format
        final emojiToUsers = <String, List<String>>{};
        for (final entry in mapData.entries) {
          final userId = entry.key.toString();
          final emoji = entry.value.toString();
          if (emoji.isNotEmpty) {
            emojiToUsers.putIfAbsent(emoji, () => []).add(userId);
          }
        }
        // Convert to list format for UI
        final List<Map<String, dynamic>> result = [];
        for (final entry in emojiToUsers.entries) {
          for (final userId in entry.value) {
            result.add({
              'emoji': entry.key,
              'userId': userId,
              'reaction': entry.key,
            });
          }
        }
        return result;
      } else if (firstValue is List) {
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

/// Prefer explicit media_type / message_type / metadata over a null media_url.
MessageType inferMessageDataType(Map<String, dynamic> data) {
  if (data['pollId'] != null || data['poll_id'] != null) {
    return MessageType.poll;
  }
  final mediaType =
      '${data['media_type'] ?? data['mediaType'] ?? ''}'.toLowerCase();
  final messageType =
      '${data['message_type'] ?? data['messageType'] ?? ''}'.toLowerCase();
  final fromMedia = _normalizeMediaKind(mediaType);
  if (fromMedia != null) return fromMedia;
  final fromDeclared = _normalizeMediaKind(messageType);
  if (fromDeclared != null) return fromDeclared;
  final fromMeta = _mediaKindFromMetadata(data['metadata']);
  if (fromMeta != null) return fromMeta;
  final mediaUrl = data['media_url'] ?? data['mediaUrl'];
  if (mediaUrl is String && mediaUrl.isNotEmpty) {
    final lower = mediaUrl.toLowerCase();
    if (lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp')) {
      return MessageType.image;
    }
    if (lower.contains('.mp4') || lower.contains('.mov') || lower.contains('.webm')) {
      return MessageType.video;
    }
    if (lower.contains('.m4a') || lower.contains('.mp3') || lower.contains('.wav')) {
      return MessageType.audio;
    }
  }
  return MessageType.text;
}

MessageType? _normalizeMediaKind(String raw) {
  if (raw.contains('image') || raw == 'photo' || raw == 'photos') {
    return MessageType.image;
  }
  if (raw.contains('video')) return MessageType.video;
  if (raw.contains('audio') || raw.contains('voice')) return MessageType.audio;
  if (raw.contains('clip')) return MessageType.clip;
  return null;
}

MessageType? _mediaKindFromMetadata(Object? metadata) {
  if (metadata is! Map) return null;
  final type = _normalizeMediaKind(
    '${metadata['media_type'] ?? metadata['mediaType'] ?? metadata['type'] ?? ''}',
  );
  if (type != null) return type;
  final photos = metadata['photos'];
  if (photos is List && photos.isNotEmpty) return MessageType.image;
  return null;
}

enum MessageStatus { sending, sent, delivered, read, failed }
