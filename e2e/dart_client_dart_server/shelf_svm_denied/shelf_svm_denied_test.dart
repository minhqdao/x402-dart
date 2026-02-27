import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';
import 'package:x402_shelf/x402_shelf.dart';

void main() {
  final env = DotEnv(includePlatformEnvironment: true)..load(['e2e/.env']);

  group('Shelf Server + Client Wrapper E2E Denied (SVM)', () {
    late HttpServer server;
    late X402ResourceServer resourceServer;
    late String serverUrl;

    final svmAddress = env['SVM_ADDRESS'];
    if (svmAddress == null || svmAddress.isEmpty) {
      fail('SVM_ADDRESS is not set in environment or .env file.');
    }

    final svmPrivateKey = env['SVM_PRIVATE_KEY_PAYER'];
    if (svmPrivateKey == null || svmPrivateKey.isEmpty) {
      fail('SVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    setUpAll(() async {
      resourceServer = await X402ResourceServer.create(
        schemeServers: [ExactSvmSchemeServer(cluster: SolanaCluster.devnet)],
      );

      final routes = {
        const RoutePattern(HttpMethod.get, '/premium'): RouteConfig(
          accepts: [
            PaymentOption(
              scheme: 'exact',
              price: const Money('0.10'),
              network: SolanaNetwork.devnet(),
              payTo: svmAddress,
            ),
          ],
          description: 'Premium content via Shelf SVM',
        ),
      };

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler((request) {
        return Response.ok(jsonEncode({'data': 'Shelf SVM Premium Content'}));
      });

      server = await serve(handler, InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDownAll(() async => await server.close(force: true));

    test('Client returns 402 when SVM payment is denied', () async {
      final svmSigner = await SvmSigner.fromPrivateKeyHex(
        privateKeyHex: svmPrivateKey,
        cluster: SolanaCluster.devnet,
      );

      final client = X402Client(
        signers: [svmSigner],
        onPaymentRequired: (req, resource, signer) async => false,
      );

      addTearDown(() => client.close());

      final uri = Uri.parse('$serverUrl/premium');
      final response = await client.get(uri);

      expect(response.statusCode, equals(402),
          reason:
              'Should return 402 Payment Required when user denies payment');
    });
  });
}
