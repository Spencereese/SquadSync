import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/entities/chat_group.dart';
import 'package:squad_sync/domain/entities/message.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';

// Manual mock for ChatRepository since build_runner is failing
class ManualMockChatRepository extends Mock implements ChatRepository {
  // Track method calls for verification
  final List<String> calledMethods = [];
  final Map<String, dynamic> methodArgs = {};

  // Exception handling
  bool shouldThrowException = false;
  dynamic exceptionToThrow;

  @override
  Future<Message> sendMessage(String chatGroupId, String text,
      MessageType messageType, ChatType chatType,
      {String? mediaUrl,
      String? mediaType,
      String? replyTo,
      Poll? poll,
      String? voiceNoteUrl,
      int? voiceNoteDuration}) async {
    calledMethods.add('sendMessage');
    methodArgs['sendMessage'] = {
      'chatGroupId': chatGroupId,
      'text': text,
      'messageType': messageType,
      'chatType': chatType,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'replyTo': replyTo,
      'poll': poll,
      'voiceNoteUrl': voiceNoteUrl,
      'voiceNoteDuration': voiceNoteDuration
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    // Return a mock message
    return Message(
      id: 'mock_msg_id',
      senderId: 'mock_sender',
      text: text,
      timestamp: DateTime.now(),
      messageType: messageType,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      replyTo: replyTo,
    );
  }

  @override
  Future<List<Message>> loadMessages(String chatGroupId,
      {int limit = 50, DateTime? before}) async {
    calledMethods.add('loadMessages');
    methodArgs['loadMessages'] = {
      'chatGroupId': chatGroupId,
      'limit': limit,
      'before': before
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return [];
  }

  @override
  Future<void> deleteMessage(String chatGroupId, String messageId) async {
    calledMethods.add('deleteMessage');
    methodArgs['deleteMessage'] = {
      'chatGroupId': chatGroupId,
      'messageId': messageId
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> syncMessages(String chatGroupId, {DateTime? since}) async {
    calledMethods.add('syncMessages');
    methodArgs['syncMessages'] = {'chatGroupId': chatGroupId, 'since': since};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<Message> editMessage(
      String chatGroupId, String messageId, String newText) async {
    calledMethods.add('editMessage');
    methodArgs['editMessage'] = {
      'chatGroupId': chatGroupId,
      'messageId': messageId,
      'newText': newText
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return Message(
      id: messageId,
      senderId: 'mock_sender',
      text: newText,
      timestamp: DateTime.now(),
      messageType: MessageType.text,
    );
  }

  @override
  Stream<List<Message>> watchMessages(String chatGroupId) {
    return Stream.value([]);
  }

  @override
  Stream<Map<String, Set<String>>> watchTypingIndicators(String chatGroupId) {
    return Stream.value({});
  }

  @override
  Stream<Map<String, int>> watchUnreadCounts() {
    return Stream.value({});
  }

  @override
  Future<void> addReaction(
      String chatGroupId, String messageId, String reaction) async {
    calledMethods.add('addReaction');
    methodArgs['addReaction'] = {
      'chatGroupId': chatGroupId,
      'messageId': messageId,
      'reaction': reaction
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> removeReaction(
      String chatGroupId, String messageId, String reaction) async {
    calledMethods.add('removeReaction');
    methodArgs['removeReaction'] = {
      'chatGroupId': chatGroupId,
      'messageId': messageId,
      'reaction': reaction
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<Map<String, int>> getMessageReactions(
      String chatGroupId, String messageId) async {
    calledMethods.add('getMessageReactions');
    methodArgs['getMessageReactions'] = {
      'chatGroupId': chatGroupId,
      'messageId': messageId
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return {};
  }

  @override
  Future<Poll> createPoll(
      String chatGroupId, String question, List<String> options) async {
    calledMethods.add('createPoll');
    methodArgs['createPoll'] = {
      'chatGroupId': chatGroupId,
      'question': question,
      'options': options
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return Poll(
      id: 'mock_poll_id',
      question: question,
      options: options,
      votes: {},
      createdAt: DateTime.now(),
      createdBy: 'mock_user',
    );
  }

  @override
  Future<void> votePoll(
      String chatGroupId, String pollId, String option, String voterId) async {
    calledMethods.add('votePoll');
    methodArgs['votePoll'] = {
      'chatGroupId': chatGroupId,
      'pollId': pollId,
      'option': option,
      'voterId': voterId
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<Map<String, Poll>> getActivePolls(String chatGroupId) async {
    calledMethods.add('getActivePolls');
    methodArgs['getActivePolls'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return {};
  }

  @override
  Future<String> uploadMedia(String filePath, String mediaType) async {
    calledMethods.add('uploadMedia');
    methodArgs['uploadMedia'] = {'filePath': filePath, 'mediaType': mediaType};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return 'mock_media_url';
  }

  @override
  Future<ChatGroup> createGroup(String name, bool isPublic,
      {String? description}) async {
    calledMethods.add('createGroup');
    methodArgs['createGroup'] = {
      'name': name,
      'isPublic': isPublic,
      'description': description
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return ChatGroup(
      id: 'mock_group_id',
      name: name,
      memberUids: ['mock_user'],
      isPublic: isPublic,
      memberCount: 1,
      createdBy: 'mock_user',
      createdAt: DateTime.now(),
      description: description,
    );
  }

  @override
  Future<void> joinGroup(String groupId) async {
    calledMethods.add('joinGroup');
    methodArgs['joinGroup'] = {'groupId': groupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    calledMethods.add('leaveGroup');
    methodArgs['leaveGroup'] = {'groupId': groupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<List<ChatGroup>> discoverGroups(
      {String? query, int limit = 20}) async {
    calledMethods.add('discoverGroups');
    methodArgs['discoverGroups'] = {'query': query, 'limit': limit};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return [];
  }

  @override
  Future<List<ChatGroup>> getUserGroups() async {
    calledMethods.add('getUserGroups');
    methodArgs['getUserGroups'] = {};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return [];
  }

  @override
  Future<void> updateTypingIndicator(String chatGroupId, bool isTyping) async {
    calledMethods.add('updateTypingIndicator');
    methodArgs['updateTypingIndicator'] = {
      'chatGroupId': chatGroupId,
      'isTyping': isTyping
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> pinMessage(String chatGroupId, String messageId) async {
    calledMethods.add('pinMessage');
    methodArgs['pinMessage'] = {
      'chatGroupId': chatGroupId,
      'messageId': messageId
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> unpinMessage(String chatGroupId, String messageId) async {
    calledMethods.add('unpinMessage');
    methodArgs['unpinMessage'] = {
      'chatGroupId': chatGroupId,
      'messageId': messageId
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<List<String>> getPinnedMessages(String chatGroupId) async {
    calledMethods.add('getPinnedMessages');
    methodArgs['getPinnedMessages'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getMediaHistory(String chatGroupId) async {
    calledMethods.add('getMediaHistory');
    methodArgs['getMediaHistory'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return [];
  }

  @override
  Future<List<Message>> searchMessages(String chatGroupId, String query) async {
    calledMethods.add('searchMessages');
    methodArgs['searchMessages'] = {'chatGroupId': chatGroupId, 'query': query};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return [];
  }

  @override
  Future<void> closePoll(String chatGroupId, String pollId) async {
    calledMethods.add('closePoll');
    methodArgs['closePoll'] = {'chatGroupId': chatGroupId, 'pollId': pollId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> deleteMedia(String mediaUrl) async {
    calledMethods.add('deleteMedia');
    methodArgs['deleteMedia'] = {'mediaUrl': mediaUrl};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> updateGroupSettings(
      String groupId, Map<String, dynamic> settings) async {
    calledMethods.add('updateGroupSettings');
    methodArgs['updateGroupSettings'] = {
      'groupId': groupId,
      'settings': settings
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<Map<String, Set<String>>> getTypingIndicators(
      String chatGroupId) async {
    calledMethods.add('getTypingIndicators');
    methodArgs['getTypingIndicators'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return {};
  }

  @override
  Future<String> getAiResponse(
      String chatGroupId, String userMessage, String context) async {
    calledMethods.add('getAiResponse');
    methodArgs['getAiResponse'] = {
      'chatGroupId': chatGroupId,
      'userMessage': userMessage,
      'context': context
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return 'Mock AI response';
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingMessages() async {
    calledMethods.add('getPendingMessages');
    methodArgs['getPendingMessages'] = {};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return [];
  }

  @override
  Future<void> markMessagesAsRead(
      String chatGroupId, DateTime timestamp) async {
    calledMethods.add('markMessagesAsRead');
    methodArgs['markMessagesAsRead'] = {
      'chatGroupId': chatGroupId,
      'timestamp': timestamp
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> trackMessageAnalytics(
      String chatGroupId, String messageId, String event) async {
    calledMethods.add('trackMessageAnalytics');
    methodArgs['trackMessageAnalytics'] = {
      'chatGroupId': chatGroupId,
      'messageId': messageId,
      'event': event
    };

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getChatAnalytics(String chatGroupId) async {
    calledMethods.add('getChatAnalytics');
    methodArgs['getChatAnalytics'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return {};
  }

  @override
  Future<void> startVoiceChat(String chatGroupId) async {
    calledMethods.add('startVoiceChat');
    methodArgs['startVoiceChat'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> endVoiceChat(String chatGroupId) async {
    calledMethods.add('endVoiceChat');
    methodArgs['endVoiceChat'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> joinVoiceChat(String chatGroupId) async {
    calledMethods.add('joinVoiceChat');
    methodArgs['joinVoiceChat'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<void> leaveVoiceChat(String chatGroupId) async {
    calledMethods.add('leaveVoiceChat');
    methodArgs['leaveVoiceChat'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }
  }

  @override
  Future<List<String>> getVoiceChatParticipants(String chatGroupId) async {
    calledMethods.add('getVoiceChatParticipants');
    methodArgs['getVoiceChatParticipants'] = {'chatGroupId': chatGroupId};

    if (shouldThrowException) {
      throw exceptionToThrow;
    }

    return [];
  }
}
