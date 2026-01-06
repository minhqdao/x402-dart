import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

void main() {
  group('HttpFacilitatorClient', () {
    late PaymentRequirement requirements;

    setUp(() {
      requirements = const PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {'name': 'USDC', 'version': '2'},
      );
    });

    test('should verify payment successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/verify'));
        expect(request.method, equals('POST'));

        return http.Response(jsonEncode({'isValid': true}), 200);
      });

      final client = HttpFacilitatorClient(baseUrl: 'https://facilitator.example.com', httpClient: mockClient);

      final response = await client.verify(
        x402Version: 2,
        paymentHeader: 'base64encodedpayload',
        requirement: requirements,
      );

      expect(response.isValid, isTrue);
      expect(response.invalidReason, isNull);
    });

    test('should handle verification failure', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'isValid': false, 'invalidReason': 'Insufficient balance'}), 200);
      });

      final client = HttpFacilitatorClient(baseUrl: 'https://facilitator.example.com', httpClient: mockClient);

      final response = await client.verify(
        x402Version: 2,
        paymentHeader: 'base64encodedpayload',
        requirement: requirements,
      );

      expect(response.isValid, isFalse);
      expect(response.invalidReason, equals('Insufficient balance'));
    });

    test('should settle payment successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/settle'));
        expect(request.method, equals('POST'));

        return http.Response(jsonEncode({'success': true, 'txHash': '0x789...', 'networkId': 'eip155:8453'}), 200);
      });

      final client = HttpFacilitatorClient(baseUrl: 'https://facilitator.example.com', httpClient: mockClient);

      final response = await client.settle(
        x402Version: 2,
        paymentHeader: 'base64encodedpayload',
        requirement: requirements,
      );

      expect(response.success, isTrue);
      expect(response.txHash, equals('0x789...'));
      expect(response.networkId, equals('eip155:8453'));
    });

    test('should get supported schemes', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/supported'));
        expect(request.method, equals('GET'));

        return http.Response(
          jsonEncode({
            'kinds': [
              {'scheme': 'exact', 'network': 'eip155:8453'},
              {'scheme': 'exact', 'network': 'eip155:1'},
            ],
          }),
          200,
        );
      });

      final client = HttpFacilitatorClient(baseUrl: 'https://facilitator.example.com', httpClient: mockClient);

      final supported = await client.getSupported();

      expect(supported.length, equals(2));
      expect(supported[0].scheme, equals('exact'));
      expect(supported[0].network, equals('eip155:8453'));
      expect(supported[1].network, equals('eip155:1'));
    });

    test('should throw on HTTP error', () {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = HttpFacilitatorClient(baseUrl: 'https://facilitator.example.com', httpClient: mockClient);

      expect(
        () => client.verify(x402Version: 2, paymentHeader: 'base64encodedpayload', requirement: requirements),
        throwsA(isA<PaymentVerificationException>()),
      );
    });
  });
}
