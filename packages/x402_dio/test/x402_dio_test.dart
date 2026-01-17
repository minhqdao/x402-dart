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
    late PaymentRequirement requirementA;
    late ResourceInfo resourceInfo;
    late String headerValue;

    setUp(() {
      mockAdapter = MockHttpClientAdapter();
      dio = Dio()..httpClientAdapter = mockAdapter;
      signerA = MockX402Signer();

      when(() => signerA.network).thenReturn('net:A');
      when(() => signerA.scheme).thenReturn('scheme:A');
      when(() => signerA.address).thenReturn('address:A');

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
