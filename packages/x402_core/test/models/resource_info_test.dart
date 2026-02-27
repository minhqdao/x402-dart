import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('ResourceInfo', () {
    const json = {
      'url': 'https://example.com',
      'description': 'Test resource',
      'mimeType': 'application/json',
    };

    test('fromJson', () {
      final info = ResourceInfo.fromJson(json);
      expect(info.url, 'https://example.com');
      expect(info.description, 'Test resource');
      expect(info.mimeType, 'application/json');
    });

    test('toJson', () {
      const info = ResourceInfo(
        url: 'https://example.com',
        description: 'Test resource',
        mimeType: 'application/json',
      );
      expect(info.toJson(), json);
    });
  });
}
