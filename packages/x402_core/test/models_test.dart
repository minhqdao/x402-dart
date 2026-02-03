import 'dart:convert';
import 'package:test/test.dart';
import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/exceptions/x402_exception.dart';
import 'package:x402_core/src/models/payment_payload.dart';
import 'package:x402_core/src/models/payment_required_response.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

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
      expect(requirement.network, equals('eip155:8453'));
      expect(requirement.amount, equals('10000'));
      expect(requirement.payTo,
          equals('0x209693Bc6afc0C5328bA36FaF03C514EF312287C'));
      expect(requirement.maxTimeoutSeconds, equals(60));
      expect(requirement.asset,
          equals('0x036CbD53842c5426634e7929541eC2318f3dCF7e'));
      expect(requirement.extra, equals({'foo': 'bar'}));
    });
  });

  group('PaymentPayload', () {
    test('should serialize to and from JSON with all fields', () {
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
        extensions: {
          'trackerId': 'xyz-789',
        },
      );

      final json = payload.toJson();
      final deserialized = PaymentPayload.fromJson(json);

      // Verify top-level fields
      expect(deserialized.x402Version, equals(payload.x402Version));
      expect(deserialized.payload, equals(payload.payload));
      expect(deserialized.extensions, equals(payload.extensions));

      // Verify nested ResourceInfo
      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.resource.description, equals(resource.description));
      expect(deserialized.resource.mimeType, equals(resource.mimeType));

      // Verify nested PaymentRequirement
      expect(deserialized.accepted.scheme, equals(requirement.scheme));
      expect(deserialized.accepted.network, equals(requirement.network));
      expect(deserialized.accepted.amount, equals(requirement.amount));
      expect(deserialized.accepted.payTo, equals(requirement.payTo));
      expect(deserialized.accepted.asset, equals(requirement.asset));
      expect(deserialized.accepted.maxTimeoutSeconds,
          equals(requirement.maxTimeoutSeconds));
      expect(deserialized.accepted.extra, equals(requirement.extra));
    });
  });

  group('PaymentRequiredResponse', () {
    const resource = ResourceInfo(
      url: 'https://api.example.com/data',
      description: 'Access to data',
      mimeType: 'application/json',
    );

    test('should serialize to and from JSON with empty accepts', () {
      const response = PaymentRequiredResponse(
        x402Version: 2,
        resource: resource,
        accepts: [],
      );

      final json = response.toJson();
      final deserialized = PaymentRequiredResponse.fromJson(json);

      expect(deserialized.x402Version, equals(2));
      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.resource.description, equals(resource.description));
      expect(deserialized.resource.mimeType, equals(resource.mimeType));
      expect(deserialized.accepts, isEmpty);
      expect(deserialized.error, isNull);
      expect(deserialized.extensions, isNull);
    });

    test(
        'should serialize to and from JSON with one requirement and extensions',
        () {
      const requirement = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {},
      );
      const response = PaymentRequiredResponse(
        x402Version: 2,
        resource: resource,
        accepts: [requirement],
        extensions: {'promo': 'early_bird_2026'},
      );

      final json = response.toJson();
      final deserialized = PaymentRequiredResponse.fromJson(json);

      expect(deserialized.x402Version, equals(2));
      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.accepts.length, equals(1));
      expect(deserialized.accepts.first.scheme, equals(requirement.scheme));
      expect(deserialized.accepts.first.network, equals(requirement.network));
      expect(deserialized.accepts.first.amount, equals(requirement.amount));
      expect(deserialized.extensions, equals({'promo': 'early_bird_2026'}));
      expect(deserialized.error, isNull);
    });

    test('should serialize to and from JSON with two requirements', () {
      const req1 = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x1',
        maxTimeoutSeconds: 60,
        asset: '0xUSDC',
        extra: {},
      );
      const req2 = PaymentRequirement(
        scheme: 'v2:solana:exact',
        network: 'solana:mainnet',
        amount: '10000',
        payTo: 'solana_address',
        maxTimeoutSeconds: 60,
        asset: 'solana_usdc',
        extra: {},
      );
      const response = PaymentRequiredResponse(
        x402Version: 2,
        resource: resource,
        accepts: [req1, req2],
      );

      final json = response.toJson();
      final deserialized = PaymentRequiredResponse.fromJson(json);

      expect(deserialized.x402Version, equals(2));
      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.accepts.length, equals(2));

      expect(deserialized.accepts[0].scheme, equals(req1.scheme));
      expect(deserialized.accepts[0].network, equals(req1.network));
      expect(deserialized.accepts[0].payTo, equals(req1.payTo));

      expect(deserialized.accepts[1].scheme, equals(req2.scheme));
      expect(deserialized.accepts[1].network, equals(req2.network));
      expect(deserialized.accepts[1].payTo, equals(req2.payTo));

      expect(deserialized.extensions, isNull);
      expect(deserialized.error, isNull);
    });

    test('should handle error field', () {
      const response = PaymentRequiredResponse(
        x402Version: 2,
        resource: resource,
        accepts: [],
        error: 'Invalid payment',
      );

      final json = response.toJson();
      expect(json['error'], equals('Invalid payment'));

      final deserialized = PaymentRequiredResponse.fromJson(json);
      expect(deserialized.x402Version, equals(2));
      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.accepts, isEmpty);
      expect(deserialized.error, equals('Invalid payment'));
      expect(deserialized.extensions, isNull);
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
    test('X402Exception initializes with message and originalError', () {
      const msg = 'Something went wrong';
      final innerError = Exception('Inner cause');
      final exception = X402Exception(msg, originalError: innerError);

      expect(exception.message, equals(msg));
      expect(exception.originalError, equals(innerError));
      expect(
        exception.toString(),
        equals(
          'X402Exception: $msg, originalError: Exception: Inner cause',
        ),
      );
    });

    test('InvalidPayloadException inherits originalError and prints it', () {
      const innerError = FormatException('Invalid JSON');
      const exception = InvalidPayloadException(
        'Payload invalid',
        originalError: innerError,
      );

      expect(exception, isA<X402Exception>());
      expect(exception.message, equals('Payload invalid'));
      expect(exception.originalError, equals(innerError));
      expect(
        exception.toString(),
        equals(
          'X402Exception: Payload invalid, '
          'originalError: FormatException: Invalid JSON',
        ),
      );
    });

    test('UnsupportedSchemeException inherits originalError and prints it', () {
      final innerError = StateError('Scheme not found');
      final exception = UnsupportedSchemeException(
        'Unknown scheme',
        originalError: innerError,
      );

      expect(exception, isA<X402Exception>());
      expect(exception.message, equals('Unknown scheme'));
      expect(exception.originalError, equals(innerError));
      expect(
        exception.toString(),
        equals(
          'X402Exception: Unknown scheme, '
          'originalError: Bad state: Scheme not found',
        ),
      );
    });
  });
}
