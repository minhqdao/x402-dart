import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';
import 'package:x402_dio/x402_dio.dart';

void main() {
  final env = DotEnv(includePlatformEnvironment: true)..load(['e2e/.env']);

  test('Client Dio returns 402 when payment is denied via SVM', () async {
    final svmPrivateKey = env['SVM_PRIVATE_KEY_PAYER'];
    if (svmPrivateKey == null || svmPrivateKey.isEmpty) {
      fail('SVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    final svmSigner = await SvmSigner.fromPrivateKeyHex(
      privateKeyHex: svmPrivateKey,
      network: SolanaNetwork.devnet,
    );

    final dio = Dio();
    dio.interceptors.add(X402Interceptor(
      dio: dio,
      signers: [svmSigner],
      onPaymentRequired: (req, resource, signer) async => false,
    ));

    final serverUrl = env['RESOURCE_SERVER_URL'] ?? 'http://server:4021';
    final endpointPath = env['ENDPOINT_PATH'] ?? '/weather';
    final url = '$serverUrl$endpointPath';

    try {
      final response = await dio.get(url);

      // Note: If X402Interceptor works correctly, it should let the 402 through if rejected.
      // However, Dio usually throws on 4xx unless configured otherwise.
      // The X402Interceptor might need to handle this.
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
