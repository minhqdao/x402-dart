import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_solana/x402_solana.dart';

// Constants
const _hostname = '0.0.0.0';
const _solanaAddress = 'mvines9iiHiQTysrwkTjMcDYC5WzZhVp85694463d74'; // Test address
const _usdcAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'; // Mainnet USDC

void main(List<String> args) async {
  final parser = ArgParser()..addOption('port', abbr: 'p', defaultsTo: '8081');
  final result = parser.parse(args);
  final port = int.parse(result['port'] as String);

  // Initialize scheme
  final solanaScheme = ExactSolanaSchemeServer();

  // Define requirements
  const requirements = [
    PaymentRequirements(
      network: 'solana:mainnet',
      asset: _usdcAddress,
      maxAmountRequired: '1000000', // 1 USDC
      maxTimeoutSeconds: 3600,
      payTo: _solanaAddress,
      scheme: 'exact',
      resource: '/premium-content',
      description: 'Premium content access',
      mimeType: 'application/json',
      extra: {},
    ),
  ];

  final app = Router();

  app.get('/premium-content', (Request request) async {
    final authHeader = request.headers['Authorization'];

    if (authHeader == null || !authHeader.startsWith('402 ')) {
      return _paymentRequired(requirements);
    }

    final token = authHeader.substring(4);
    try {
      final json = jsonDecode(utf8.decode(base64Decode(token)));
      final payload = PaymentPayload.fromJson(json as Map<String, dynamic>);

      // Find matching requirement
      final requirement = requirements.firstWhere(
        (r) => r.network == payload.network && r.scheme == payload.scheme,
        orElse:
            () => throw Exception(
              'No matching requirement found for ${payload.network}',
            ),
      );

      final isValid = await solanaScheme.verifyPayload(payload, requirement);

      if (isValid) {
        return Response.ok(
          jsonEncode({'content': 'Here is your premium Solana content! ☀️'}),
          headers: const {'content-type': 'application/json'},
        );
      } else {
        return Response.forbidden('Invalid payment signature');
      }
    } catch (e) {
      stdout.writeln('Error verifying payment: $e');
      return Response.forbidden('Invalid payment payload');
    }
  });

  // CORS middleware
  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
      .addHandler(app.call);

  final server = await io.serve(handler, _hostname, port);
  stdout.writeln(
    'Solana Server serving at http://${server.address.host}:${server.port}',
  );
}

Response _paymentRequired(List<PaymentRequirements> requirements) {
  final response = PaymentRequiredResponse(x402Version: 1, accepts: requirements);

  return Response(
    402,
    body: jsonEncode(response.toJson()),
    headers: const {
      'content-type': 'application/json',
      'WWW-Authenticate': '402',
    },
  );
}