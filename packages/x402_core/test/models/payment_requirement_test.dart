import 'dart:convert';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('PaymentRequirement Serialization', () {
    test('should serialize to and from JSON', () {
      final requirements = PaymentRequirement(
        scheme: 'exact',
        network: const Network(namespace: 'eip155', reference: '8453'),
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: const {'name': 'USDC', 'version': '2'},
      );

      final json = requirements.toJson();
      final deserialized = PaymentRequirement.fromJson(json);

      expect(deserialized.scheme, equals(requirements.scheme));
      expect(deserialized.network, equals(requirements.network));
      expect(deserialized.amount, equals(requirements.amount));
      expect(deserialized.payTo, equals(requirements.payTo));
      expect(deserialized.asset, equals(requirements.asset));
      expect(deserialized.extra, equals(requirements.extra));
    });

    test('toJson produces expected canonical structure', () {
      final req = PaymentRequirement(
        scheme: 'exact',
        network: const Network(namespace: 'eip155', reference: '1'),
        amount: '42',
        payTo: '0xabc',
        asset: '0xdef',
        maxTimeoutSeconds: 99,
        extra: const {'foo': 'bar'},
      );

      final json = req.toJson();

      expect(
          json.keys.toSet(),
          equals({
            'scheme',
            'network',
            'asset',
            'amount',
            'payTo',
            'maxTimeoutSeconds',
            'extra',
          }));

      expect(json['network'], equals('eip155:1'));
      expect(json['amount'], equals('42'));
    });

    test('fromJson defaults extra to empty map if missing', () {
      final req = PaymentRequirement.fromJson({
        'scheme': 's',
        'network': 'n:r',
        'amount': '1',
        'payTo': 'p',
        'asset': 'a',
        'maxTimeoutSeconds': 0,
      });

      expect(req.extra, isEmpty);
      expect(() => req.extra['x'] = 1, throwsUnsupportedError);
    });

    test('should decode from Base64 header using fromHeader', () {
      const requirementJson = {
        'scheme': 'exact',
        'network': 'eip155:8453',
        'amount': '10000',
        'payTo': '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        'maxTimeoutSeconds': 60,
        'asset': '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        'extra': {'foo': 'bar'}
      };
      final headerValue =
          base64Encode(utf8.encode(jsonEncode(requirementJson)));

      final requirement = PaymentRequirement.fromHeader(headerValue);

      expect(requirement.scheme, equals('exact'));
      expect(requirement.network.identifier, equals('eip155:8453'));
      expect(requirement.amount, equals('10000'));
      expect(requirement.payTo,
          equals('0x209693Bc6afc0C5328bA36FaF03C514EF312287C'));
      expect(requirement.maxTimeoutSeconds, equals(60));
      expect(requirement.asset,
          equals('0x036CbD53842c5426634e7929541eC2318f3dCF7e'));
      expect(requirement.extra, equals({'foo': 'bar'}));
    });

    group('fromJson validation failures', () {
      test('throws if amount is missing', () {
        expect(
          () => PaymentRequirement.fromJson({
            'scheme': 's',
            'network': 'n:r',
            'payTo': 'p',
            'asset': 'a',
            'maxTimeoutSeconds': 0,
          }),
          throwsFormatException,
        );
      });

      test('throws if network is invalid CAIP-2', () {
        expect(
          () => PaymentRequirement.fromJson({
            'scheme': 's',
            'network': 'invalid-network',
            'amount': '1',
            'payTo': 'p',
            'asset': 'a',
            'maxTimeoutSeconds': 0,
          }),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws if maxTimeoutSeconds is not numeric', () {
        expect(
          () => PaymentRequirement.fromJson({
            'scheme': 's',
            'network': 'n:r',
            'amount': '1',
            'payTo': 'p',
            'asset': 'a',
            'maxTimeoutSeconds': 'bad',
          }),
          throwsA(isA<TypeError>()),
        );
      });
    });

    group('Legacy JSON compatibility', () {
      test('supports maxAmountRequired fallback', () {
        final req = PaymentRequirement.fromJson({
          'scheme': 's',
          'network': 'n:r',
          'maxAmountRequired': 123,
          'payTo': 'p',
          'asset': 'a',
          'maxTimeoutSeconds': 0,
        });

        expect(req.amount, equals('123'));
      });

      test('supports data field as fallback for extra', () {
        final req = PaymentRequirement.fromJson({
          'scheme': 's',
          'network': 'n:r',
          'amount': '1',
          'payTo': 'p',
          'asset': 'a',
          'maxTimeoutSeconds': 0,
          'data': {'legacy': true},
        });

        expect(req.extra, equals({'legacy': true}));
      });
    });

    group('fromHeader robustness', () {
      test('throws on invalid base64', () {
        expect(
          () => PaymentRequirement.fromHeader('not-base64'),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws on invalid JSON payload', () {
        final invalidJson = base64Encode(utf8.encode('not-json'));
        expect(
          () => PaymentRequirement.fromHeader(invalidJson),
          throwsA(isA<FormatException>()),
        );
      });
    });

    group('copyWith behavior', () {
      test('replaces individual fields correctly', () {
        final original = PaymentRequirement(
          scheme: 'a',
          network: const Network(namespace: 'n1', reference: 'r1'),
          amount: '1',
          payTo: 'p1',
          asset: 'asset1',
          maxTimeoutSeconds: 10,
          extra: const {'x': 1},
        );

        final updated = original.copyWith(
          scheme: 'b',
          network: const Network(namespace: 'n2', reference: 'r2'),
          amount: '2',
          payTo: 'p2',
          asset: 'asset2',
          maxTimeoutSeconds: 20,
          extra: const {'y': 2},
        );

        expect(updated.scheme, equals('b'));
        expect(updated.network.identifier, equals('n2:r2'));
        expect(updated.amount, equals('2'));
        expect(updated.payTo, equals('p2'));
        expect(updated.asset, equals('asset2'));
        expect(updated.maxTimeoutSeconds, equals(20));
        expect(updated.extra, equals({'y': 2}));

        // Ensure original unchanged
        expect(original.scheme, equals('a'));
      });

      test('copyWith without parameters returns equal object', () {
        final original = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: const {'x': 1},
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy.hashCode, equals(original.hashCode));
      });
    });
  });

  group('PaymentRequirement Equality and Hashing', () {
    test('equality and hashCode should work correctly', () {
      final req1 = PaymentRequirement(
        scheme: 'exact',
        network: const Network(namespace: 'eip155', reference: '1'),
        amount: '100',
        payTo: '0x1',
        asset: '0xA',
        maxTimeoutSeconds: 60,
        extra: const {'foo': 'bar'},
      );
      final req2 = PaymentRequirement(
        scheme: 'exact',
        network: const Network(namespace: 'eip155', reference: '1'),
        amount: '100',
        payTo: '0x1',
        asset: '0xA',
        maxTimeoutSeconds: 60,
        extra: const {'foo': 'bar'},
      );
      final req3 = PaymentRequirement(
        scheme: 'other',
        network: const Network(namespace: 'eip155', reference: '1'),
        amount: '100',
        payTo: '0x1',
        asset: '0xA',
        maxTimeoutSeconds: 60,
        extra: const {'foo': 'bar'},
      );
      final req4 = PaymentRequirement(
        scheme: 'exact',
        network: const Network(namespace: 'eip155', reference: '1'),
        amount: '100',
        payTo: '0x1',
        asset: '0xA',
        maxTimeoutSeconds: 60,
        extra: const {'foo': 'baz'}, // Different extra
      );

      expect(req1, equals(req2));
      expect(req1.hashCode, equals(req2.hashCode));

      expect(req1, isNot(equals(req3)));
      expect(req1, isNot(equals(req4)));
    });

    group('Deep Equality and HashCode (extra field challenges)', () {
      test('should handle nested maps with different key order', () {
        final req1 = PaymentRequirement(
          scheme: 'exact',
          network: const Network(namespace: 'eip155', reference: '1'),
          amount: '100',
          payTo: '0x1',
          asset: '0xA',
          maxTimeoutSeconds: 60,
          extra: const {
            'a': {'b': 1, 'c': 2},
            'd': 3,
          },
        );
        final req2 = PaymentRequirement(
          scheme: 'exact',
          network: const Network(namespace: 'eip155', reference: '1'),
          amount: '100',
          payTo: '0x1',
          asset: '0xA',
          maxTimeoutSeconds: 60,
          extra: const {
            'd': 3,
            'a': {'c': 2, 'b': 1},
          },
        );

        expect(req1, equals(req2));
        expect(req1.hashCode, equals(req2.hashCode));
      });

      test('should handle nested lists where order matters', () {
        final req1 = PaymentRequirement(
          scheme: 'exact',
          network: const Network(namespace: 'eip155', reference: '1'),
          amount: '100',
          payTo: '0x1',
          asset: '0xA',
          maxTimeoutSeconds: 60,
          extra: const {
            'list': [1, 2, 3]
          },
        );
        final req2 = PaymentRequirement(
          scheme: 'exact',
          network: const Network(namespace: 'eip155', reference: '1'),
          amount: '100',
          payTo: '0x1',
          asset: '0xA',
          maxTimeoutSeconds: 60,
          extra: const {
            'list': [1, 3, 2]
          },
        );

        expect(req1, isNot(equals(req2)));
        // Hash collision is theoretically possible but highly unlikely for these inputs
        expect(req1.hashCode, isNot(equals(req2.hashCode)));
      });

      test('should handle mixed nested structures', () {
        const extra1 = {
          'map': {
            'list': [
              {'a': 1},
              {'b': 2}
            ]
          }
        };
        const extra2 = {
          'map': {
            'list': [
              {'a': 1},
              {'b': 2}
            ]
          }
        };
        const extra3 = {
          'map': {
            'list': [
              {'b': 2},
              {'a': 1}
            ]
          }
        };

        final req1 = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: extra1,
        );
        final req2 = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: extra2,
        );
        final req3 = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: extra3,
        );

        expect(req1, equals(req2));
        expect(req1.hashCode, equals(req2.hashCode));
        expect(req1, isNot(equals(req3)));
      });

      test('should distinguish between different types', () {
        final req1 = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: const {'val': 1},
        );
        final req2 = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: const {'val': '1'},
        );

        expect(req1, isNot(equals(req2)));
      });

      test('should handle null values in collections', () {
        final req1 = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: const {
            'val': null,
            'list': [null]
          },
        );
        final req2 = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: const {
            'val': null,
            'list': [null]
          },
        );

        expect(req1, equals(req2));
        expect(req1.hashCode, equals(req2.hashCode));
      });
    });

    group('Equality contract correctness', () {
      test('equality is symmetric', () {
        final a = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: const {'x': 1},
        );

        final b = a.copyWith();

        expect(a == b, isTrue);
        expect(b == a, isTrue);
      });

      test('equality is transitive', () {
        final a = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: const {'x': 1},
        );

        final b = a.copyWith();
        final c = b.copyWith();

        expect(a == b, isTrue);
        expect(b == c, isTrue);
        expect(a == c, isTrue);
      });

      test('hashCode remains stable', () {
        final req = PaymentRequirement(
          scheme: 's',
          network: const Network(namespace: 'n', reference: 'r'),
          amount: '1',
          payTo: 'p',
          asset: 'a',
          maxTimeoutSeconds: 0,
          extra: const {'x': 1},
        );

        final first = req.hashCode;
        final second = req.hashCode;

        expect(first, equals(second));
      });
    });
  });

  group('PaymentRequirement Immutability and Defensive Copying', () {
    test('constructor defensively copies extra map', () {
      final original = <String, dynamic>{'a': 1};
      final req = PaymentRequirement(
        scheme: 's',
        network: const Network(namespace: 'n', reference: 'r'),
        amount: '1',
        payTo: 'p',
        asset: 'a',
        maxTimeoutSeconds: 0,
        extra: original,
      );

      original['a'] = 2;

      expect(req.extra['a'], equals(1));
    });

    test('extra map is unmodifiable', () {
      final req = PaymentRequirement(
        scheme: 's',
        network: const Network(namespace: 'n', reference: 'r'),
        amount: '1',
        payTo: 'p',
        asset: 'a',
        maxTimeoutSeconds: 0,
        extra: const {'a': 1},
      );

      expect(() => req.extra['a'] = 2, throwsUnsupportedError);
    });

    test('copyWith defensively copies extra map', () {
      final original = <String, dynamic>{'x': 1};

      final req = PaymentRequirement(
        scheme: 's',
        network: const Network(namespace: 'n', reference: 'r'),
        amount: '1',
        payTo: 'p',
        asset: 'a',
        maxTimeoutSeconds: 0,
        extra: const {'a': 1},
      );

      final copied = req.copyWith(extra: original);

      original['x'] = 99;

      expect(copied.extra['x'], equals(1));
    });
  });
}
