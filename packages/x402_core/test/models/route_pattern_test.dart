import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('RoutePattern', () {
    test('normalizes path with leading slash', () {
      const p1 = RoutePattern(HttpMethod.get, 'protected');
      expect(p1.normalizedPath, '/protected');

      const p2 = RoutePattern(HttpMethod.get, '/protected');
      expect(p2.normalizedPath, '/protected');
    });

    test('key combines method and normalized path', () {
      const pattern = RoutePattern(HttpMethod.post, 'submit');
      expect(pattern.key, 'POST /submit');
    });

    test('equality and hashCode based on method and normalized path', () {
      const p1 = RoutePattern(HttpMethod.get, 'test');
      const p2 = RoutePattern(HttpMethod.get, '/test');
      const p3 = RoutePattern(HttpMethod.post, '/test');

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p1, isNot(equals(p3)));
    });

    test('toString returns key', () {
      const pattern = RoutePattern(HttpMethod.get, '/test');
      expect(pattern.toString(), 'GET /test');
    });
  });
}
