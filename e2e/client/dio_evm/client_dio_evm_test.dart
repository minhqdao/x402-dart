import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';
import 'package:x402_dio/x402_dio.dart';

void main() {
  final env = DotEnv(includePlatformEnvironment: true)..load(['e2e/.env']);

  test('Client Dio pays for premium content via EVM', () async {
    final evmPrivateKey = env['EVM_PRIVATE_KEY_PAYER'];
    if (evmPrivateKey == null || evmPrivateKey.isEmpty) {
      fail('EVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    final evmSigner = EvmSigner.fromPrivateKeyHex(
      chainId: 84532,
      privateKeyHex: evmPrivateKey,
    );

    final dio = Dio();
    dio.interceptors.add(X402Interceptor(dio: dio, signers: [evmSigner]));

    final serverUrl = env['RESOURCE_SERVER_URL'] ?? 'http://server:4021';
    final endpointPath = env['ENDPOINT_PATH'] ?? '/weather';
    final url = '$serverUrl$endpointPath';

    try {
      final response = await dio.get(url);

      expect(response.statusCode, equals(200),
          reason: 'Should return 200 OK after payment');
      expect(response.data, isNotEmpty,
          reason: 'Response body should not be empty');

      // Dio automatically decodes JSON if content-type is application/json
      final data = response.data as Map<String, dynamic>;
      expect(data, contains('report'));

      final report = data['report'] as Map<String, dynamic>;
      expect(report['weather'], equals('sunny'));
      expect(report['temperature'], equals(70));
    } catch (e) {
      fail('Exception during request: $e');
    }
  });
}
