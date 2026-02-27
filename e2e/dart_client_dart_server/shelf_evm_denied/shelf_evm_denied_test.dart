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

  group('Shelf Server + Client Wrapper E2E Denied (EVM)', () {
    late HttpServer server;
    late X402ResourceServer resourceServer;
    late String serverUrl;

    final facilitatorUrl = env['FACILITATOR_URL'];
    final evmAddress = env['EVM_ADDRESS'];
    if (evmAddress == null || evmAddress.isEmpty) {
      fail('EVM_ADDRESS is not set in environment or .env file.');
    }

    final evmPrivateKey = env['EVM_PRIVATE_KEY_PAYER'];
    if (evmPrivateKey == null || evmPrivateKey.isEmpty) {
      fail('EVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
    }

    setUpAll(() async {
      final List<FacilitatorClient> facilitators = [];
      if (facilitatorUrl != null) {
        facilitators.add(HttpFacilitatorClient(url: facilitatorUrl));
      } else {
        for (final url in [
          kDefaultFacilitatorUrl,
          'http://127.0.0.1:4022',
          'http://facilitator:4022',
        ]) {
          try {
            final client = HttpFacilitatorClient(url: url);
            final supported = await client.getSupported();
            if (supported.kinds.any((k) =>
                k.scheme == 'exact' && k.network.namespace == 'eip155')) {
              facilitators.add(client);
              break;
            }
          } catch (_) {
            continue;
          }
        }
      }

      if (facilitators.isEmpty) {
        fail('No facilitator found that supports EVM payments.');
      }

      resourceServer = await X402ResourceServer.create(
        facilitators: facilitators,
        schemeServers: [
          ExactEvmSchemeServer(chainId: 84532),
        ],
      );

      final routes = {
        const RoutePattern(HttpMethod.get, '/premium'): RouteConfig(
          accepts: [
            PaymentOption(
              scheme: 'exact',
              price: const Money('0.10'),
              network: const EvmNetwork(chainId: 84532),
              payTo: evmAddress,
            ),
          ],
          description: 'Premium content via Shelf',
        ),
      };

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler((request) {
        return Response.ok(jsonEncode({'data': 'Shelf Premium Content'}));
      });

      server = await serve(handler, InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDownAll(() async => await server.close(force: true));

    test('Client returns 402 when EVM payment is denied', () async {
      final evmSigner = EvmSigner.fromPrivateKeyHex(
        privateKeyHex: evmPrivateKey,
        chainId: 84532,
      );

      final client = X402Client(
        signers: [evmSigner],
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
