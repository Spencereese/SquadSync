/// One realtime topic for the signed-in person.
/// No squad yet: their own member row. In a squad: that squad's rows.
String rosterTopic({String? squadId, required String userId}) {
  if (squadId == null || squadId.isEmpty) return 'sq8-seat-$userId';
  return 'sq8-squad-$squadId';
}

/// Tracks the open channel so a reconnect does not leave the old one running.
class RosterChannel {
  RosterChannel({required this.attach, required this.detach});

  final void Function(String topic) attach;
  final void Function(String topic) detach;

  String? topic;

  void bind({String? squadId, required String userId}) {
    final next = rosterTopic(squadId: squadId, userId: userId);
    if (topic == next) return;
    final previous = topic;
    if (previous != null) detach(previous);
    topic = next;
    attach(next);
  }

  void resubscribe() {
    final current = topic;
    if (current == null) return;
    detach(current);
    attach(current);
  }

  void dispose() {
    final current = topic;
    topic = null;
    if (current != null) detach(current);
  }
}
