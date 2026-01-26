import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';

void main() {
  final env = DotEnv(includePlatformEnvironment: true)..load(['e2e/.env']);

  test('Client wrapper returns 402 when payment is denied via SVM', () async {
    final svmPrivateKey = env['SVM_PRIVATE_KEY_PAYER'];
    if (svmPrivateKey == null || svmPrivateKey.isEmpty) {
      fail('SVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    final svmSigner = await SvmSigner.fromPrivateKeyHex(
      privateKeyHex: svmPrivateKey,
      network: SolanaNetwork.devnet,
    );

    final client = X402Client(
      signers: [svmSigner],
      onPaymentRequired: (req, resource, signer) async {
        stdout.writeln('💰 Payment required but denying it intentionally...');
        return false; // Deny payment
      },
    );

    addTearDown(() => client.close());

    final serverUrl = env['RESOURCE_SERVER_URL'] ?? 'http://server:4021';
    final endpointPath = env['ENDPOINT_PATH'] ?? '/weather';
    final uri = Uri.parse('$serverUrl$endpointPath');

    try {
      final response = await client.get(uri);

      expect(response.statusCode, equals(402),
          reason:
              'Should return 402 Payment Required when user denies payment');

      stdout.writeln('Received expected 402 status code.');
    } catch (e) {
      fail('Exception during request: $e');
    }
  });
}
