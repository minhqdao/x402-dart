import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('RouteConfig', () {
    test('requires at least one payment option', () {
      expect(
        () => RouteConfig(accepts: []),
        throwsA(isA<AssertionError>()),
      );
    });

    test('constructor sets fields correctly', () {
      const option = PaymentOption(
        scheme: 'exact',
        payTo: '0x123',
        price: Money('1.0'),
        network: Network(namespace: 'n', reference: 'r'),
      );
      final config = RouteConfig(
        accepts: [option],
        resource: 'res1',
        description: 'desc1',
        mimeType: 'application/json',
        customPaywallHtml: '<html></html>',
        extensions: {'ext': 'val'},
      );

      expect(config.accepts, [option]);
      expect(config.resource, 'res1');
      expect(config.description, 'desc1');
      expect(config.mimeType, 'application/json');
      expect(config.customPaywallHtml, '<html></html>');
      expect(config.extensions?['ext'], 'val');
    });
  });
}
