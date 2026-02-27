import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  const resource = ResourceInfo(
    url: 'https://api.example.com/data',
    description: 'Access to premium data',
    mimeType: 'application/json',
  );

  final requirement = PaymentRequirement(
    scheme: 'exact',
    network: const Network(namespace: 'eip155', reference: '8453'),
    amount: '10000',
    payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
    maxTimeoutSeconds: 60,
    asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    extra: const {},
  );

  Map<String, dynamic> buildValidJson() {
    return {
      'x402Version': 2,
      'resource': resource.toJson(),
      'accepted': requirement.toJson(),
      'payload': {
        'signature': '0x123...',
        'authorization': {
          'from': '0xabc...',
          'to': '0xdef...',
          'value': '10000'
        },
      },
      'extensions': {
        'trackerId': 'xyz-789',
      },
    };
  }

  group('PaymentPayload — happy path', () {
    test('serializes to and from JSON with all fields', () {
      final payload = PaymentPayload.fromJson(buildValidJson());
      final json = payload.toJson();
      final deserialized = PaymentPayload.fromJson(json);

      expect(deserialized.x402Version, equals(2));
      expect(deserialized.payload, equals(payload.payload));
      expect(deserialized.extensions, equals(payload.extensions));

      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.resource.description, equals(resource.description));
      expect(deserialized.resource.mimeType, equals(resource.mimeType));

      expect(deserialized.accepted.scheme, equals(requirement.scheme));
      expect(deserialized.accepted.network, equals(requirement.network));
      expect(deserialized.accepted.amount, equals(requirement.amount));
      expect(deserialized.accepted.payTo, equals(requirement.payTo));
      expect(deserialized.accepted.asset, equals(requirement.asset));
      expect(deserialized.accepted.maxTimeoutSeconds,
          equals(requirement.maxTimeoutSeconds));
      expect(deserialized.accepted.extra, equals(requirement.extra));
    });

    test('preserves nested payload structure', () {
      final payload = PaymentPayload.fromJson(buildValidJson());

      final auth = payload.payload['authorization'] as Map<String, dynamic>;

      expect(auth['from'], equals('0xabc...'));
      expect(auth['to'], equals('0xdef...'));
      expect(auth['value'], equals('10000'));
    });

    test('extensions can be null', () {
      final json = buildValidJson()..remove('extensions');

      final payload = PaymentPayload.fromJson(json);

      expect(payload.extensions, isNull);

      final serialized = payload.toJson();
      expect(serialized.containsKey('extensions'), isFalse);
    });
  });

  group('PaymentPayload — JSON validation', () {
    test('throws if payload is missing', () {
      final json = buildValidJson()..remove('payload');

      expect(
        () => PaymentPayload.fromJson(json),
        throwsA(isA<Exception>()),
      );
    });

    test('throws if payload is not a map', () {
      final json = buildValidJson()..['payload'] = 'invalid';

      expect(
        () => PaymentPayload.fromJson(json),
        throwsA(isA<Exception>()),
      );
    });

    test('throws if extensions is not a map', () {
      final json = buildValidJson()..['extensions'] = 'invalid';

      expect(
        () => PaymentPayload.fromJson(json),
        throwsA(isA<Exception>()),
      );
    });

    test('throws if resource is not a map', () {
      final json = buildValidJson()..['resource'] = 'invalid';

      expect(
        () => PaymentPayload.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('throws if accepted is not a map', () {
      final json = buildValidJson()..['accepted'] = 'invalid';

      expect(
        () => PaymentPayload.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('PaymentPayload — immutability safety', () {
    test('mutating original input map does not affect instance', () {
      final json = buildValidJson();
      final payload = PaymentPayload.fromJson(json);

      (json['payload'] as Map<String, dynamic>)['signature'] = 'tampered';

      expect(
        payload.payload['signature'],
        equals('0x123...'),
      );
    });

    test('toJson result is unmodifiable', () {
      final payload = PaymentPayload.fromJson(buildValidJson());
      final json = payload.toJson();

      expect(() => json['x402Version'] = 1, throwsUnsupportedError);
      expect(
        () =>
            (json['payload'] as Map<String, dynamic>)['signature'] = 'tampered',
        throwsUnsupportedError,
      );
    });
  });

  group('PaymentPayload — structural integrity', () {
    test('round-trip JSON is structurally identical', () {
      final originalJson = buildValidJson();

      final payload = PaymentPayload.fromJson(originalJson);
      final roundTrip = payload.toJson();

      expect(roundTrip, equals(originalJson));
    });

    test('x402Version must be preserved exactly', () {
      final json = buildValidJson()..['x402Version'] = 999;

      final payload = PaymentPayload.fromJson(json);

      expect(payload.x402Version, equals(999));
    });
  });
}
