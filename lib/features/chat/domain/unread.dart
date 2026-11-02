/// Unread counts keyed by chat id.
class UnreadBook {
  const UnreadBook([this.counts = const {}]);

  final Map<String, int> counts;

  int of(String chatId) => counts[chatId] ?? 0;

  UnreadBook add(String chatId, int by) {
    if (chatId.isEmpty || by <= 0) return this;
    return UnreadBook({...counts, chatId: of(chatId) + by});
  }

  /// Opening [chatId] zeros that chat and leaves every other chat alone.
  UnreadBook opened(String chatId) {
    if (chatId.isEmpty || !counts.containsKey(chatId)) return this;
    return UnreadBook({...counts, chatId: 0});
  }

  @override
  bool operator ==(Object other) {
    if (other is! UnreadBook || other.counts.length != counts.length) {
      return false;
    }
    for (final entry in counts.entries) {
      if (other.counts[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final keys = counts.keys.toList()..sort();
    return Object.hashAll([
      for (final key in keys) Object.hash(key, counts[key]),
    ]);
  }
}

/// Messages from other people count only while that chat is closed.
/// The viewer's own rows never count.
int unreadArrivals({
  required Iterable<String> senderIds,
  required String currentUserId,
  required bool chatIsOpen,
}) {
  if (chatIsOpen) return 0;
  var count = 0;
  for (final sender in senderIds) {
    if (sender.isEmpty || sender == currentUserId) continue;
    count++;
  }
  return count;
}
