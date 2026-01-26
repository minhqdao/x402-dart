import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';
import 'package:x402_dio/x402_dio.dart';

void main() {
  final env = DotEnv(includePlatformEnvironment: true)..load(['e2e/.env']);

  test('Client Dio returns 402 when payment is denied via EVM', () async {
    final evmPrivateKey = env['EVM_PRIVATE_KEY_PAYER'];
    if (evmPrivateKey == null || evmPrivateKey.isEmpty) {
      fail('EVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    final evmSigner = EvmSigner.fromPrivateKeyHex(
      chainId: 84532,
      privateKeyHex: evmPrivateKey,
    );

    final dio = Dio();
    dio.interceptors.add(X402Interceptor(
      dio: dio,
      signers: [evmSigner],
      onPaymentRequired: (req, resource, signer) async {
        stdout.writeln('💰 Payment required but denying it intentionally...');
        return false; // Deny payment
      },
    ));

    final serverUrl = env['RESOURCE_SERVER_URL'] ?? 'http://server:4021';
    final endpointPath = env['ENDPOINT_PATH'] ?? '/weather';
    final url = '$serverUrl$endpointPath';

    try {
      final response = await dio.get(url);

      expect(response.statusCode, equals(402),
          reason:
              'Should return 402 Payment Required when user denies payment');

      stdout.writeln('Received expected 402 status code.');
    } on DioException catch (e) {
      if (e.response?.statusCode == 402) {
        stdout.writeln('Received expected 402 status code via DioException.');
        expect(e.response?.statusCode, equals(402));
      } else {
        fail('Received unexpected DioException: ${e.message}');
      }
    } catch (e) {
      fail('Exception during request: $e');
    }
  });
}
