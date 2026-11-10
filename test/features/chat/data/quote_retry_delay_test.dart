import 'dart:io';

// fake_async is already required by flutter_test.
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
// http and postgrest come in through supabase_flutter.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart';
// ignore: depend_on_referenced_packages
import 'package:postgrest/postgrest.dart';

/// Throws on every attempt. PostgREST retries GET network errors.
class _SocketClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    throw const SocketException('failed host lookup');
  }
}

void main() {
  test('a socket failure waits through the default 7 second retry backoff', () {
    fakeAsync((async) {
      final client = PostgrestClient(
        'http://localhost:3000',
        httpClient: _SocketClient(),
      );
      var settled = false;
      client
          .from('sq8_messages')
          .select('id, body')
          .inFilter('id', ['m1'])
          .then((_) => settled = true, onError: (_) => settled = true);

      async.flushMicrotasks();
      expect(settled, isFalse);

      // Default delays are 1s, then 2s, then 4s, before the last attempt throws.
      async.elapse(const Duration(seconds: 6));
      expect(settled, isFalse);

      async.elapse(const Duration(seconds: 1));
      expect(settled, isTrue);
    });
  });
}
