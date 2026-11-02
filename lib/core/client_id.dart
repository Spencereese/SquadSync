import 'dart:math';

/// One id for each outgoing message. Tests pass a fixed sequence.
abstract class ClientIdFactory {
  String create();
}

class RandomClientIdFactory implements ClientIdFactory {
  RandomClientIdFactory({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  @override
  String create() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class SequenceClientIdFactory implements ClientIdFactory {
  SequenceClientIdFactory(this._ids);

  final List<String> _ids;
  var _index = 0;

  @override
  String create() {
    if (_index >= _ids.length) {
      throw StateError('SequenceClientIdFactory ran out of ids');
    }
    return _ids[_index++];
  }
}
