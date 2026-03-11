import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('PaymentOption', () {
    test('constructor sets fields correctly', () {
      const network = Network(namespace: 'n', reference: 'r');
      const option = PaymentOption(
        scheme: 'exact',
        payTo: '0x123',
        price: Money('1.0'),
        network: network,
        maxTimeoutSeconds: 60,
        extra: {'foo': 'bar'},
      );

      expect(option.scheme, 'exact');
      expect(option.payTo, '0x123');
      expect(option.price, isA<Money>());
      expect(option.network, network);
      expect(option.maxTimeoutSeconds, 60);
      expect(option.extra?['foo'], 'bar');
    });

    test('optional fields can be null', () {
      const option = PaymentOption(
        scheme: 'exact',
        payTo: '0x123',
        price: Money('1.0'),
        network: Network(namespace: 'n', reference: 'r'),
      );
      expect(option.maxTimeoutSeconds, isNull);
      expect(option.extra, isNull);
    });
  });
}
