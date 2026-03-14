import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:x402/x402.dart';
import 'package:x402_shelf/x402_shelf.dart';

void main() async {
  // Load environment variables
  final env = DotEnv(includePlatformEnvironment: true)..load();

  final evmAddress = env['EVM_ADDRESS'];
  if (evmAddress == null || evmAddress.isEmpty) {
    throw Exception('EVM_ADDRESS is not set in environment or .env file.');
  }

  final svmAddress = env['SVM_ADDRESS'];
  if (svmAddress == null || svmAddress.isEmpty) {
    throw Exception('SVM_ADDRESS is not set in environment or .env file.');
  }

  // 1. Define Protected Routes
  final routes = {
    const RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
      accepts: [
        PaymentOption(
          scheme: 'exact',
          price: const Money('0.000001'),
          network: const EvmNetwork(chainId: 84532),
          payTo: evmAddress,
        ),
        PaymentOption(
          scheme: 'exact',
          price: const Money('0.000001'),
          network: const SolanaNetwork.devnet(),
          payTo: svmAddress,
        ),
      ],
      description: 'Access to premium content',
    ),
  };

  // 2. Create a Resource Server
  // This uses the default facilitator (https://x402.org/facilitator)
  stdout.writeln('Initializing Resource Server...');
  final resourceServer = await X402ResourceServer.create(
    schemeServers: [
      ExactEvmSchemeServer(chainId: 84532),
      ExactSvmSchemeServer(cluster: SolanaCluster.devnet),
    ],
  );
  stdout.writeln('Resource Server initialized.');

  // 3. Simple Handler
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
      .addHandler((request) {
    if (request.url.path == 'public') {
      return Response.ok('This is a public route.\n');
    } else if (request.url.path == 'protected') {
      return Response.ok('✅ Payment verified!\n');
    }
    return Response.notFound('Not Found\n');
  });

  // 4. Start the Server
  final server = await serve(handler, InternetAddress.anyIPv4, 8080);
  stdout
    ..writeln('🚀 Server listening on http://localhost:${server.port}')
    ..writeln('   Protected route: http://localhost:${server.port}/protected')
    ..writeln('   Public route:    http://localhost:${server.port}/public');
}
