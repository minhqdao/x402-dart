import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_core/src/client/x402_client.dart';

class MockHttpClient extends Mock implements http.Client {}
class MockX402Signer extends Mock implements X402Signer {}

void main() {
  group('X402Client', () {
    late MockHttpClient mockInner;
    late MockX402Signer signerA;
    late MockX402Signer signerB;
    
    late PaymentRequirement requirementA;
    late ResourceInfo resourceInfo;
    late String headerValue;

    setUp(() {
      mockInner = MockHttpClient();
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

      registerFallbackValue(requirementA);
      registerFallbackValue(resourceInfo);
      registerFallbackValue(http.Request('GET', Uri.parse('http://example.com')));
    });

    test('should invoke callback with correct arguments and proceed if true returned', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() => signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => 'signature_A');

      // Mock 402 response
      final response402 = http.StreamedResponse(
        Stream.value(utf8.encode('Payment Required')),
        402,
        headers: {kPaymentRequiredHeader: headerValue},
      );
      
      // Mock 200 response (after payment)
      final response200 = http.StreamedResponse(
        Stream.value(utf8.encode('Success')),
        200,
      );

      // Setup http client
      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((invocation) async {
        callCount++;
        if (callCount == 1) return response402;
        return response200;
      });

      var callbackCalled = false;
      final client = X402Client(
        signers: [signerA],
        inner: mockInner,
        onPaymentRequired: (req, res, s) async {
          callbackCalled = true;
          // Verify all three arguments
          expect(req.network, equals('net:A'));
          expect(res.url, equals('http://res'));
          expect(s, equals(signerA));
          return true; // Approve
        },
      );

      final request = http.Request('GET', Uri.parse('http://example.com'));
      final response = await client.send(request);

      expect(callbackCalled, isTrue);
      expect(response.statusCode, equals(200));
      verify(() => signerA.sign(any(), any(), extensions: any(named: 'extensions'))).called(1);
    });

    test('should abort if callback returns false', () async {
      when(() => signerA.supports(any())).thenReturn(true);

      final response402 = http.StreamedResponse(
        Stream.value(utf8.encode('Payment Required')),
        402,
        headers: {kPaymentRequiredHeader: headerValue},
      );

      when(() => mockInner.send(any())).thenAnswer((_) async => response402);

      final client = X402Client(
        signers: [signerA],
        inner: mockInner,
        onPaymentRequired: (req, res, s) async {
          // Verify arguments even in abort case
          expect(req.network, equals('net:A'));
          expect(res.url, equals('http://res'));
          expect(s, equals(signerA));
          return false; // Deny
        },
      );

      final request = http.Request('GET', Uri.parse('http://example.com'));
      final response = await client.send(request);

      expect(response.statusCode, equals(402));
      verifyNever(() => signerA.sign(any(), any(), extensions: any(named: 'extensions')));
    });

    test('should use first matching signer (A before B)', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() => signerB.supports(any())).thenReturn(true);
      
      when(() => signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => 'signature_A');

      final response402 = http.StreamedResponse(
        Stream.value(utf8.encode('Payment Required')),
        402,
        headers: {kPaymentRequiredHeader: headerValue},
      );
      final response200 = http.StreamedResponse(Stream.value([]), 200);

      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return response402;
        return response200;
      });

      final client = X402Client(
        signers: [signerA, signerB], // A is preferred
        inner: mockInner,
      );

      final request = http.Request('GET', Uri.parse('http://example.com'));
      await client.send(request);

      verify(() => signerA.sign(any(), any(), extensions: any(named: 'extensions'))).called(1);
      verifyNever(() => signerB.sign(any(), any(), extensions: any(named: 'extensions')));
    });

    test('should use first matching signer (B before A)', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() => signerB.supports(any())).thenReturn(true);
      
      when(() => signerB.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => 'signature_B');

      final response402 = http.StreamedResponse(
        Stream.value(utf8.encode('Payment Required')),
        402,
        headers: {kPaymentRequiredHeader: headerValue},
      );
      final response200 = http.StreamedResponse(Stream.value([]), 200);

      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return response402;
        return response200;
      });

      final client = X402Client(
        signers: [signerB, signerA], // B is preferred
        inner: mockInner,
      );

      final request = http.Request('GET', Uri.parse('http://example.com'));
      await client.send(request);

      verify(() => signerB.sign(any(), any(), extensions: any(named: 'extensions'))).called(1);
      verifyNever(() => signerA.sign(any(), any(), extensions: any(named: 'extensions')));
    });
  });
}