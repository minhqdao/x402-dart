// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';
import 'package:x402_solana/x402_solana.dart';

// Constants
const _hostname = '0.0.0.0';
const _evmAddress = '0x036CbD53842c5426634e7929541eC2318f3dCF7e'; // Test address
const _solanaAddress = 'GsbwXfJ3G9K7pM6f8h2wJ5kQ9z8y7v4x3n2m1l0k'; // Test address
const _usdcAddress = '0x036CbD53842c5426634e7929541eC2318f3dCF7e'; // Mock USDC
const _usdcName = 'USD Coin';
const _usdcVersion = '2';
const _chainId = 8453; // Base

void main(List<String> args) async {
  final parser = ArgParser()..addOption('port', abbr: 'p', defaultsTo: '8080');
  final result = parser.parse(args);
  final port = int.parse(result['port'] as String);

  // Initialize schemes
  final evmScheme = ExactEvmSchemeServer();
  final solanaScheme = ExactSolanaSchemeServer();

  // Define requirements
  const requirements = [
    PaymentRequirements(
      network: 'eip155:$_chainId',
      asset: _usdcAddress,
      maxAmountRequired: '1000000', // 1 USDC
      maxTimeoutSeconds: 3600,
      payTo: _evmAddress,
      scheme: 'exact',
      resource: '/premium-content',
      description: 'Premium content access',
      mimeType: 'application/json',
      extra: {'name': _usdcName, 'version': _usdcVersion},
    ),
    PaymentRequirements(
      network: 'solana:mainnet',
      asset: _usdcAddress, // Mock
      maxAmountRequired: '1000000',
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

      bool isValid = false;
      if (payload.scheme == 'exact' && payload.network.startsWith('eip155')) {
        isValid = await evmScheme.verifyPayload(payload, requirement);
      } else if (payload.scheme == 'exact' &&
          payload.network.startsWith('solana')) {
        isValid = await solanaScheme.verifyPayload(payload, requirement);
      }

      if (isValid) {
        return Response.ok(
          jsonEncode({'content': 'Here is your premium content! 🚀'}),
          headers: const {'content-type': 'application/json'},
        );
      } else {
        return Response.forbidden('Invalid payment signature');
      }
    } catch (e) {
      print('Error verifying payment: $e');
      return Response.forbidden('Invalid payment payload');
    }
  });

  // CORS middleware
  final handler = const Pipeline().addMiddleware(corsHeaders()).addHandler(app.call);

  final server = await io.serve(handler, _hostname, port);
  print('Serving at http://${server.address.host}:${server.port}');
}

Response _paymentRequired(List<PaymentRequirements> requirements) {
  final response = PaymentRequiredResponse(
    x402Version: 1,
    accepts: requirements,
  );

  return Response(
    402,
    body: jsonEncode(response.toJson()),
    headers: const {
      'content-type': 'application/json',
      'WWW-Authenticate': '402',
    },
  );
}
