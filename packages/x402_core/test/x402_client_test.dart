import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

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

      when(() => signerA.network)
          .thenReturn(const Network(namespace: 'net', reference: 'A'));
      when(() => signerA.scheme).thenReturn('scheme:A');
      when(() => signerA.address).thenReturn('address:A');

      when(() => signerB.network)
          .thenReturn(const Network(namespace: 'net', reference: 'B'));
      when(() => signerB.scheme).thenReturn('scheme:B');
      when(() => signerB.address).thenReturn('address:B');

      requirementA = PaymentRequirement(
        network: const Network(namespace: 'net', reference: 'A'),
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
      registerFallbackValue(
          http.Request('GET', Uri.parse('http://example.com')));
    });

    test('should throw ArgumentError if signers list is empty', () {
      expect(() => X402Client(signers: [], inner: mockInner),
          throwsA(isA<ArgumentError>()));
    });

    test('should handle 402 and retry', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => const SignedPayment('signature_A'));

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});
      final response200 = http.StreamedResponse(Stream.value([]), 200);

      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return response402;
        return response200;
      });

      final client = X402Client(signers: [signerA], inner: mockInner);
      final response = await client.get(Uri.parse('http://example.com'));

      expect(response.statusCode, 200);
      verify(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
    });

    test('should proceed automatically if no callback provided', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => const SignedPayment('signature_A'));

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});
      final response200 = http.StreamedResponse(Stream.value([]), 200);

      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return response402;
        return response200;
      });

      // No onPaymentRequired provided
      final client = X402Client(signers: [signerA], inner: mockInner);
      final response = await client.get(Uri.parse('http://example.com'));

      expect(response.statusCode, 200);
      verify(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
    });

    test(
        'should invoke callback with correct arguments and proceed if true returned',
        () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => const SignedPayment('signature_A'));

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});
      final response200 = http.StreamedResponse(Stream.value([]), 200);

      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((_) async {
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
          expect(req.network.identifier, equals('net:A'));
          expect(res.url, equals('http://res'));
          expect(s, equals(signerA));
          return true; // Approve
        },
      );
      final response = await client.get(Uri.parse('http://example.com'));

      expect(response.statusCode, 200);
      expect(callbackCalled, isTrue);
    });

    test('should ignore non-402 responses (e.g., 200)', () async {
      when(() => mockInner.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(Stream.value([]), 200));

      final client = X402Client(signers: [signerA], inner: mockInner);
      final response = await client.get(Uri.parse('http://example.com'));

      expect(response.statusCode, 200);
      verifyNever(() => signerA.supports(any()));
    });

    test('should ignore non-402 responses (e.g., 404)', () async {
      when(() => mockInner.send(any())).thenAnswer(
          (_) async => http.StreamedResponse(Stream.value([]), 404));

      final client = X402Client(signers: [signerA], inner: mockInner);
      final response = await client.get(Uri.parse('http://example.com'));

      expect(response.statusCode, 404);
      verifyNever(() => signerA.supports(any()));
    });

    test('should pass through 402 if header is missing', () async {
      final response402 = http.StreamedResponse(Stream.value([]), 402);
      when(() => mockInner.send(any())).thenAnswer((_) async => response402);

      final client = X402Client(signers: [signerA], inner: mockInner);
      final request = http.Request('GET', Uri.parse('http://example.com'));
      final response = await client.send(request);

      expect(response.statusCode, 402);
    });

    test('should pass through 402 if header is malformatted', () async {
      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: 'not-base64'});
      when(() => mockInner.send(any())).thenAnswer((_) async => response402);

      final client = X402Client(signers: [signerA], inner: mockInner);
      final request = http.Request('GET', Uri.parse('http://example.com'));
      final response = await client.send(request);

      expect(response.statusCode, 402);
    });

    test('should pass through 402 if requirements are empty', () async {
      final emptyHeader = base64Encode(utf8.encode(jsonEncode({
        'x402Version': kX402Version,
        'accepts': [],
        'resource': resourceInfo.toJson(),
      })));
      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: emptyHeader});
      when(() => mockInner.send(any())).thenAnswer((_) async => response402);

      final client = X402Client(signers: [signerA], inner: mockInner);
      final request = http.Request('GET', Uri.parse('http://example.com'));
      final response = await client.send(request);

      expect(response.statusCode, 402);
    });

    test('should abort if callback returns false', () async {
      when(() => signerA.supports(any())).thenReturn(true);

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});
      when(() => mockInner.send(any())).thenAnswer((_) async => response402);

      final client = X402Client(
        signers: [signerA],
        inner: mockInner,
        onPaymentRequired: (req, res, s) async => false, // Deny
      );
      final request = http.Request('GET', Uri.parse('http://example.com'));
      final response = await client.send(request);

      expect(response.statusCode, 402);
      verifyNever(() =>
          signerA.sign(any(), any(), extensions: any(named: 'extensions')));
    });

    test('should pass through 402 if onPaymentRequired throws', () async {
      when(() => signerA.supports(any())).thenReturn(true);

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});
      when(() => mockInner.send(any())).thenAnswer((_) async => response402);

      final client = X402Client(
        signers: [signerA],
        inner: mockInner,
        onPaymentRequired: (req, res, s) async => throw Exception('User Error'),
      );
      final request = http.Request('GET', Uri.parse('http://example.com'));
      final response = await client.send(request);

      expect(response.statusCode, 402);
    });

    test('should pass through 402 if sign throws', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenThrow(Exception('Sign Error'));

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});
      when(() => mockInner.send(any())).thenAnswer((_) async => response402);

      final client = X402Client(signers: [signerA], inner: mockInner);
      final request = http.Request('GET', Uri.parse('http://example.com'));
      final response = await client.send(request);

      expect(response.statusCode, 402);
    });

    test('should use first matching signer (A before B)', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() => signerB.supports(any())).thenReturn(true);

      when(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => const SignedPayment('signature_A'));

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});
      final response200 = http.StreamedResponse(Stream.value([]), 200);

      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return response402;
        return response200;
      });

      final client = X402Client(signers: [signerA, signerB], inner: mockInner);
      await client.get(Uri.parse('http://example.com'));

      verify(() =>
              signerA.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
      verifyNever(() =>
          signerB.sign(any(), any(), extensions: any(named: 'extensions')));
    });

    test('should use first matching signer (B before A)', () async {
      when(() => signerA.supports(any())).thenReturn(true);
      when(() => signerB.supports(any())).thenReturn(true);

      when(() =>
              signerB.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => const SignedPayment('signature_B'));

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});
      final response200 = http.StreamedResponse(Stream.value([]), 200);

      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return response402;
        return response200;
      });

      final client = X402Client(signers: [signerB, signerA], inner: mockInner);
      await client.get(Uri.parse('http://example.com'));

      verify(() =>
              signerB.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
      verifyNever(() =>
          signerA.sign(any(), any(), extensions: any(named: 'extensions')));
    });

    test('should use second signer if first one does not match', () async {
      final requirementB = PaymentRequirement(
        network: const Network(namespace: 'net', reference: 'B'),
        scheme: 'scheme:B',
        amount: '100',
        payTo: 'someone',
        asset: 'asset',
        maxTimeoutSeconds: 100,
        extra: const {},
      );
      final multiHeader = base64Encode(utf8.encode(jsonEncode({
        'x402Version': kX402Version,
        'accepts': [requirementB.toJson()],
        'resource': resourceInfo.toJson(),
      })));

      when(() => signerA.supports(any(
          that: predicate<PaymentRequirement>(
              (p) => p.network.identifier == 'net:B')))).thenReturn(false);
      when(() => signerB.supports(any(
          that: predicate<PaymentRequirement>(
              (p) => p.network.identifier == 'net:B')))).thenReturn(true);

      when(() =>
              signerB.sign(any(), any(), extensions: any(named: 'extensions')))
          .thenAnswer((_) async => const SignedPayment('signature_B'));

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: multiHeader});
      final response200 = http.StreamedResponse(Stream.value([]), 200);

      var callCount = 0;
      when(() => mockInner.send(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return response402;
        return response200;
      });

      final client = X402Client(signers: [signerA, signerB], inner: mockInner);
      await client.get(Uri.parse('http://example.com'));

      verifyNever(() =>
          signerA.sign(any(), any(), extensions: any(named: 'extensions')));
      verify(() =>
              signerB.sign(any(), any(), extensions: any(named: 'extensions')))
          .called(1);
    });

    test('should avoid infinite loop if signature already present', () async {
      when(() => signerA.supports(any())).thenReturn(true);

      final response402 = http.StreamedResponse(Stream.value([]), 402,
          headers: {kPaymentRequiredHeader: headerValue});

      when(() => mockInner.send(any())).thenAnswer((_) async => response402);

      final client = X402Client(signers: [signerA], inner: mockInner);

      final request = http.Request('GET', Uri.parse('http://example.com'))
        ..headers[kPaymentSignatureHeader] = 'already_signed';

      final response = await client.send(request);

      expect(response.statusCode, 402);
      verifyNever(() =>
          signerA.sign(any(), any(), extensions: any(named: 'extensions')));
    });
  });
}
