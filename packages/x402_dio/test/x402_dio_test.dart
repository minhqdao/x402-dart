import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_dio/x402_dio.dart';

class MockX402Signer extends Mock implements X402Signer {}

class MockHttpClientAdapter extends Mock implements HttpClientAdapter {}

void main() {
  group('X402Interceptor', () {
    late Dio dio;
    late MockHttpClientAdapter mockAdapter;
    late MockX402Signer signerA;
    late MockX402Signer signerB;
    late PaymentRequirement requirementA;
    late ResourceInfo resourceInfo;
    late String headerValue;

    setUp(() {
      mockAdapter = MockHttpClientAdapter();
      dio = Dio()..httpClientAdapter = mockAdapter;
      signerA = MockX402Signer();
      signerB = MockX402Signer();

      when(() => signerA.network).thenReturn('net:A');
      when(() => signerA.scheme).thenReturn('scheme:A');
      when(() => signerA.address).thenReturn('address:A');

      when(() => signerB.network).thenReturn('net:B');
      when(() => signerB.scheme).thenReturn('scheme:B');
      when(() => signerB.address).thenReturn('address:B');

      requirementA = const PaymentRequirement(
        network: 'net:A',
        scheme: 'scheme:A',
        amount: '100',
        payTo: 'someone',
        asset: 'asset',
        maxTimeoutSeconds: 100,
        extra: {},
      );

      resourceInfo = const ResourceInfo(
        url: 'http://res',
        description: 'desc',
        mimeType: 'text/plain',
      );

      headerValue = base64Encode(utf8.encode(jsonEncode({
        'x402Version': kX402Version,
        'accepts': [requirementA.toJson()],
        'resource': resourceInfo.toJson(),
        'extensions': {}
      })));

      registerFallbackValue(RequestOptions());
      registerFallbackValue(requirementA);
      registerFallbackValue(resourceInfo);
    });

    test('should throw ArgumentError if signers list is empty', () {
      expect(() => X402Interceptor(dio: dio, signers: []),
          throwsA(isA<ArgumentError>()));
    });

    test('should handle 402 and retry', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => 'signature_A');

      var callCount = 0;
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        callCount++;
        final options = invocation.positionalArguments[0] as RequestOptions;

        if (callCount == 1) {
          return ResponseBody.fromBytes(
            utf8.encode('Payment Required'),
            402,
            headers: {
              kPaymentRequiredHeader: [headerValue],
            },
          );
        }

        if (options.headers[kPaymentSignatureHeader] == 'signature_A') {
          return ResponseBody.fromBytes(utf8.encode('Success'), 200);
        }

        return ResponseBody.fromBytes(utf8.encode('Fail'), 500);
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      final response = await dio.get('http://example.com');

      expect(response.statusCode, 200);
      expect(response.data, 'Success');
      verify(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
    });

    test('should use first matching signer if multiple match', () async {
      const requirementB = PaymentRequirement(
        network: 'net:B',
        scheme: 'scheme:B',
        amount: '100',
        payTo: 'someone',
        asset: 'asset',
        maxTimeoutSeconds: 100,
        extra: {},
      );

      final multiHeaderValue = base64Encode(utf8.encode(jsonEncode({
        'x402Version': kX402Version,
        'accepts': [requirementA.toJson(), requirementB.toJson()],
        'resource': resourceInfo.toJson(),
      })));

      when(() => signerA.supports(any(
              that:
                  predicate<PaymentRequirement>((p) => p.network == 'net:A'))))
          .thenReturn(true);
      when(() => signerA.supports(any(
              that:
                  predicate<PaymentRequirement>((p) => p.network == 'net:B'))))
          .thenReturn(false);

      when(() => signerB.supports(any(
              that:
                  predicate<PaymentRequirement>((p) => p.network == 'net:A'))))
          .thenReturn(false);
      when(() => signerB.supports(any(
              that:
                  predicate<PaymentRequirement>((p) => p.network == 'net:B'))))
          .thenReturn(true);

      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => 'signature_A');

      var callCount = 0;
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        callCount++;
        if (callCount == 1) {
          return ResponseBody.fromBytes(
            utf8.encode('Payment Required'),
            402,
            headers: {
              kPaymentRequiredHeader: [multiHeaderValue],
            },
          );
        }
        return ResponseBody.fromBytes(utf8.encode('Success'), 200);
      });

      dio.interceptors
          .add(X402Interceptor(dio: dio, signers: [signerA, signerB]));

      await dio.get('http://example.com');

      verify(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
      verifyNever(() =>
          signerB.sign(any(), any(), extensions: any(named: 'extensions')));
    });

    test('should use second signer if first one does not match', () async {
      const requirementB = PaymentRequirement(
        network: 'net:B',
        scheme: 'scheme:B',
        amount: '100',
        payTo: 'someone',
        asset: 'asset',
        maxTimeoutSeconds: 100,
        extra: {},
      );

      final multiHeaderValue = base64Encode(utf8.encode(jsonEncode({
        'x402Version': kX402Version,
        'accepts': [requirementB.toJson()],
        'resource': resourceInfo.toJson(),
      })));

      when(() => signerA.supports(any(
              that:
                  predicate<PaymentRequirement>((p) => p.network == 'net:B'))))
          .thenReturn(false);
      when(() => signerB.supports(any(
              that:
                  predicate<PaymentRequirement>((p) => p.network == 'net:B'))))
          .thenReturn(true);

      when(() =>
              signerB.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => 'signature_B');

      var callCount = 0;
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        callCount++;
        if (callCount == 1) {
          return ResponseBody.fromBytes(
            utf8.encode('Payment Required'),
            402,
            headers: {
              kPaymentRequiredHeader: [multiHeaderValue],
            },
          );
        }
        return ResponseBody.fromBytes(utf8.encode('Success'), 200);
      });

      dio.interceptors
          .add(X402Interceptor(dio: dio, signers: [signerA, signerB]));

      await dio.get('http://example.com');

      verifyNever(() =>
          signerA.sign(any(), any(), extensions: any(named: 'extensions')));
      verify(() =>
              signerB.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
    });

    test('should ignore non-402 responses (e.g., 200)', () async {
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(utf8.encode('OK'), 200);
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      final response = await dio.get('http://example.com');

      expect(response.statusCode, 200);
      expect(response.data, 'OK');
      verifyNever(() => signerA.supports(any()));
    });

    test('should ignore non-402 responses (e.g., 404)', () async {
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(utf8.encode('Not Found'), 404);
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 404);
      }
      verifyNever(() => signerA.supports(any()));
    });

    test('should pass through 402 if header is missing', () async {
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(utf8.encode('Payment Required'), 402);
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 402);
      }
    });

    test('should pass through 402 if header is malformatted', () async {
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(
          utf8.encode('Payment Required'),
          402,
          headers: {
            kPaymentRequiredHeader: ['not-base64-json'],
          },
        );
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 402);
      }
    });

    test('should pass through 402 if requirements are empty', () async {
      final emptyHeaderValue = base64Encode(utf8.encode(jsonEncode({
        'x402Version': kX402Version,
        'accepts': [],
        'resource': resourceInfo.toJson(),
      })));

      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(
          utf8.encode('Payment Required'),
          402,
          headers: {
            kPaymentRequiredHeader: [emptyHeaderValue],
          },
        );
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 402);
      }
    });

    test('should pass through 402 if user denies consent', () async {
      when(() => signerA.supports(any())).thenReturn(true);

      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(
          utf8.encode('Payment Required'),
          402,
          headers: {
            kPaymentRequiredHeader: [headerValue],
          },
        );
      });

      dio.interceptors.add(X402Interceptor(
        dio: dio,
        signers: [signerA],
        onPaymentRequired: (req, res, signer) async => false, // Deny
      ));

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 402);
        verifyNever(() =>
            signerA.sign(any(), any(), extensions: any(named: 'extensions')));
      }
    });

    test('should pass through 402 if onPaymentRequired throws', () async {
      when(() => signerA.supports(any())).thenReturn(true);

      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(
          utf8.encode('Payment Required'),
          402,
          headers: {
            kPaymentRequiredHeader: [headerValue],
          },
        );
      });

      dio.interceptors.add(X402Interceptor(
        dio: dio,
        signers: [signerA],
        onPaymentRequired: (req, res, signer) async =>
            throw Exception('User Error'),
      ));

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 402);
        verifyNever(() =>
            signerA.sign(any(), any(), extensions: any(named: 'extensions')));
      }
    });

    test('should pass through 402 if sign throws', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenThrow(Exception('Sign Error'));

      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(
          utf8.encode('Payment Required'),
          402,
          headers: {
            kPaymentRequiredHeader: [headerValue],
          },
        );
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 402);
      }
    });

    test('should retry if user explicitly consents', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => 'signature_A');

      var callCount = 0;
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        callCount++;
        final options = invocation.positionalArguments[0] as RequestOptions;

        if (callCount == 1) {
          return ResponseBody.fromBytes(
            utf8.encode('Payment Required'),
            402,
            headers: {
              kPaymentRequiredHeader: [headerValue],
            },
          );
        }

        if (options.headers[kPaymentSignatureHeader] == 'signature_A') {
          return ResponseBody.fromBytes(utf8.encode('Success'), 200);
        }

        return ResponseBody.fromBytes(utf8.encode('Fail'), 500);
      });

      dio.interceptors.add(X402Interceptor(
        dio: dio,
        signers: [signerA],
        onPaymentRequired: (req, res, signer) async => true, // Approve
      ));

      final response = await dio.get('http://example.com');

      expect(response.statusCode, 200);
      expect(response.data, 'Success');
      verify(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
    });

    test('should fail if no signer supports requirement', () async {
      when(() => signerA.supports(any())).thenReturn(false);

      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(
          utf8.encode('Payment Required'),
          402,
          headers: {
            kPaymentRequiredHeader: [headerValue],
          },
        );
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 402);
      }
    });

    test('should avoid infinite loop if signature already present', () async {
      when(() => signerA.supports(any())).thenReturn(true);

      // Simulate a scenario where 402 is returned even AFTER signing
      when(() => mockAdapter.fetch(any(), any(), any()))
          .thenAnswer((invocation) async {
        return ResponseBody.fromBytes(
          utf8.encode('Payment Required Again'),
          402,
          headers: {
            kPaymentRequiredHeader: [headerValue],
          },
        );
      });

      dio.interceptors.add(X402Interceptor(dio: dio, signers: [signerA]));

      // Set header globally to ensure it's in request options
      dio.options.headers[kPaymentSignatureHeader] = 'signature_A';

      try {
        await dio.get('http://example.com');
        fail('Should throw DioException');
      } on DioException catch (e) {
        expect(e.response?.statusCode, 402);
        // Should NOT have called sign() because we already have the signature
        verifyNever(() =>
            signerA.sign(any(), any(), extensions: any(named: 'extensions')));
      }
    });
  });
}
