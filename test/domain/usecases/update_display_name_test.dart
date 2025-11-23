import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/update_display_name.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late UpdateDisplayName usecase;
  late MockUserRepository mockRepository;

  setUp(() {
    mockRepository = MockUserRepository();
    usecase = UpdateDisplayName(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
  });

  group('UpdateDisplayName Usecase', () {
    const testName = 'New Display Name';

    test('should call repository.updateDisplayName with correct name',
        () async {
      // Arrange
      when(mockRepository.updateDisplayName(testName))
          .thenAnswer((_) async => Future.value());

      // Act
      await usecase(testName);

      // Assert
      verify(mockRepository.updateDisplayName(testName)).called(1);
      verifyNoMoreInteractions(mockRepository);
    });

    test('should propagate repository exceptions', () async {
      // Arrange
      final exception = Exception('Update failed');
      when(mockRepository.updateDisplayName(testName)).thenThrow(exception);

      // Act & Assert
      expect(() => usecase(testName), throwsA(exception));
    });

    test('should handle empty name', () async {
      // Arrange
      const emptyName = '';
      when(mockRepository.updateDisplayName(emptyName))
          .thenAnswer((_) async => Future.value());

      // Act
      await usecase(emptyName);

      // Assert
      verify(mockRepository.updateDisplayName(emptyName)).called(1);
    });

    test('should handle special characters in name', () async {
      // Arrange
      const specialName = 'Test@#\$%^&*()';
      when(mockRepository.updateDisplayName(specialName))
          .thenAnswer((_) async => Future.value());

      // Act
      await usecase(specialName);

      // Assert
      verify(mockRepository.updateDisplayName(specialName)).called(1);
    });
  });
}
