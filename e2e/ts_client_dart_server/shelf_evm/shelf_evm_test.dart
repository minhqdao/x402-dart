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

  Future<void> ensureNodeAvailable() async {
    final node = await Process.run('node', ['--version']);
    if (node.exitCode != 0) {
      markTestSkipped('Node.js not installed');
    }

    final npx = await Process.run('npx', ['--version']);
    if (npx.exitCode != 0) {
      throw Exception('npx is required for TS client e2e tests.');
    }
  }

  group('TS Client + Shelf Server E2E (EVM)', () {
    late HttpServer server;
    late X402ResourceServer resourceServer;
    late String serverUrl;

    final evmAddress = env['EVM_ADDRESS'];
    if (evmAddress == null || evmAddress.isEmpty) {
      throw Exception('EVM_ADDRESS is not set in environment or .env file.');
    }

    final evmPrivateKeyPayer = env['EVM_PRIVATE_KEY_PAYER'];
    if (evmPrivateKeyPayer == null || evmPrivateKeyPayer.isEmpty) {
      throw Exception('EVM_PRIVATE_KEY_PAYER is not set.');
    }

    setUpAll(() async {
      await ensureNodeAvailable();

      // 1. Create Resource Server
      resourceServer = await X402ResourceServer.create(
        schemeServers: [ExactEvmSchemeServer(chainId: 84532)],
      );

      // 2. Define Protected Routes
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
          description: 'Premium content for TS client',
        ),
      };

      // 3. Setup Shelf Pipeline
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler((request) {
        if (request.url.path == 'premium') {
          return Response.ok(
              jsonEncode({'success': true, 'data': 'TS Client Reward'}));
        }
        return Response.notFound('Not Found');
      });

      // 4. Start Server
      server = await serve(handler, InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${server.address.host}:${server.port}';
    });

    tearDownAll(() async => await server.close(force: true));

    test('TS client successfully pays and accesses premium content', () async {
      // Execute TS client
      final result = await Process.run(
        'npm',
        ['run', 'ts-client-evm'],
        workingDirectory: 'e2e',
        environment: {
          ...Platform.environment,
          'EVM_PRIVATE_KEY': evmPrivateKeyPayer,
          'RESOURCE_SERVER_URL': serverUrl,
        },
      ).timeout(const Duration(seconds: 30));

      stdout.writeln('TS Client STDOUT:');
      stdout.writeln(result.stdout);
      stderr.writeln('TS Client STDERR:');
      stderr.writeln(result.stderr);

      if (result.exitCode != 0) {
        fail(
            'TS client failed.\nSTDOUT:\n${result.stdout}\nSTDERR:\n${result.stderr}');
      }
      expect(result.stdout, contains('TS Client Reward'));
    });
  });
}
