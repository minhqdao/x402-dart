import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/x402_svm.dart';

// Constants
const _hostname = '0.0.0.0';
const _solanaAddress = 'mvines9iiHiQTysrwkTjMcDYC5WzZhVp85694463d74'; // Test address
const _usdcAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'; // Mainnet USDC

void main(List<String> args) async {
  final parser = ArgParser()..addOption('port', abbr: 'p');
  final result = parser.parse(args);
  final port = int.parse(result['port'] as String);

  // Initialize scheme
  final svmScheme = ExactSvmSchemeServer();

  // Define requirements
  const requirements = [
    X402Requirement(
      network: 'svm:mainnet',
      asset: _usdcAddress,
      amount: '1000000', // 1 USDC
      maxTimeoutSeconds: 3600,
      payTo: _solanaAddress,
      scheme: 'exact',
      resource: '/premium-content',
      description: 'Premium content access',
      mimeType: 'application/json',
    ),
  ];

  final app = Router();

  app.get('/premium-content', (Request request) async {
    // Check for payment signature in standard v2 header or legacy header
    String? token = request.headers[kPaymentSignatureHeader];
    token ??= request.headers[kPaymentHeader.toLowerCase()];

    // Also check Authorization header for backward compatibility
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

      final isValid = await svmScheme.verifyPayload(payload, requirement);

      if (isValid) {
        return Response.ok(
          jsonEncode({'content': 'Here is your premium SVM content! ☀️'}),
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
    'SVM Server serving at http://${server.address.host}:${server.port}',
  );
}

Response _paymentRequired(List<X402Requirement> requirements) {
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
