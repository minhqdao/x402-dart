import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

// Constants
const _hostname = '0.0.0.0';
const _evmAddress = '0x036CbD53842c5426634e7929541eC2318f3dCF7e'; // Test address
const _usdcAddress = '0x036CbD53842c5426634e7929541eC2318f3dCF7e'; // Mock USDC
const _usdcName = 'USD Coin';
const _usdcVersion = '2';
const _chainId = 8453; // Base

void main(List<String> args) async {
  final parser = ArgParser()..addOption('port', abbr: 'p', defaultsTo: '8080');
  final result = parser.parse(args);
  final port = int.parse(result['port'] as String);

  // Initialize scheme
  final evmScheme = ExactEvmSchemeServer();

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
  ];

  final app = Router();

  app.get('/premium-content', (Request request) async {
    // Check for payment signature in standard v2 header or legacy header
    String? token = request.headers[kPaymentSignatureHeader];
    token ??= request.headers[kPaymentHeader.toLowerCase()];

    // Also check Authorization header for backward compatibility with initial examples
    final authHeader = request.headers['Authorization'];
    if (token == null && authHeader != null && authHeader.startsWith('402 ')) {
      token = authHeader.substring(4);
    }

    if (token == null) {
      return _paymentRequired(requirements);
    }

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

      final isValid = await evmScheme.verifyPayload(payload, requirement);

      if (isValid) {
        return Response.ok(
          jsonEncode({'content': 'Here is your premium EVM content! 🚀'}),
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
    'EVM Server serving at http://${server.address.host}:${server.port}',
  );
}

Response _paymentRequired(List<PaymentRequirements> requirements) {
  final response = PaymentRequiredResponse(
    x402Version: kX402Version,
    accepts: requirements,
  );

  final responseJson = jsonEncode(response.toJson());
  final base64Response = base64Encode(utf8.encode(responseJson));

  return Response(
    kPaymentRequiredStatus,
    body: responseJson,
    headers: {
      'content-type': 'application/json',
      'WWW-Authenticate': '402',
      kPaymentRequiredHeader: base64Response,
    },
  );
}
