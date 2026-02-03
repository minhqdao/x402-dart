import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:x402/x402.dart';

void main() {
  final env = DotEnv(includePlatformEnvironment: true)..load(['e2e/.env']);

  test('Manual payment flow via EVM', () async {
    final evmPrivateKey = env['EVM_PRIVATE_KEY_PAYER'];
    if (evmPrivateKey == null || evmPrivateKey.isEmpty) {
      fail('EVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    final serverUrl = env['RESOURCE_SERVER_URL'] ?? 'http://server:4021';
    final endpointPath = env['ENDPOINT_PATH'] ?? '/weather';
    final uri = Uri.parse('$serverUrl$endpointPath');

    final client = http.Client();
    addTearDown(() => client.close());

    // 1. Initial Request
    stdout.writeln('Making initial request to $uri...');
    final initialResponse = await client.get(uri);

    expect(initialResponse.statusCode, equals(402),
        reason: 'Initial request should return 402 Payment Required');

    // 2. Parse 402 Header
    final header = initialResponse.headers[kPaymentRequiredHeader];
    expect(header, isNotNull, reason: 'Missing $kPaymentRequiredHeader header');

    final paymentResponse = PaymentRequiredResponse.fromHeader(header!);

    // 3. Setup Signer and Sign
    final evmSigner = EvmSigner.fromPrivateKeyHex(
      chainId: 84532,
      privateKeyHex: evmPrivateKey,
    );

    final requirement =
        paymentResponse.accepts.firstWhereOrNull(evmSigner.supports);
    expect(requirement, isNotNull,
        reason: 'No compatible requirement found for EVM signer');

    stdout.writeln('Signing payment payload...');
    final signature = await evmSigner.sign(
      requirement!,
      paymentResponse.resource,
      extensions: paymentResponse.extensions,
    );

    // 4. Retry Request with Signature
    stdout.writeln('Retrying request with signature...');
    final retryResponse = await client.get(
      uri,
      headers: {kPaymentSignatureHeader: signature.encoded},
    );

    expect(retryResponse.statusCode, equals(200),
        reason: 'Retry with signature should return 200 OK');

    final decoded = json.decode(retryResponse.body) as Map<String, dynamic>;
    expect(decoded, contains('report'));
    final report = decoded['report'] as Map<String, dynamic>;
    expect(report['weather'], equals('sunny'));
    expect(report['temperature'], equals(70));

    stdout.writeln('Manual payment flow successful.');
  });
}
