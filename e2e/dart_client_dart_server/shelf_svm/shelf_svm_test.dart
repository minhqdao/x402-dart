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

  group('Shelf Server + Client Wrapper E2E (SVM)', () {
    late HttpServer server;
    late X402ResourceServer resourceServer;
    late String serverUrl;

    final facilitatorUrl = env['FACILITATOR_URL'];
    final svmAddress = env['SVM_ADDRESS'];
    if (svmAddress == null || svmAddress.isEmpty) {
      fail('SVM_ADDRESS is not set in environment or .env file.');
    }

    final svmPrivateKey = env['SVM_PRIVATE_KEY_PAYER'];
    if (svmPrivateKey == null || svmPrivateKey.isEmpty) {
      fail('SVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    setUpAll(() async {
      // 1. Create Resource Server
      // If FACILITATOR_URL is missing, we try to connect to the local TS facilitator
      // which is usually running at :4022 in the E2E environment.
      final List<FacilitatorClient> facilitators = [];
      if (facilitatorUrl != null) {
        facilitators.add(HttpFacilitatorClient(url: facilitatorUrl));
      } else {
        // Try common local/CI facilitator locations for SVM support
        for (final url in [
          kDefaultFacilitatorUrl,
          'http://127.0.0.1:4022',
          'http://facilitator:4022',
        ]) {
          try {
            final client = HttpFacilitatorClient(url: url);
            final supported = await client.getSupported();
            if (supported.kinds.any((k) =>
                k.scheme == 'exact' && k.network.namespace == 'solana')) {
              facilitators.add(client);
              break;
            }
          } catch (_) {
            continue;
          }
        }
      }

      if (facilitators.isEmpty) {
        fail('No facilitator found that supports Solana payments.');
      }

      resourceServer = await X402ResourceServer.create(
        facilitators: facilitators,
        schemeServers: [
          ExactSvmSchemeServer(cluster: SolanaCluster.devnet),
        ],
      );

      // 2. Define Protected Routes
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

      // 3. Setup Shelf Pipeline
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler((request) {
        return Response.ok(jsonEncode({'data': 'Shelf SVM Premium Content'}));
      });

      // 4. Start Server
      server = await serve(handler, InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDownAll(() async => await server.close(force: true));

    test('Client pays and accesses Shelf server SVM premium content', () async {
      final svmSigner = await SvmSigner.fromPrivateKeyHex(
        privateKeyHex: svmPrivateKey,
        cluster: SolanaCluster.devnet,
      );

      final client = X402Client(
        signers: [svmSigner],
        retryDelay: const Duration(seconds: 1),
      );

      addTearDown(() => client.close());

      final uri = Uri.parse('$serverUrl/premium');
      final response = await client.get(uri);

      expect(response.statusCode, equals(200),
          reason: 'Should return 200 OK after successful SVM payment');

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['data'], equals('Shelf SVM Premium Content'));
    });
  });
}
