import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('PaymentRequirement', () {
    test('should serialize to and from JSON', () {
      const requirements = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {'name': 'USDC', 'version': '2'},
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
  });

  group('PaymentPayload', () {
    test('should serialize to and from JSON', () {
      const resource = ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Access to premium data',
        mimeType: 'application/json',
      );
      const requirement = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {},
      );
      const payload = PaymentPayload(
        x402Version: 2,
        resource: resource,
        accepted: requirement,
        payload: {
          'signature': '0x123...',
          'authorization': {
            'from': '0xabc...',
            'to': '0xdef...',
            'value': '10000'
          },
        },
      );

      final json = payload.toJson();
      final deserialized = PaymentPayload.fromJson(json);

      expect(deserialized.x402Version, equals(payload.x402Version));
      expect(deserialized.accepted.scheme, equals(payload.accepted.scheme));
      expect(deserialized.accepted.network, equals(payload.accepted.network));
      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.payload['signature'], equals('0x123...'));
    });
  });

  group('PaymentRequiredResponse', () {
    test('should serialize to and from JSON', () {
      const resource = ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Access to data',
        mimeType: 'application/json',
      );
      const response = PaymentRequiredResponse(
        x402Version: 2,
        resource: resource,
        accepts: [
          PaymentRequirement(
            scheme: 'exact',
            network: 'eip155:8453',
            amount: '10000',
            payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
            maxTimeoutSeconds: 60,
            asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
            extra: {},
          ),
        ],
      );

      final json = response.toJson();
      final deserialized = PaymentRequiredResponse.fromJson(json);

      expect(deserialized.x402Version, equals(response.x402Version));
      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.accepts.length, equals(1));
      expect(deserialized.accepts.first.scheme, equals('exact'));
    });

    test('should handle error field', () {
      const resource = ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Access to data',
        mimeType: 'application/json',
      );
      const response = PaymentRequiredResponse(
        x402Version: 2,
        resource: resource,
        accepts: [],
        error: 'Invalid payment',
      );

      final json = response.toJson();
      expect(json['error'], equals('Invalid payment'));

      final deserialized = PaymentRequiredResponse.fromJson(json);
      expect(deserialized.error, equals('Invalid payment'));
    });
  });

  group('Constants', () {
    test('should have correct values', () {
      expect(kX402Version, equals(2));
      expect(kPaymentHeader, equals('X-PAYMENT'));
      expect(kPaymentRequiredStatus, equals(402));
    });
  });

  group('Exceptions', () {
    test('should format messages correctly', () {
      const exception = X402Exception('Something went wrong');
      expect(
          exception.toString(), equals('X402Exception: Something went wrong'));

      const exceptionWithCode =
          X402Exception('Invalid payload', code: 'INVALID_PAYLOAD');
      expect(exceptionWithCode.toString(),
          equals('X402Exception [INVALID_PAYLOAD]: Invalid payload'));
    });

    test('should support specialized exceptions', () {
      expect(const InvalidPayloadException('Invalid'), isA<X402Exception>());
      expect(const UnsupportedSchemeException('Unsupported'),
          isA<X402Exception>());
    });
  });
}
