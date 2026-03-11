import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('SupportedKind', () {
    const json = {
      'x402Version': 2,
      'scheme': 'exact',
      'network': 'solana:123',
      'extra': {'feePayer': 'abc'},
    };

    test('fromJson', () {
      final kind = SupportedKind.fromJson(json);
      expect(kind.x402Version, 2);
      expect(kind.scheme, 'exact');
      expect(kind.network.identifier, 'solana:123');
      expect(kind.extra?['feePayer'], 'abc');
    });

    test('toJson', () {
      const kind = SupportedKind(
        x402Version: 2,
        scheme: 'exact',
        network: Network(namespace: 'solana', reference: '123'),
        extra: {'feePayer': 'abc'},
      );
      expect(kind.toJson(), json);
    });
  });
}
