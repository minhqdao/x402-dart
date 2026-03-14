import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:test/test.dart';
import 'package:x402/x402.dart';
import 'package:x402_shelf/x402_shelf.dart';

void main() {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  late final HttpServer server;
  late final X402ResourceServer resourceServer;
  late final String serverUrl;
  late final Uri uri;

  final evmAddress = env['EVM_ADDRESS'];
  if (evmAddress == null || evmAddress.isEmpty) {
    fail('EVM_ADDRESS is not set in environment or .env file.');
  }

  final svmAddress = env['SVM_ADDRESS'];
  if (svmAddress == null || svmAddress.isEmpty) {
    fail('SVM_ADDRESS is not set in environment or .env file.');
  }

  final evmPrivateKey = env['EVM_PRIVATE_KEY_PAYER'];
  if (evmPrivateKey == null || evmPrivateKey.isEmpty) {
    fail('EVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
  }

  final svmPrivateKey = env['SVM_PRIVATE_KEY_PAYER'];
  if (svmPrivateKey == null || svmPrivateKey.isEmpty) {
    fail('SVM_PRIVATE_KEY_PAYER is not set in environment or .env file.');
  }

  setUpAll(() async {
    // 1. Create Resource Server
    resourceServer = await X402ResourceServer.create(
      schemeServers: [
        ExactEvmSchemeServer(chainId: 84532),
        ExactSvmSchemeServer(cluster: SolanaCluster.devnet)
      ],
    );

    // 2. Define Protected Routes
    final routes = {
      const RoutePattern(HttpMethod.get, '/premium'): RouteConfig(
        accepts: [
          PaymentOption(
            scheme: 'exact',
            price: const Money('0.001'),
            network: const EvmNetwork(chainId: 84532),
            payTo: evmAddress,
          ),
          PaymentOption(
            scheme: 'exact',
            price: const Money('0.001'),
            network: const SolanaNetwork.devnet(),
            payTo: svmAddress,
          ),
        ],
        description: 'Premium content via Shelf',
      ),
    };

    // 3. Setup Shelf Pipeline
    final handler = const Pipeline()
        .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
        .addHandler((request) {
      if (request.url.path == 'premium') {
        return Response.ok(jsonEncode({'data': 'Shelf Premium Content'}));
      }
      return Response.notFound('Not Found');
    });

    // 4. Start Server
    server = await serve(handler, InternetAddress.loopbackIPv4, 0);
    serverUrl = 'http://${server.address.host}:${server.port}';
    uri = Uri.parse('$serverUrl/premium');
  });

  tearDownAll(() async => await server.close(force: true));

  test('Pays on EVM and accesses Shelf server premium content', () async {
    final evmSigner = EvmSigner.fromPrivateKeyHex(
      privateKeyHex: evmPrivateKey,
      chainId: 84532,
    );

    final client = X402Client(
      signers: [evmSigner],
      retryDelay: const Duration(seconds: 1),
    );

    addTearDown(() => client.close());

    final response = await client.get(uri);

    expect(response.statusCode, equals(200),
        reason: 'Should return 200 OK after successful payment');

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    expect(body['data'], equals('Shelf Premium Content'));
  });

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

    final response = await client.get(uri);

    expect(response.statusCode, equals(402),
        reason: 'Should return 402 Payment Required when user denies payment');
  });

  test('Pays on SVM and accesses Shelf server premium content', () async {
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
    expect(body['data'], equals('Shelf Premium Content'));
  }, timeout: const Timeout(Duration(minutes: 1)));

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
        reason: 'Should return 402 Payment Required when user denies payment');
  }, timeout: const Timeout(Duration(minutes: 1)));
}
