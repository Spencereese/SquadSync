import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/data/datasources/system_local_datasource.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late SystemLocalDataSourceImpl datasource;
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockPrefs = MockSharedPreferences();
    datasource = SystemLocalDataSourceImpl(mockPrefs);
  });

  group('SystemLocalDataSourceImpl', () {
    test('should work', () async {
      expect(true, true);
    });
  });
}
