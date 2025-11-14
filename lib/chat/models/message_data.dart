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
  final String? replyTo;
  final String? pollId;
  final bool isAiResponse;
  final bool pinned;
  final MessageType type;
  final MessageStatus status;
  final String? threadId;
  final int threadDepth;
  final bool isBumped;
  final String? originalId;
  final String? bumpedBy;

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
    this.replyTo,
    this.pollId,
    this.isAiResponse = false,
    this.pinned = false,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.threadId,
    this.threadDepth = 0,
    this.isBumped = false,
    this.originalId,
    this.bumpedBy,
  }) : timestamp = timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Factory constructor to create MessageData from Firestore DocumentSnapshot
  factory MessageData.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isAiResponse = data['isAiResponse'] ?? false;
    final senderUid = data['senderUid'] ?? '';

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
          : (data['photos'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [],
      videoUrl: data['videoUrl'] ??
          (data['videos']?.isNotEmpty == true
              ? data['videos'][0]['uri']
              : null),
      audioUrl: data['audioUrl'] ??
          (data['audio']?.isNotEmpty == true ? data['audio'][0]['uri'] : null),
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(
              data['timestamp_ms'] ?? DateTime.now().millisecondsSinceEpoch),
      delivered: data['delivered'] ?? false,
      read: data['read'] ?? false,
      reactions: (data['reactions'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [],
      replyTo: data['replyTo'] ?? data['reply_to'],
      pollId: data['pollId'],
      isAiResponse: isAiResponse,
      pinned: data['pinned'] ?? false,
      threadId: data['threadId'],
      threadDepth: data['threadDepth'] ?? 0,
      isBumped: data['isBumped'] ?? false,
      originalId: data['originalId'],
      bumpedBy: data['bumpedBy'],
    );
  }

  /// Factory constructor to create MessageData from Map
  factory MessageData.fromMap(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? '';
    final isAiResponse = data['isAiResponse'] ?? false;
    final senderUid = data['senderUid'] ?? '';

    return MessageData(
      id: id,
      sender: isAiResponse && senderUid == 'grok-ai'
          ? 'Grok 🤖'
          : data['sender'] ?? data['sender_name'] ?? 'Unknown',
      senderUid: senderUid,
      text: data['content'] ?? data['text'] ?? '',
      content: data['content'] ?? data['text'],
      photos:
          (data['photos'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [],
      videoUrl: data['videoUrl'] ??
          (data['videos']?.isNotEmpty == true
              ? data['videos'][0]['uri']
              : null),
      audioUrl: data['audioUrl'] ??
          (data['audio']?.isNotEmpty == true ? data['audio'][0]['uri'] : null),
      timestamp: data['timestamp_ms'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['timestamp_ms'])
          : DateTime.now(),
      delivered: data['delivered'] ?? false,
      read: data['read'] ?? false,
      reactions: (data['reactions'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [],
      replyTo: data['replyTo'] ?? data['reply_to'],
      pollId: data['pollId'],
      isAiResponse: isAiResponse,
      pinned: data['pinned'] ?? false,
      threadId: data['threadId'],
      threadDepth: data['threadDepth'] is int ? data['threadDepth'] : 0,
      isBumped: data['isBumped'] ?? false,
      originalId: data['originalId'],
      bumpedBy: data['bumpedBy'],
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
      'replyTo': replyTo,
      'pollId': pollId,
      'isAiResponse': isAiResponse,
      'threadId': threadId,
      'threadDepth': threadDepth,
      'isBumped': isBumped,
      'originalId': originalId,
      'bumpedBy': bumpedBy,
    };
  }
}

enum MessageType { text, image, video, audio, poll, system }

enum MessageStatus { sending, sent, delivered, read, failed }
