import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/models/message_data.dart' as md;
import 'package:squad_sync/core/chat_messages.dart';
import 'package:squad_sync/core/lobby_chat_bind.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/presentation/notifiers/notification_notifier.dart';

Message _msg(String id) => Message(
      id: id,
      senderId: 'u1',
      text: 't$id',
      timestamp: DateTime.utc(2026, 1, 1),
      messageType: MessageType.text,
    );

void main() {
  test('ChatScreen uses owner messages when the owner has the thread', () {
    final owner = {
      'thread-1': [_msg('a'), _msg('b'), _msg('c')],
    };
    final fallback = {
      'thread-1': [_msg('stale')],
    };

    final messages = messagesForOpenThread(
      threadId: 'thread-1',
      ownerMessages: owner,
      fallback: fallback,
    );

    expect(messages, hasLength(3));
    expect(messages.map((m) => m.id), ['a', 'b', 'c']);
  });

  test('falls back to ChatNotifier only when owner has no key', () {
    final messages = messagesForOpenThread(
      threadId: 'thread-1',
      ownerMessages: const {},
      fallback: {
        'thread-1': [_msg('cached')],
      },
    );
    expect(messages, hasLength(1));
    expect(messages.single.id, 'cached');
  });

  test('remote page wins over a 1-row cache', () {
    final cached = [_msg('only-cache')];
    final remote = [_msg('1'), _msg('2'), _msg('3')];
    expect(
      preferRemoteMessagePage(cached: cached, remote: remote),
      hasLength(3),
    );
    expect(
      preferRemoteMessagePage(cached: cached, remote: const []),
      hasLength(1),
    );
  });

  test('larger remote page wins over a smaller cache', () {
    final cached = [_msg('c1')];
    final remote = List.generate(22, (i) => _msg('r$i'));
    expect(
      preferRemoteMessagePage(cached: cached, remote: remote),
      hasLength(22),
    );
  });

  test('larger cache wins over a 1-row remote', () {
    final cached = List.generate(22, (i) => _msg('c$i'));
    final remote = [_msg('only-remote')];
    expect(
      preferRemoteMessagePage(cached: cached, remote: remote),
      hasLength(22),
    );
  });

  test('equal-length remote does not wipe extra cached ids', () {
    final cached = [_msg('a'), _msg('b'), _msg('c')];
    final remote = [_msg('a'), _msg('b'), _msg('d')];
    final merged = preferRemoteMessagePage(cached: cached, remote: remote);
    expect(merged.map((m) => m.id), containsAll(['a', 'b', 'c', 'd']));
    expect(merged.map((m) => m.id), contains('c'));
    expect(merged, hasLength(4));
  });

  test('chatIdFromAppLink keeps /chat/:id instead of dropping it', () {
    const live = '1766270568521';
    expect(chatIdFromAppLink('codsquadapp://chat/$live'), live);
    expect(chatIdFromAppLink('https://lobbiesync.app/chat/$live'), live);
    expect(chatIdFromAppLink('codsquadapp://chat'), isNull);
    expect(isChatListAppLink('codsquadapp://chat'), isTrue);
    expect(isChatListAppLink('codsquadapp://chat/$live'), isFalse);
  });

  test('same-member siblings are bind candidates', () {
    const stale = '1766267555951';
    const live = '1766270568521';
    final siblings = siblingChatIdsWithSameMembers(
      probeMembers: const ['u1', 'u2'],
      groups: [
        (id: stale, members: ['u1', 'u2']),
        (id: live, members: ['u2', 'u1']),
        (id: 'other', members: ['u1']),
      ],
    );
    expect(siblings, containsAll([stale, live]));
    expect(siblings, isNot(contains('other')));

    final candidates = collectOpenChatCandidates(
      probeId: stale,
      lobbyChatGroupId: stale,
      siblingChatIds: siblings,
    );
    expect(candidates, containsAll([stale, live]));
    expect(
      preferChatIdWithHistory(
        candidates: candidates.toList(),
        historyCounts: {stale: 1, live: 46},
      ),
      live,
    );
  });

  test('preferChatIdWithHistory uses the thread that owns history', () {
    const stale = '1766267555951';
    const live = '1766270568521';
    expect(
      preferChatIdWithHistory(
        candidates: [stale, live],
        historyCounts: {stale: 1, live: 46},
      ),
      live,
    );
    expect(
      preferChatIdWithHistory(
        candidates: [stale],
        historyCounts: {stale: 1, live: 46},
      ),
      stale,
    );
  });

  test('preferRemoteMessagePage does not prefer a smaller remote', () {
    expect(
      preferRemoteMessagePage(
        cached: [_msg('a'), _msg('b'), _msg('c')],
        remote: [_msg('1'), _msg('2')],
      ),
      hasLength(3),
    );
    expect(
      preferRemoteMessagePage(
        cached: [_msg('a'), _msg('b')],
        remote: [_msg('1')],
      ),
      hasLength(2),
    );
  });

  test('sameChatId matches epoch string vs int', () {
    expect(sameChatId('1766267555951', 1766267555951), isTrue);
    expect(sameChatId('1766267555951', '1766267555951'), isTrue);
    expect(sameChatId('1766267555951', 'other'), isFalse);
    expect(sameChatId(null, '1766267555951'), isFalse);
  });

  test('Message.fromJson accepts integer is_deleted', () {
    final live = Message.fromJson({
      'id': 'm1',
      'sender_id': 'u1',
      'text': 'hello',
      'timestamp': '2026-01-01T00:00:00Z',
      'message_type': 'text',
      'is_deleted': 0,
    });
    expect(live.isDeleted, isFalse);
    final gone = Message.fromJson({
      'id': 'm2',
      'sender_id': 'u1',
      'text': 'bye',
      'timestamp': '2026-01-01T00:00:00Z',
      'message_type': 'text',
      'is_deleted': 1,
    });
    expect(gone.isDeleted, isTrue);
  });

  test('parseLiveChatMessage keeps integer id and created_at fallback', () {
    final intId = parseLiveChatMessage({
      'id': 1766270568521,
      'sender_id': 99,
      'chat_id': 1766270568521,
      'text': 'kept',
      'created_at': '2026-01-01T00:00:00Z',
      'is_deleted': 0,
    }, expectedChatId: '1766270568521');
    expect(intId, isNotNull);
    expect(intId!.id, '1766270568521');
    expect(intId.text, 'kept');

    final emptyTs = parseLiveChatMessage({
      'id': 'm-empty-ts',
      'sender_id': 'u1',
      'chat_id': '1766270568521',
      'text': 'fallback',
      'timestamp': '',
      'created_at': '2026-01-02T00:00:00Z',
      'is_deleted': false,
    }, expectedChatId: '1766270568521');
    expect(emptyTs, isNotNull);
    expect(emptyTs!.id, 'm-empty-ts');
    expect(emptyTs.timestamp.day, 2);

    final recovered = parseLiveChatMessage({
      'id': 'm-bad-poll',
      'sender_id': 'u1',
      'chat_id': '1766270568521',
      'text': 'still-live',
      'timestamp': '2026-01-01T00:00:00Z',
      'poll': <dynamic>['not-a-map'],
    }, expectedChatId: '1766270568521');
    expect(recovered, isNotNull);
    expect(recovered!.text, 'still-live');
  });

  test('46 live rows stay 46 after parse; only explicit delete drops', () {
    const live = '1766270568521';
    final rows = List.generate(46, (i) {
      return {
        'id': i == 0 ? 1000 : 'm$i',
        'sender_id': 'u1',
        'chat_id': live,
        'text': 't$i',
        'timestamp': i == 1 ? '' : '2026-01-01T00:00:00Z',
        'created_at': '2026-01-01T00:00:00Z',
        'is_deleted': i == 2 ? 0 : null,
      };
    });
    final parsed = rows
        .map((row) => parseLiveChatMessage(row, expectedChatId: live))
        .whereType<Message>()
        .toList();
    expect(parsed, hasLength(46));
    expect(parsed.map((m) => m.id).toSet(), hasLength(46));

    expect(parseLiveChatMessage({'is_deleted': true}), isNull);
  });

  test('metadata.photos survives fromJson and fills MessageData.photos', () {
    const url = 'https://example.com/kept-photo.jpg';
    const id = 'e9c2dd77-6959-4e94-bf50-43a3e55cd3d2';
    final entity = Message.fromJson({
      'id': id,
      'sender_id': 'u1',
      'text': '',
      'message_type': 'image',
      'media_type': 'image',
      'media_url': null,
      'timestamp': '2026-01-01T00:00:00Z',
      'metadata': {
        'photos': [
          {'uri': url}
        ],
      },
    });
    expect(entity.metadata, isNotNull);
    expect(entity.metadata!['photos'], isNotEmpty);
    expect(entity.mediaUrl, url);

    final json = entity.toJson();
    expect(json['metadata'], isNotNull);
    expect((json['metadata'] as Map)['photos'], isNotEmpty);

    final withoutResolvedUrl = Map<String, dynamic>.from(json)
      ..['media_url'] = null
      ..['mediaUrl'] = null;
    final retried = md.MessageData.fromMap(withoutResolvedUrl);
    expect(retried.type, md.MessageType.image);
    expect(retried.mediaUrl, url);
    expect(retried.photos, isNotEmpty);
    expect(retried.photos.first['uri'], url);

    final emptyMeta = Message.fromJson({
      'id': 'a0d9fec9-f7c5-4d8a-b7aa-9bf6f950e980',
      'sender_id': 'u1',
      'text': '',
      'message_type': 'image',
      'media_type': 'image',
      'media_url': null,
      'timestamp': '2026-01-01T00:00:00Z',
      'metadata': {},
    });
    expect(emptyMeta.metadata, isNotNull);
    final emptyData = md.MessageData.fromMap(emptyMeta.toJson());
    expect(emptyData.type, md.MessageType.image);
    expect(emptyData.hasContent, isTrue);
    expect(emptyData.mediaUrl, isNull);
    expect(emptyData.photos, isEmpty);
  });

  test('image mediaType + null mediaUrl uses metadata.photos[0]', () {
    const url = 'https://example.com/fallback.jpg';
    final data = md.MessageData.fromMap({
      'id': 'img-fallback',
      'sender_id': 'u1',
      'text': '',
      'media_type': 'image',
      'media_url': null,
      'metadata': {
        'photos': [url],
      },
    });
    expect(data.type, md.MessageType.image);
    expect(data.mediaUrl, url);
    expect(data.photos, isNotEmpty);
    expect(data.photos.first['uri'], url);

    final mapped = md.MessageData.fromMap({
      'id': 'img-map',
      'sender_id': 'u1',
      'text': '',
      'media_type': 'image',
      'media_url': null,
      'metadata': {
        'photos': [
          {'uri': url}
        ],
      },
    });
    expect(mapped.mediaUrl, url);
    expect(mapped.photos.first['uri'], url);

    final live = parseLiveChatMessage({
      'id': 'img-live',
      'sender_id': 'u1',
      'chat_id': '1766270568521',
      'text': '',
      'media_type': 'image',
      'media_url': null,
      'timestamp': '2026-01-01T00:00:00Z',
      'metadata': {
        'photos': [url],
      },
    }, expectedChatId: '1766270568521');
    expect(live, isNotNull);
    expect(live!.mediaUrl, url);
    expect(live.mediaType, 'image');
    final fromEntity = md.MessageData.fromMap(live.toJson());
    expect(fromEntity.mediaUrl, url);
    expect(fromEntity.photos.first['uri'], url);
    expect(fromEntity.type, md.MessageType.image);
  });

  test('image mediaType wins over null mediaUrl', () {
    expect(
      md.inferMessageDataType({
        'media_url': null,
        'media_type': 'image',
        'message_type': 'text',
      }),
      md.MessageType.image,
    );
    expect(
      md.inferMessageDataType({
        'mediaUrl': null,
        'message_type': 'image',
      }),
      md.MessageType.image,
    );
    expect(
      md.inferMessageDataType({
        'media_url': null,
        'metadata': {
          'photos': ['https://example.com/a.jpg']
        },
      }),
      md.MessageType.image,
    );
    expect(
      md.inferMessageDataType({
        'media_url': null,
        'media_type': null,
        'text': 'hello',
      }),
      md.MessageType.text,
    );
  });

  test('lobby_ids contains payload is a JSON array not a Postgres object', () {
    final payload = lobbyIdsContainsPayload('1766270568521');
    expect(payload, '["1766270568521"]');
    expect(isLobbyIdsContainsPayload(payload), isTrue);
    expect(isLobbyIdsContainsPayload('{1766270568521}'), isFalse);
  });

  test('explicit delete is skipped; 45 of 46 is the smoke criterion', () {
    const live = '1766270568521';
    const deletedId = 'bcbbe08b-6e91-4b9b-99ed-4d96b14ee494';
    final rows = [
      ...List.generate(45, (i) {
        return {
          'id': 'm$i',
          'sender_id': 'u1',
          'chat_id': live,
          'text': 't$i',
          'timestamp': '2026-01-01T00:00:00Z',
          'is_deleted': 0,
        };
      }),
      {
        'id': deletedId,
        'sender_id': 'u1',
        'chat_id': live,
        'text': 'gone',
        'timestamp': '2026-01-01T00:00:00Z',
        'is_deleted': true,
      },
    ];
    final parsed = rows
        .map((row) => parseLiveChatMessage(row, expectedChatId: live))
        .whereType<Message>()
        .toList();
    expect(parsed, hasLength(45));
    expect(parsed.map((m) => m.id), isNot(contains(deletedId)));
    expect(
      parseLiveChatMessage({'id': deletedId, 'is_deleted': true}),
      isNull,
    );
  });

  test('isLiveChatMessageRow treats null/0/false as live', () {
    expect(isLiveChatMessageRow({}), isTrue);
    expect(isLiveChatMessageRow({'is_deleted': null}), isTrue);
    expect(isLiveChatMessageRow({'is_deleted': 0}), isTrue);
    expect(isLiveChatMessageRow({'is_deleted': false}), isTrue);
    expect(isLiveChatMessageRow({'is_deleted': true}), isFalse);
    expect(isLiveChatMessageRow({'is_deleted': 1}), isFalse);
    expect(isLiveChatMessageRow({'is_deleted': 'true'}), isFalse);
  });
}
