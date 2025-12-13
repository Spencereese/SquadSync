import 'dart:convert';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/chat/models/message_data.dart';

abstract class ClipLocalDataSource {
  Future<void> cacheClip(MessageData clip, {String? squadId});
  Future<void> cacheClips(List<MessageData> clips, {String? squadId});
  Future<List<MessageData>> getCachedClips(String squadId,
      {int limit = 20, int offset = 0});
  Future<MessageData?> getCachedClip(String clipId);
  Future<void> updateClipViews(String clipId, int views);
  Future<void> updateClipHypeReactions(String clipId, List<String> reactions);
  Future<List<MessageData>> getUnsyncedClips();
  Future<void> markClipSynced(String clipId);
  Future<void> queueClipUpload(MessageData clip, {String? squadId});
  Future<void> purgeOldClips({int daysToKeep = 30});
}

class ClipLocalDataSourceImpl implements ClipLocalDataSource {
  final SQLiteHelper _sqliteHelper;

  ClipLocalDataSourceImpl(this._sqliteHelper);

  @override
  Future<void> cacheClip(MessageData clip, {String? squadId}) async {
    if (clip.clipData == null) return;

    final clipData = clip.clipData!;
    await _sqliteHelper.cacheClip({
      'id': clip.id,
      'squad_id': squadId ?? '',
      'sender_id': clip.senderUid,
      'sender_name': clip.sender,
      'video_url': clipData.videoUrl,
      'thumbnail_url': clipData.thumbnailUrl,
      'duration_sec': clipData.durationSec,
      'width': clipData.width,
      'height': clipData.height,
      'views': clipData.views,
      'hype_reactions': clipData.hypeReactions,
      'created_at': clip.timestamp.millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> cacheClips(List<MessageData> clips, {String? squadId}) async {
    for (final clip in clips) {
      await cacheClip(clip, squadId: squadId);
    }
  }

  @override
  Future<List<MessageData>> getCachedClips(String squadId,
      {int limit = 20, int offset = 0}) async {
    final results = await _sqliteHelper.getCachedClips(squadId,
        limit: limit, offset: offset);

    return results.map((map) {
      return MessageData(
        id: map['id'] as String,
        sender: map['sender_name'] as String,
        senderUid: map['sender_id'] as String,
        text: 'Clip',
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        type: MessageType.clip,
        status: MessageStatus.sent,
        clipData: ClipMessageData(
          videoUrl: map['video_url'] as String,
          thumbnailUrl: map['thumbnail_url'] as String? ?? '',
          durationSec: map['duration_sec'] as int? ?? 0,
          views: map['views'] as int? ?? 0,
          hypeReactions: List<String>.from(map['hype_reactions'] ?? []),
          clipId: map['id'] as String,
          width: map['width'] as int? ?? 0,
          height: map['height'] as int? ?? 0,
        ),
      );
    }).toList();
  }

  @override
  Future<MessageData?> getCachedClip(String clipId) async {
    final db = await _sqliteHelper.database;
    final results = await db.query(
      'clips',
      where: 'id = ?',
      whereArgs: [clipId],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final map = results.first;
    return MessageData(
      id: map['id'] as String,
      sender: map['sender_name'] as String,
      senderUid: map['sender_id'] as String,
      text: 'Clip',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      type: MessageType.clip,
      status: MessageStatus.sent,
      clipData: ClipMessageData(
        videoUrl: map['video_url'] as String,
        thumbnailUrl: map['thumbnail_url'] as String? ?? '',
        durationSec: map['duration_sec'] as int? ?? 0,
        views: map['views'] as int? ?? 0,
        hypeReactions: List<String>.from(
            jsonDecode(map['hype_reactions'] as String? ?? '[]')),
        clipId: map['id'] as String,
        width: map['width'] as int? ?? 0,
        height: map['height'] as int? ?? 0,
      ),
    );
  }

  @override
  Future<void> updateClipViews(String clipId, int views) async {
    await _sqliteHelper.updateClipViews(clipId, views);
  }

  @override
  Future<void> updateClipHypeReactions(
      String clipId, List<String> reactions) async {
    await _sqliteHelper.updateClipHypeReactions(clipId, reactions);
  }

  @override
  Future<List<MessageData>> getUnsyncedClips() async {
    final results = await _sqliteHelper.getUnsyncedClips();

    return results.map((map) {
      return MessageData(
        id: map['id'] as String,
        sender: map['sender_name'] as String,
        senderUid: map['sender_id'] as String,
        text: 'Clip',
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        type: MessageType.clip,
        status: MessageStatus.sent,
        clipData: ClipMessageData(
          videoUrl: map['video_url'] as String,
          thumbnailUrl: map['thumbnail_url'] as String? ?? '',
          durationSec: map['duration_sec'] as int? ?? 0,
          views: map['views'] as int? ?? 0,
          hypeReactions: List<String>.from(
              jsonDecode(map['hype_reactions'] as String? ?? '[]')),
          clipId: map['id'] as String,
          width: map['width'] as int? ?? 0,
          height: map['height'] as int? ?? 0,
        ),
      );
    }).toList();
  }

  @override
  Future<void> markClipSynced(String clipId) async {
    await _sqliteHelper.markClipSynced(clipId);
  }

  @override
  Future<void> queueClipUpload(MessageData clip, {String? squadId}) async {
    if (clip.clipData == null) return;

    // Cache the clip locally
    await cacheClip(clip, squadId: squadId);

    // Queue for upload
    await _sqliteHelper.enqueueOfflineItem(
      id: clip.id,
      type: 'clip_upload',
      data: {
        'id': clip.id,
        'squad_id': squadId ?? '',
        'sender_id': clip.senderUid,
        'sender_name': clip.sender,
        'video_url': clip.clipData!.videoUrl,
        'thumbnail_url': clip.clipData!.thumbnailUrl,
        'duration_sec': clip.clipData!.durationSec,
        'width': clip.clipData!.width,
        'height': clip.clipData!.height,
        'created_at': clip.timestamp.toIso8601String(),
      },
    );
  }

  @override
  Future<void> purgeOldClips({int daysToKeep = 30}) async {
    await _sqliteHelper.purgeOldClips(daysToKeep: daysToKeep);
  }
}
