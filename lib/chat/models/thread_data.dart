import 'package:cloud_firestore/cloud_firestore.dart';

/// Thread data model for managing threaded conversations
class ThreadData {
  final String id;
  final String rootMessageId;
  final String chatGroupId;
  final String title;
  final String creatorUid;
  final String creatorName;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final int replyCount;
  final List<String> participantUids;
  final bool isArchived;
  final bool isMuted;
  final ThreadType type;

  ThreadData({
    required this.id,
    required this.rootMessageId,
    required this.chatGroupId,
    required this.title,
    required this.creatorUid,
    required this.creatorName,
    required this.createdAt,
    required this.lastActivityAt,
    required this.replyCount,
    required this.participantUids,
    this.isArchived = false,
    this.isMuted = false,
    this.type = ThreadType.reply,
  });

  /// Factory constructor to create ThreadData from Firestore DocumentSnapshot
  factory ThreadData.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return ThreadData(
      id: doc.id,
      rootMessageId: data['rootMessageId'] ?? '',
      chatGroupId: data['chatGroupId'] ?? '',
      title: data['title'] ?? 'Thread',
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'] ?? 'Unknown',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastActivityAt: data['lastActivityAt'] is Timestamp
          ? (data['lastActivityAt'] as Timestamp).toDate()
          : DateTime.now(),
      replyCount: data['replyCount'] ?? 0,
      participantUids: List<String>.from(data['participantUids'] ?? []),
      isArchived: data['isArchived'] ?? false,
      isMuted: data['isMuted'] ?? false,
      type: ThreadType.values.firstWhere(
        (e) => e.toString() == 'ThreadType.${data['type']}',
        orElse: () => ThreadType.reply,
      ),
    );
  }

  /// Convert ThreadData to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'rootMessageId': rootMessageId,
      'chatGroupId': chatGroupId,
      'title': title,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      'replyCount': replyCount,
      'participantUids': participantUids,
      'isArchived': isArchived,
      'isMuted': isMuted,
      'type': type.toString().split('.').last,
    };
  }

  /// Create a copy with updated fields
  ThreadData copyWith({
    String? id,
    String? rootMessageId,
    String? chatGroupId,
    String? title,
    String? creatorUid,
    String? creatorName,
    DateTime? createdAt,
    DateTime? lastActivityAt,
    int? replyCount,
    List<String>? participantUids,
    bool? isArchived,
    bool? isMuted,
    ThreadType? type,
  }) {
    return ThreadData(
      id: id ?? this.id,
      rootMessageId: rootMessageId ?? this.rootMessageId,
      chatGroupId: chatGroupId ?? this.chatGroupId,
      title: title ?? this.title,
      creatorUid: creatorUid ?? this.creatorUid,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      replyCount: replyCount ?? this.replyCount,
      participantUids: participantUids ?? this.participantUids,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      type: type ?? this.type,
    );
  }

  /// Check if thread has activity
  bool get hasActivity => replyCount > 0;

  /// Get thread preview text
  String getPreviewText() {
    if (replyCount == 0) return 'No replies yet';
    if (replyCount == 1) return '1 reply';
    return '$replyCount replies';
  }
}

enum ThreadType {
  reply, // Standard reply thread
  question, // Question thread
  discussion, // Discussion thread
  announcement, // Announcement thread
}

/// Thread message data for messages within threads
class ThreadMessageData {
  final String messageId;
  final String threadId;
  final int depth; // Nesting level (0 = root, 1 = direct reply, etc.)
  final String? parentMessageId;
  final List<String> childMessageIds;

  ThreadMessageData({
    required this.messageId,
    required this.threadId,
    required this.depth,
    this.parentMessageId,
    this.childMessageIds = const [],
  });

  factory ThreadMessageData.fromMap(Map<String, dynamic> data) {
    return ThreadMessageData(
      messageId: data['messageId'] ?? '',
      threadId: data['threadId'] ?? '',
      depth: data['depth'] ?? 0,
      parentMessageId: data['parentMessageId'],
      childMessageIds: List<String>.from(data['childMessageIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'threadId': threadId,
      'depth': depth,
      'parentMessageId': parentMessageId,
      'childMessageIds': childMessageIds,
    };
  }
}
