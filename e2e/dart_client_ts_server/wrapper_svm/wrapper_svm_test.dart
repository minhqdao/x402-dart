import 'dart:convert';

import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';

void main() {
  final env = DotEnv(includePlatformEnvironment: true)..load(['e2e/.env']);

  test('Client wrapper pays for premium content via SVM', () async {
    final svmPrivateKey = env['SVM_PRIVATE_KEY_PAYER'];
    if (svmPrivateKey == null || svmPrivateKey.isEmpty) {
      fail('SVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    final svmSigner = await SvmSigner.fromPrivateKeyHex(
      privateKeyHex: svmPrivateKey,
      cluster: SolanaCluster.devnet,
    );

    final client = X402Client(
      signers: [svmSigner],
      retryDelay: const Duration(seconds: 1),
    );

    addTearDown(() => client.close());

    final serverUrl = env['RESOURCE_SERVER_URL'] ?? 'http://server:4021';
    final endpointPath = env['ENDPOINT_PATH'] ?? '/weather';
    final uri = Uri.parse('$serverUrl$endpointPath');

    try {
      final response = await client.get(uri);

      expect(response.statusCode, equals(200),
          reason: 'Should return 200 OK after payment');
      expect(response.body, isNotEmpty,
          reason: 'Response body should not be empty');

      final decoded = json.decode(response.body) as Map<String, dynamic>;
      expect(decoded, contains('report'));

      final report = decoded['report'] as Map<String, dynamic>;
      expect(report['weather'], equals('sunny'));
      expect(report['temperature'], equals(70));
    } catch (e) {
      fail('Exception during request: $e');
    }
  });
}
