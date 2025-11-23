import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:squad_sync/domain/usecases/upload_media.dart';

import '../../helpers/manual_mock_chat.dart';

void main() {
  late UploadMedia usecase;
  late ManualMockChatRepository mockRepository;

  setUp(() {
    mockRepository = ManualMockChatRepository();
    usecase = UploadMedia(mockRepository);
  });

  tearDown(() {
    reset(mockRepository);
    mockRepository.shouldThrowException = false;
    mockRepository.exceptionToThrow = null;
  });

  const testFilePath = '/path/to/image.jpg';
  const testMediaType = 'image/jpeg';

  group('UploadMedia Usecase', () {
    group('Happy Path', () {
      test('should upload image successfully', () async {
        // Act
        final result = await usecase(testFilePath, testMediaType);

        // Assert
        expect(result, isA<String>());
        expect(result, 'mock_media_url');
        expect(mockRepository.calledMethods.contains('uploadMedia'), isTrue);
        expect(
            mockRepository.methodArgs['uploadMedia']['filePath'], testFilePath);
        expect(mockRepository.methodArgs['uploadMedia']['mediaType'],
            testMediaType);
      });

      test('should upload video successfully', () async {
        // Arrange
        const videoPath = '/path/to/video.mp4';
        const videoType = 'video/mp4';

        // Act
        final result = await usecase(videoPath, videoType);

        // Assert
        expect(result, isA<String>());
        expect(mockRepository.calledMethods.contains('uploadMedia'), isTrue);
        expect(mockRepository.methodArgs['uploadMedia']['filePath'], videoPath);
        expect(
            mockRepository.methodArgs['uploadMedia']['mediaType'], videoType);
      });
    });

    group('Error Path', () {
      test('should throw exception when repository fails', () async {
        // Arrange
        final exception = Exception('Failed to upload media');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase(testFilePath, testMediaType),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('uploadMedia'), isTrue);
      });

      test('should throw exception for invalid file path', () async {
        // Arrange
        final exception = Exception('File not found');
        mockRepository.shouldThrowException = true;
        mockRepository.exceptionToThrow = exception;

        // Act & Assert
        expect(
          () => usecase('/invalid/path.jpg', testMediaType),
          throwsA(exception),
        );
        expect(mockRepository.calledMethods.contains('uploadMedia'), isTrue);
        expect(mockRepository.methodArgs['uploadMedia']['filePath'],
            '/invalid/path.jpg');
      });
    });

    group('Edge Cases', () {
      test('should handle empty file path', () async {
        // Act
        final result = await usecase('', testMediaType);

        // Assert
        expect(result, isA<String>());
        expect(mockRepository.calledMethods.contains('uploadMedia'), isTrue);
        expect(mockRepository.methodArgs['uploadMedia']['filePath'], '');
      });

      test('should handle large file upload', () async {
        // Arrange
        const largeFilePath = '/path/to/large_video.mp4';

        // Act
        final result = await usecase(largeFilePath, 'video/mp4');

        // Assert
        expect(result, isA<String>());
        expect(mockRepository.calledMethods.contains('uploadMedia'), isTrue);
        expect(mockRepository.methodArgs['uploadMedia']['filePath'],
            largeFilePath);
      });

      test('should handle unsupported media type', () async {
        // Act
        final result = await usecase(testFilePath, 'application/octet-stream');

        // Assert
        expect(result, isA<String>());
        expect(mockRepository.calledMethods.contains('uploadMedia'), isTrue);
        expect(mockRepository.methodArgs['uploadMedia']['mediaType'],
            'application/octet-stream');
      });
    });
  });
}
