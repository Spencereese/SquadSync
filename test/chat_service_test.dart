import 'package:flutter_test/flutter_test.dart';
import '../lib/chat/link_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Link Preview Tests', () {
    test('should detect URLs in text', () {
      const text =
          'Check out this video: https://youtube.com/watch?v=123 and this tweet: https://twitter.com/user/status/456';
      final urls = LinkDetector.extractUrls(text);
      expect(urls.length, 2);
      expect(urls[0], 'https://youtube.com/watch?v=123');
      expect(urls[1], 'https://twitter.com/user/status/456');
    });

    test('should identify link types correctly', () {
      expect(LinkDetector.getLinkType('https://youtube.com/watch?v=123'),
          LinkType.youtube);
      expect(LinkDetector.getLinkType('https://twitter.com/user/status/456'),
          LinkType.twitter);
      expect(LinkDetector.getLinkType('https://instagram.com/p/123'),
          LinkType.instagram);
      expect(LinkDetector.getLinkType('https://example.com'), LinkType.website);
      expect(LinkDetector.getLinkType('https://example.com/video.mp4'),
          LinkType.videoFile);
    });

    test('should handle text without URLs', () {
      const text = 'This is just plain text without any links';
      final urls = LinkDetector.extractUrls(text);
      expect(urls.isEmpty, true);
    });
  });

  group('Basic functionality', () {
    test('should initialize without errors', () async {
      // Basic test to ensure test framework works
      expect(1 + 1, 2);
    });

    test('string operations work', () {
      const message = 'Hello World';
      expect(message.isNotEmpty, true);
      expect(message.length, 11);
    });

    test('list operations work', () {
      final messages = ['msg1', 'msg2', 'msg3'];
      expect(messages.length, 3);
      expect(messages.contains('msg2'), true);
    });
  });
}
