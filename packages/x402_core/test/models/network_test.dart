import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('Network', () {
    test('constructor sets namespace and reference', () {
      const network = Network(namespace: 'solana', reference: 'mainnet');
      expect(network.namespace, equals('solana'));
      expect(network.reference, equals('mainnet'));
    });

    group('parse', () {
      test('successfully parses valid CAIP-2 strings', () {
        final ethereum = Network.parse('eip155:1');
        expect(ethereum.namespace, equals('eip155'));
        expect(ethereum.reference, equals('1'));

        final solana = Network.parse(
            'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d');
        expect(solana.namespace, equals('solana'));
        expect(solana.reference,
            equals('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d'));
      });

      test('throws FormatException for invalid strings', () {
        expect(() => Network.parse('invalid'), throwsFormatException);
        expect(() => Network.parse(':reference'), throwsFormatException);
        expect(() => Network.parse('namespace:'), throwsFormatException);
        expect(() => Network.parse(''), throwsFormatException);
      });

      test('parse round-trips with toString', () {
        const original = Network(namespace: 'eip155', reference: '8453');
        final parsed = Network.parse(original.toString());
        expect(parsed, equals(original));
      });
    });

    test('identifier returns canonical string', () {
      const network = Network(namespace: 'eip155', reference: '8453');
      expect(network.identifier, equals('eip155:8453'));
    });

    test('toString returns identifier', () {
      const network = Network(namespace: 'eip155', reference: '8453');
      expect(network.toString(), equals('eip155:8453'));
      expect(network.toString(), equals(network.identifier));
    });

    group('equality and hashCode', () {
      test('instances with same values are equal', () {
        const n1 = Network(namespace: 'a', reference: 'b');
        const n2 = Network(namespace: 'a', reference: 'b');
        const n3 = Network(namespace: 'a', reference: 'c');

        expect(n1, equals(n2));
        expect(n1.hashCode, equals(n2.hashCode));
        expect(n1, isNot(equals(n3)));
      });

      test('equality is case-sensitive', () {
        const n1 = Network(namespace: 'eip155', reference: '1');
        const n2 = Network(namespace: 'EIP155', reference: '1');

        expect(n1, isNot(equals(n2)));
      });

      test('identical instances are equal', () {
        const n1 = Network(namespace: 'eip155', reference: '1');
        expect(n1, equals(n1));
        expect(identical(n1, n1), isTrue);
      });

      test('can be used in Sets and Maps', () {
        const n1 = Network(namespace: 'eip155', reference: '1');
        const n2 = Network(namespace: 'eip155', reference: '1');
        const n3 = Network(namespace: 'eip155', reference: '2');

        // Build set dynamically to avoid const duplicate warning
        final set = <Network>{};
        set.add(n1);
        set.add(n2); // Should not increase size since n1 == n2
        set.add(n3);
        expect(set.length, equals(2)); // n1 and n2 are deduplicated

        final map = <Network, String>{};
        map[n1] = 'first';
        map[n3] = 'second';
        expect(
            map[n2], equals('first')); // n2 equals n1, so retrieves same value
        expect(map.length, equals(2));
      });
    });
  });
}
