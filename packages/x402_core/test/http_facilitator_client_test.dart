import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  PaymentRequirement mockPaymentRequirement({
    String scheme = 'exact',
    String network = 'eip155:1',
    String asset = '0x123',
    String amount = '100',
    String payTo = '0xabc',
    int maxTimeoutSeconds = 3600,
    Map<String, dynamic> extra = const {},
  }) {
    return PaymentRequirement(
      scheme: scheme,
      network: network,
      asset: asset,
      amount: amount,
      payTo: payTo,
      maxTimeoutSeconds: maxTimeoutSeconds,
      extra: extra,
    );
  }

  ResourceInfo mockResourceInfo({
    String url = 'https://example.com/resource',
    String description = 'A mock resource',
    String mimeType = 'application/json',
  }) {
    return ResourceInfo(
      url: url,
      description: description,
      mimeType: mimeType,
    );
  }

  PaymentPayload mockPaymentPayload({
    int x402Version = 1,
    ResourceInfo? resource,
    PaymentRequirement? accepted,
    Map<String, dynamic> payload = const {},
    Map<String, dynamic>? extensions,
  }) {
    return PaymentPayload(
      x402Version: x402Version,
      resource: resource ?? mockResourceInfo(),
      accepted: accepted ?? mockPaymentRequirement(),
      payload: payload,
      extensions: extensions,
    );
  }

  group('HttpFacilitatorClient.verify', () {
    test('verify sends correct body structure', () async {
      late Map<String, dynamic> decoded;

      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        expect(request.url.path, endsWith('/verify'));
        expect(request.headers['Content-Type'], equals('application/json'));

        decoded = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(jsonEncode({'isValid': true}), 200);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      final payload = mockPaymentPayload();
      final requirement = mockPaymentRequirement();

      await client.verify(payload, requirement);

      expect(decoded['x402Version'], equals(payload.x402Version));
      expect(decoded['paymentPayload'], isA<Map<String, dynamic>>());
      expect(decoded['paymentRequirements'], isA<Map<String, dynamic>>());
    });

    test('throws FacilitatorResponseException on non-200 with valid body', () {
      final mockClient = MockClient((_) async {
        return http.Response(jsonEncode({'isValid': false}), 400);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        () => client.verify(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(isA<FacilitatorResponseException>()),
      );
    });

    test('throws FacilitatorException on invalid JSON', () {
      final mockClient = MockClient((_) async {
        return http.Response('not-json', 200);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        () => client.verify(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(isA<FacilitatorException>()),
      );
    });

    test('throws FacilitatorException on invalid response shape', () {
      final mockClient = MockClient((_) async {
        return http.Response(jsonEncode({'foo': 'bar'}), 200);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        () => client.verify(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(isA<FacilitatorException>()),
      );
    });

    test('serializes deeply nested BigInt correctly', () async {
      late Map<String, dynamic> decodedBody;

      final mockClient = MockClient((request) async {
        decodedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'isValid': true}), 200);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      final payload = mockPaymentPayload(
        payload: {
          'amount': BigInt.parse('123456789012345678901234567890'),
          'nested': {
            'list': [BigInt.from(42)],
          }
        },
        extensions: {
          'crypto': {
            'gasLimit': BigInt.parse('999999999999999999999'),
          }
        },
      );

      await client.verify(
        payload,
        mockPaymentRequirement(extra: {'nonce': BigInt.from(12345)}),
      );

      final paymentPayload =
          decodedBody['paymentPayload'] as Map<String, dynamic>;
      final innerPayload = paymentPayload['payload'] as Map<String, dynamic>;
      expect(innerPayload['amount'], isA<String>());

      final nested = innerPayload['nested'] as Map<String, dynamic>;
      final nestedList = nested['list'] as List<dynamic>;
      expect(nestedList[0], equals('42'));

      final extensions = paymentPayload['extensions'] as Map<String, dynamic>;
      final crypto = extensions['crypto'] as Map<String, dynamic>;
      expect(crypto['gasLimit'], isA<String>());

      final paymentRequirements =
          decodedBody['paymentRequirements'] as Map<String, dynamic>;
      final extra = paymentRequirements['extra'] as Map<String, dynamic>;
      expect(extra['nonce'], equals('12345'));
    });

    test('BigInt in extra is stringified', () async {
      late Map<String, dynamic> decoded;

      final mockClient = MockClient((request) async {
        decoded = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'isValid': true}), 200);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      await client.verify(
        mockPaymentPayload(),
        mockPaymentRequirement(
          extra: {'nonce': BigInt.from(999999999999)},
        ),
      );

      final paymentRequirements =
          decoded['paymentRequirements'] as Map<String, dynamic>;
      final extra = paymentRequirements['extra'] as Map<String, dynamic>;

      expect(extra['nonce'], isA<String>());
    });

    test('wraps network errors in FacilitatorException', () {
      final mockClient = MockClient((_) {
        throw Exception('network down');
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        client.verify(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(isA<FacilitatorException>()),
      );
    });

    test('throws on structurally invalid VerifyResponse', () {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'isValid': true,
            'invalidReason': 123, // invalid type
          }),
          200,
        );
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        () => client.verify(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(anything),
      );
    });

    test('non-200 with non-json body throws FacilitatorException', () {
      final mockClient = MockClient((_) async {
        return http.Response('<html>error</html>', 500);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        () => client.verify(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(isA<FacilitatorException>()),
      );
    });

    test('throws if response is not JSON object', () {
      final mockClient = MockClient((_) async {
        return http.Response(jsonEncode(['invalid']), 200);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        () => client.verify(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(isA<FacilitatorException>()),
      );
    });
  });

  group('HttpFacilitatorClient.settle', () {
    test('returns SettleResponse on success', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'transaction': '0x123',
            'network': 'eip155:1',
          }),
          200,
        );
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      final result = await client.settle(
        mockPaymentPayload(),
        mockPaymentRequirement(),
      );

      expect(result, isA<SettleResponse>());
      expect(result.success, isTrue);
    });

    test('throws FacilitatorResponseException on failure', () {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'transaction': '',
            'network': '',
          }),
          500,
        );
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        () => client.settle(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(isA<FacilitatorResponseException>()),
      );
    });
  });

  group('HttpFacilitatorClient.getSupported', () {
    test('returns SupportedResponse on 200', () async {
      final mockClient = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'kinds': [],
            'extensions': [],
            'signers': {},
          }),
          200,
        );
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      final result = await client.getSupported();

      expect(result, isA<SupportedResponse>());
    });

    test('throws FacilitatorException on non-200', () {
      final mockClient = MockClient((_) async {
        return http.Response('error', 500);
      });

      final client = HttpFacilitatorClient(httpClient: mockClient);

      expect(
        () => client.getSupported(),
        throwsA(isA<FacilitatorException>()),
      );
    });
  });

  group('Auth headers', () {
    test('adds auth headers per path', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['Authorization'], equals('Bearer test'));
        return http.Response(jsonEncode({'isValid': true}), 200);
      });

      final client = HttpFacilitatorClient(
        httpClient: mockClient,
        createAuthHeaders: () async => {
          'verify': {'Authorization': 'Bearer test'}
        },
      );

      await client.verify(
        mockPaymentPayload(),
        mockPaymentRequirement(),
      );
    });

    test('does not add auth headers for other paths', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response(
            jsonEncode({
              'kinds': [],
              'extensions': [],
              'signers': {},
            }),
            200);
      });

      final client = HttpFacilitatorClient(
        httpClient: mockClient,
        createAuthHeaders: () async => {
          'verify': {'Authorization': 'Bearer test'}
        },
      );

      await client.getSupported();
    });

    test('wraps auth header creation errors in FacilitatorException', () async {
      final mockClient = MockClient((_) async {
        return http.Response('{}', 200);
      });

      final client = HttpFacilitatorClient(
        httpClient: mockClient,
        createAuthHeaders: () {
          throw Exception('auth generation failed');
        },
      );

      await expectLater(
        client.verify(
          mockPaymentPayload(),
          mockPaymentRequirement(),
        ),
        throwsA(
          isA<FacilitatorException>().having((e) => e.message, 'message',
              contains('Error creating auth headers')),
        ),
      );
    });
  });
}
