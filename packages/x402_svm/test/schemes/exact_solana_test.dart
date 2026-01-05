import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/x402_svm.dart';

void main() {
  group('HttpFacilitatorClient', () {
    late X402Requirement requirements;

    setUp(() {
      requirements = const X402Requirement(
        scheme: 'v2:solana:exact',
        network: 'solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
        amount: '10000',
        resource: 'https://api.example.com/data',
        description: 'Premium data',
        mimeType: 'application/json',
        payTo: 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv',
        maxTimeoutSeconds: 60,
        asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
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
    });

    test('should settle payment successfully', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/settle'));
        expect(request.method, equals('POST'));

        return http.Response(
          jsonEncode({
            'success': true,
            'txHash': 'transaction_signature',
            'networkId': 'solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
          }),
          200,
        );
      });

      final client = HttpFacilitatorClient(baseUrl: 'https://facilitator.example.com', httpClient: mockClient);

      final response = await client.settle(
        x402Version: 2,
        paymentHeader: 'base64encodedpayload',
        requirement: requirements,
      );

      expect(response.success, isTrue);
      expect(response.txHash, equals('transaction_signature'));
    });

    test('should get supported schemes', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/supported'));
        expect(request.method, equals('GET'));

        return http.Response(
          jsonEncode({
            'kinds': [
              {'scheme': 'v2:solana:exact', 'network': 'solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1'},
              {'scheme': 'v2:solana:exact', 'network': 'solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'},
            ],
          }),
          200,
        );
      });

      final client = HttpFacilitatorClient(baseUrl: 'https://facilitator.example.com', httpClient: mockClient);

      final supported = await client.getSupported();

      expect(supported.length, equals(2));
      expect(supported[0].scheme, equals('v2:solana:exact'));
      expect(supported[0].network, contains('solana:'));
    });
  });
}
