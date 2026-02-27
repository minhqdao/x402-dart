import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('ResourceConfig', () {
    test('initializes with default timeout', () {
      const config = ResourceConfig(
        scheme: 'exact',
        payTo: '0x123',
        price: Money('1.0'),
        network: Network(namespace: 'eip155', reference: '1'),
      );
      expect(config.maxTimeoutSeconds, 300);
    });

    test('initializes with custom timeout', () {
      const config = ResourceConfig(
        scheme: 'exact',
        payTo: '0x123',
        price: Money('1.0'),
        network: Network(namespace: 'eip155', reference: '1'),
        maxTimeoutSeconds: 600,
      );
      expect(config.maxTimeoutSeconds, 600);
    });
  });
}
