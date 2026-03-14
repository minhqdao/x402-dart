import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:x402/x402.dart';

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

  // 3. Start the Server
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  stdout
    ..writeln('🚀 Server listening on http://localhost:${server.port}')
    ..writeln('   Protected route: http://localhost:${server.port}/protected')
    ..writeln('   Public route:    http://localhost:${server.port}/public');

  // 4. Handle Requests
  await for (final request in server) {
    final status = await _handleRequest(request, routes, resourceServer);
    stdout.writeln('$status ${request.method} ${request.uri.path}');
  }
}

Future<int> _handleRequest(
  HttpRequest request,
  Map<RoutePattern, RouteConfig> routes,
  X402ResourceServer resourceServer,
) async {
  final method = request.method;
  final path = request.uri.path;

  // Public route — no payment required
  if (method == 'GET' && path == '/public') {
    request.response
      ..statusCode = HttpStatus.ok
      ..write('This is a public route.\n');
    await request.response.close();
    return HttpStatus.ok;
  }

  // Match against protected routes
  RoutePattern? matchedPattern;
  RouteConfig? matchedConfig;
  for (final entry in routes.entries) {
    if (entry.key.method.value == method && entry.key.normalizedPath == path) {
      matchedPattern = entry.key;
      matchedConfig = entry.value;
      break;
    }
  }

  // Not a protected route
  if (matchedPattern == null || matchedConfig == null) {
    request.response
      ..statusCode = HttpStatus.notFound
      ..write('Not Found\n');
    await request.response.close();
    return HttpStatus.notFound;
  }

  // Build payment requirements
  final requirements = <PaymentRequirement>[];
  for (final option in matchedConfig.accepts) {
    final resourceConfig = ResourceConfig(
      scheme: option.scheme,
      network: option.network,
      price: option.price,
      payTo: option.payTo,
      maxTimeoutSeconds:
          option.maxTimeoutSeconds ?? ResourceConfig.defaultTimeoutSeconds,
    );
    requirements
        .add(await resourceServer.buildPaymentRequirement(resourceConfig));
  }

  // Check for payment header
  final paymentHeader = request.headers.value(kPaymentSignatureHeader) ??
      request.headers.value(kPaymentHeader);

  if (paymentHeader == null) {
    _send402(request.response, resourceServer, matchedPattern, matchedConfig,
        requirements);
    return HttpStatus.paymentRequired;
  }

  // Parse payload
  PaymentPayload? payload;
  try {
    final decodedJson = utf8.decode(base64Decode(paymentHeader));
    final decoded = jsonDecode(decodedJson) as Map<String, dynamic>;
    payload = PaymentPayload.fromJson(decoded);
  } catch (_) {
    _send402(request.response, resourceServer, matchedPattern, matchedConfig,
        requirements);
    return HttpStatus.paymentRequired;
  }

  // Match requirements
  final matching =
      resourceServer.findMatchingRequirements(requirements, payload);
  if (matching == null) {
    _send402(request.response, resourceServer, matchedPattern, matchedConfig,
        requirements);
    return HttpStatus.paymentRequired;
  }

  // Verify
  final verify = await resourceServer.verifyPayment(payload, matching);
  if (!verify.isValid) {
    _send402(request.response, resourceServer, matchedPattern, matchedConfig,
        requirements);
    return HttpStatus.paymentRequired;
  }

  // Settle
  final settle = await resourceServer.settlePayment(payload, matching);
  if (!settle.success) {
    request.response
      ..statusCode = HttpStatus.internalServerError
      ..write('Payment settlement failed\n');
    await request.response.close();
    return HttpStatus.internalServerError;
  }

  // Success — serve protected content
  request.response
    ..statusCode = HttpStatus.ok
    ..headers.set(kPaymentResponseHeader, settle.encoded)
    ..write(jsonEncode({
      'message': '✅ Payment verified!\n',
      'x402': {
        'payer': settle.payer,
        'transaction': settle.transaction,
      },
      'data': '✅ Premium content here',
    }));
  await request.response.close();
  return HttpStatus.ok;
}

Future<void> _send402(
  HttpResponse response,
  X402ResourceServer resourceServer,
  RoutePattern pattern,
  RouteConfig config,
  List<PaymentRequirement> requirements,
) async {
  final header = resourceServer.buildPaymentRequiredHeader(
    resourceUrl: pattern.normalizedPath,
    description: config.description,
    requirements: requirements,
  );

  response
    ..statusCode = 402
    ..headers.set('content-type', 'application/json')
    ..headers.set(kPaymentRequiredHeader, header)
    ..write('{}');
  await response.close();
}
