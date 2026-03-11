import 'dart:convert';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  const resource = ResourceInfo(
    url: 'https://api.example.com/data',
    description: 'Access to data',
    mimeType: 'application/json',
  );

  final validRequirement = PaymentRequirement(
    scheme: 'exact',
    network: const Network(namespace: 'eip155', reference: '8453'),
    amount: '10000',
    payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
    maxTimeoutSeconds: 60,
    asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    extra: const {},
  );

  group('PaymentRequiredResponse JSON Serialization', () {
    test('should serialize to and from JSON with valid requirements', () {
      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [validRequirement],
      );

      final json = response.toJson();
      final deserialized = PaymentRequiredResponse.fromJson(json);

      expect(deserialized.x402Version, equals(kX402Version));
      expect(deserialized.resource.url, equals(resource.url));
      expect(deserialized.accepts.length, equals(1));
      expect(
          deserialized.accepts.first.scheme, equals(validRequirement.scheme));
      expect(deserialized.error, isNull);
      expect(deserialized.extensions, isNull);
    });

    test('should handle extensions during round-trip', () {
      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [validRequirement],
        extensions: const {'promo': 'early_bird_2026'},
      );

      final json =
          jsonDecode(jsonEncode(response.toJson())) as Map<String, dynamic>;
      final deserialized = PaymentRequiredResponse.fromJson(json);

      expect(deserialized.extensions, equals({'promo': 'early_bird_2026'}));
    });

    test('should serialize to and from JSON with multiple requirements', () {
      final req2 = validRequirement.copyWith(scheme: 'v2:solana:exact');
      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [validRequirement, req2],
      );

      final json = response.toJson();
      final deserialized = PaymentRequiredResponse.fromJson(json);

      expect(deserialized.accepts.length, equals(2));
      expect(deserialized.accepts[0].scheme, equals(validRequirement.scheme));
      expect(deserialized.accepts[1].scheme, equals(req2.scheme));
    });

    test('should handle error field', () {
      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [validRequirement],
        error: 'Invalid payment',
      );

      final json = response.toJson();
      expect(json['error'], equals('Invalid payment'));

      final deserialized = PaymentRequiredResponse.fromJson(json);
      expect(deserialized.error, equals('Invalid payment'));
    });

    test('fromJson throws if version is unsupported', () {
      final json = {
        'x402Version': 999,
        'resource': resource.toJson(),
        'accepts': [validRequirement.toJson()],
      };

      expect(
        () => PaymentRequiredResponse.fromJson(json),
        throwsA(isA<InvalidPayloadException>().having(
          (e) => e.message,
          'message',
          contains('Unsupported x402 version'),
        )),
      );
    });

    test('fromJson throws if accepts is empty', () {
      final json = {
        'x402Version': kX402Version,
        'resource': resource.toJson(),
        'accepts': [],
      };

      expect(
        () => PaymentRequiredResponse.fromJson(json),
        throwsA(isA<InvalidPayloadException>().having(
          (e) => e.message,
          'message',
          contains('contains no payment requirements'),
        )),
      );
    });

    test('fromJson throws if resource is missing', () {
      final json = {
        'x402Version': kX402Version,
        'accepts': [validRequirement.toJson()],
      };

      expect(
        () => PaymentRequiredResponse.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('fromJson throws if accepts is not a list', () {
      final json = {
        'x402Version': kX402Version,
        'resource': resource.toJson(),
        'accepts': 'not-a-list',
      };

      expect(
        () => PaymentRequiredResponse.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('fromJson throws if x402Version is wrong type', () {
      final json = {
        'x402Version': '1',
        'resource': resource.toJson(),
        'accepts': [validRequirement.toJson()],
      };

      expect(
        () => PaymentRequiredResponse.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('PaymentRequiredResponse Base64 Header Support', () {
    test('should decode from Base64 header using fromHeader', () {
      final responseJson = {
        'x402Version': kX402Version,
        'resource': resource.toJson(),
        'accepts': [validRequirement.toJson()],
        'error': 'Payment Required',
        'extensions': {'foo': 'bar'}
      };
      final encodedHeader = base64Encode(utf8.encode(jsonEncode(responseJson)));

      final response = PaymentRequiredResponse.fromHeader(encodedHeader);

      expect(response.x402Version, equals(kX402Version));
      expect(response.resource.url, equals(resource.url));
      expect(response.accepts.length, equals(1));
      expect(response.error, equals('Payment Required'));
      expect(response.extensions, equals({'foo': 'bar'}));
    });

    test('fromHeader throws on invalid base64', () {
      expect(
        () => PaymentRequiredResponse.fromHeader('not-base64'),
        throwsA(isA<InvalidPayloadException>()),
      );
    });

    test('fromHeader throws on malformed JSON', () {
      final malformed = base64Encode(utf8.encode('{invalid-json}'));
      expect(
        () => PaymentRequiredResponse.fromHeader(malformed),
        throwsA(isA<InvalidPayloadException>()),
      );
    });
  });

  group('PaymentRequiredResponse Helper Methods', () {
    PaymentRequirement buildReq({
      required String scheme,
      required Network network,
    }) {
      return PaymentRequirement(
        scheme: scheme,
        network: network,
        asset: 'USDC',
        amount: '100',
        payTo: 'address',
        maxTimeoutSeconds: 60,
        extra: const {},
      );
    }

    test('findFirstSupportedBy returns the first supported payment requirement',
        () {
      final req1 = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '1'));
      final req2 = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '137'));

      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [req1, req2],
      );

      final signer = _TestSigner((r) =>
          r.network == const Network(namespace: 'eip155', reference: '137'));

      final result = response.findFirstSupportedBy(signer);

      expect(result, equals(req2));
    });

    test('respects order and returns the first match even if later ones match',
        () {
      final req1 = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '1'));
      final req2 = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '1'));

      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [req1, req2],
      );

      final signer = _TestSigner((_) => true);

      final result = response.findFirstSupportedBy(signer);

      expect(result, same(req1));
    });

    test('returns null when no payment requirements are supported', () {
      final requirement = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '1'));

      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [requirement],
      );

      final signer = _TestSigner((_) => false);

      final result = response.findFirstSupportedBy(signer);

      expect(result, isNull);
    });

    test('calls supports for each requirement until a match is found', () {
      var callCount = 0;

      final req1 = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '1'));
      final req2 = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '137'));

      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [req1, req2],
      );

      final signer = _TestSigner((r) {
        callCount++;
        return r == req2;
      });

      final result = response.findFirstSupportedBy(signer);

      expect(result, equals(req2));
      expect(callCount, equals(2));
    });

    test('does not call supports after the first successful match', () {
      var callCount = 0;

      final req1 = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '1'));
      final req2 = buildReq(
          scheme: 'x402',
          network: const Network(namespace: 'eip155', reference: '137'));

      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [req1, req2],
      );

      final signer = _TestSigner((_) {
        callCount++;
        return true;
      });

      final result = response.findFirstSupportedBy(signer);

      expect(result, same(req1));
      expect(callCount, equals(1));
    });

    test('accepts list is unmodifiable', () {
      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [validRequirement],
      );

      expect(
        () => response.accepts.add(validRequirement),
        throwsUnsupportedError,
      );
    });

    test('extensions map is unmodifiable', () {
      final response = PaymentRequiredResponse(
        x402Version: kX402Version,
        resource: resource,
        accepts: [validRequirement],
        extensions: {'foo': 'bar'},
      );

      expect(
        () => response.extensions!['baz'] = 'qux',
        throwsUnsupportedError,
      );
    });
  });
}

class _TestSigner implements X402Signer {
  final bool Function(PaymentRequirement) _supports;

  _TestSigner(this._supports);

  @override
  bool supports(PaymentRequirement requirement) => _supports(requirement);

  @override
  String get address => throw UnimplementedError();

  @override
  Network get network => throw UnimplementedError();

  @override
  String get scheme => throw UnimplementedError();

  @override
  Future<SignedPayment> sign(
      PaymentRequirement requirement, ResourceInfo resource,
      {Map<String, dynamic>? extensions}) {
    throw UnimplementedError();
  }
}
