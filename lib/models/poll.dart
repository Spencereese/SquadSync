/// Represents a poll option with its text and vote count
class PollOption {
  final String id;
  final String text;
  final int voteCount;
  final List<String> voterUids; // For tracking who voted (if not anonymous)

  PollOption({
    required this.id,
    required this.text,
    this.voteCount = 0,
    this.voterUids = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'voteCount': voteCount,
      'voterUids': voterUids,
    };
  }

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      voteCount: map['voteCount'] ?? 0,
      voterUids: List<String>.from(map['voterUids'] ?? []),
    );
  }

  PollOption copyWith({
    String? id,
    String? text,
    int? voteCount,
    List<String>? voterUids,
  }) {
    return PollOption(
      id: id ?? this.id,
      text: text ?? this.text,
      voteCount: voteCount ?? this.voteCount,
      voterUids: voterUids ?? this.voterUids,
    );
  }
}

/// Represents a complete poll with all its data
class Poll {
  final String id;
  final String title;
  final String creatorUid;
  final String creatorName;
  final List<PollOption> options;
  final bool isMultipleChoice;
  final bool isAnonymous;
  final bool isClosed;
  final DateTime createdAt;
  final DateTime? closedAt;
  final Duration? duration; // Time limit for the poll
  final int totalVotes;

  Poll({
    required this.id,
    required this.title,
    required this.creatorUid,
    required this.creatorName,
    required this.options,
    this.isMultipleChoice = false,
    this.isAnonymous = false,
    this.isClosed = false,
    required this.createdAt,
    this.closedAt,
    this.duration,
  }) : totalVotes = options.fold(
            0, (accumulator, option) => accumulator + option.voteCount);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'options': options.map((option) => option.toMap()).toList(),
      'isMultipleChoice': isMultipleChoice,
      'isAnonymous': isAnonymous,
      'isClosed': isClosed,
      'createdAt': createdAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'duration': duration?.inSeconds,
    };
  }

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      creatorUid: map['creatorUid'] ?? '',
      creatorName: map['creatorName'] ?? '',
      options: (map['options'] as List<dynamic>?)
              ?.map((option) => PollOption.fromMap(option))
              .toList() ??
          [],
      isMultipleChoice: map['isMultipleChoice'] ?? false,
      isAnonymous: map['isAnonymous'] ?? false,
      isClosed: map['isClosed'] ?? false,
      createdAt: map['createdAt'] is String
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      closedAt:
          map['closedAt'] is String ? DateTime.parse(map['closedAt']) : null,
      duration: map['duration'] != null
          ? Duration(seconds: map['duration'] as int)
          : null,
    );
  }

  Poll copyWith({
    String? id,
    String? title,
    String? creatorUid,
    String? creatorName,
    List<PollOption>? options,
    bool? isMultipleChoice,
    bool? isAnonymous,
    bool? isClosed,
    DateTime? createdAt,
    DateTime? closedAt,
    Duration? duration,
  }) {
    return Poll(
      id: id ?? this.id,
      title: title ?? this.title,
      creatorUid: creatorUid ?? this.creatorUid,
      creatorName: creatorName ?? this.creatorName,
      options: options ?? this.options,
      isMultipleChoice: isMultipleChoice ?? this.isMultipleChoice,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      isClosed: isClosed ?? this.isClosed,
      createdAt: createdAt ?? this.createdAt,
      closedAt: closedAt ?? this.closedAt,
      duration: duration ?? this.duration,
    );
  }

  /// Check if a user has already voted
  bool hasUserVoted(String userUid) {
    return options.any((option) => option.voterUids.contains(userUid));
  }

  /// Get the user's current votes
  List<String> getUserVotes(String userUid) {
    return options
        .where((option) => option.voterUids.contains(userUid))
        .map((option) => option.id)
        .toList();
  }
}

/// Settings for creating a new poll
class PollSettings {
  final bool isMultipleChoice;
  final bool isAnonymous;
  final Duration? duration; // Optional time limit

  PollSettings({
    this.isMultipleChoice = false,
    this.isAnonymous = false,
    this.duration,
  });

  PollSettings copyWith({
    bool? isMultipleChoice,
    bool? isAnonymous,
    Duration? duration,
  }) {
    return PollSettings(
      isMultipleChoice: isMultipleChoice ?? this.isMultipleChoice,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      duration: duration ?? this.duration,
    );
  }
}
