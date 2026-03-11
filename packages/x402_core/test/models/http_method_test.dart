import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('HttpMethod', () {
    test('values return expected string identifiers', () {
      expect(HttpMethod.get.value, 'GET');
      expect(HttpMethod.post.value, 'POST');
      expect(HttpMethod.put.value, 'PUT');
      expect(HttpMethod.delete.value, 'DELETE');
      expect(HttpMethod.patch.value, 'PATCH');
      expect(HttpMethod.head.value, 'HEAD');
      expect(HttpMethod.options.value, 'OPTIONS');
    });
  });
}
