import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart' as evm;

// Constants
const _hostname = '0.0.0.0';

void main(List<String> args) async {
  final parser = ArgParser()..addOption('port', abbr: 'p', defaultsTo: '8082');
  final result = parser.parse(args);
  final port = int.parse(result['port'] as String);

  // 1. Start a mock Facilitator Server
  final facilitatorPort = port + 100;
  await _startMockFacilitator(facilitatorPort);
  stdout.writeln('Mock Facilitator running at http://localhost:$facilitatorPort');

  // 2. Initialize Facilitator Client
  final facilitatorClient = evm.HttpFacilitatorClient(baseUrl: 'http://localhost:$facilitatorPort');

  // 3. Define requirements for multiple chains
  const requirements = [
    PaymentRequirement(
      network: 'eip155:8453',
      asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      amount: '1000000',
      maxTimeoutSeconds: 3600,
      payTo: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      scheme: 'exact',
      resource: '/premium-content',
      description: 'Multi-chain premium access',
      mimeType: 'application/json',
      data: {'name': 'USD Coin', 'version': '2'},
    ),
    PaymentRequirement(
      network: 'svm:mainnet',
      asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
      amount: '1000000',
      maxTimeoutSeconds: 3600,
      payTo: 'mvines9iiHiQTysrwkTjMcDYC5WzZhVp85694463d74',
      scheme: 'exact',
      resource: '/premium-content',
      description: 'Multi-chain premium access',
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
        orElse: () => throw Exception('No matching requirement found for ${payload.network}'),
      );

      stdout.writeln('Verifying payment via facilitator...');
      final verifyResp = await facilitatorClient.verify(
        x402Version: kX402Version,
        paymentHeader: token,
        requirement: requirement,
      );

      if (!verifyResp.isValid) {
        return Response.forbidden('Payment verification failed');
      }

      stdout.writeln('Settling payment via facilitator...');
      final settleResp = await facilitatorClient.settle(
        x402Version: kX402Version,
        paymentHeader: token,
        requirement: requirement,
      );

      if (settleResp.success) {
        stdout.writeln('Payment settled! TX: ${settleResp.txHash}');
        return Response.ok(
          jsonEncode({'content': 'Multi-chain premium content! 🌐', 'txHash': settleResp.txHash}),
          headers: const {'content-type': 'application/json'},
        );
      } else {
        return Response.internalServerError(body: 'Settlement failed');
      }
    } catch (e) {
      stdout.writeln('Error: $e');
      return Response.forbidden('Invalid payment payload or facilitator error');
    }
  });

  final handler = const Pipeline().addMiddleware(corsHeaders()).addHandler(app.call);

  final server = await io.serve(handler, _hostname, port);
  stdout.writeln('Facilitator-backed Server serving at http://${server.address.host}:${server.port}');
}

Response _paymentRequired(List<PaymentRequirement> requirements) {
  final response = PaymentRequiredResponse(x402Version: kX402Version, accepts: requirements);

  final responseJson = jsonEncode(response.toJson());
  final base64Response = base64Encode(utf8.encode(responseJson));

  return Response(
    kPaymentRequiredStatus,
    body: responseJson,
    headers: {'content-type': 'application/json', 'WWW-Authenticate': '402', kPaymentRequiredHeader: base64Response},
  );
}

/// A very simple mock Facilitator server for demonstration
Future<void> _startMockFacilitator(int port) async {
  final router = Router();

  router.post('/verify', (Request request) {
    // In a real facilitator, this would cryptographically verify the signature/transaction
    return Response.ok(jsonEncode({'isValid': true}));
  });

  router.post('/settle', (Request request) {
    // In a real facilitator, this would submit the transaction to the blockchain
    return Response.ok(
      jsonEncode({
        'success': true,
        'txHash': '0x${'f' * 64}', // Mock hash
      }),
    );
  });

  router.get('/supported', (Request request) {
    return Response.ok(
      jsonEncode({
        'kinds': [
          {'scheme': 'exact', 'network': 'eip155:8453'},
          {'scheme': 'exact', 'network': 'svm:mainnet'},
        ],
      }),
    );
  });

  await io.serve(router.call, 'localhost', port);
}
