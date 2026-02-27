import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:x402_core/x402_core.dart';

/// Shelf middleware that protects routes using x402 payments.
///
/// This middleware:
/// - Matches requests against protected routes
/// - Builds payment requirements dynamically
/// - Extracts and verifies payment payloads
/// - Returns `402 Payment Required` when necessary
///
/// All protocol semantics are delegated to [X402ResourceServer].
///
/// The middleware itself is transport orchestration only.
///
/// Example:
/// ```dart
/// final routes = <RoutePattern, RouteConfig>{
///   RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
///     accepts: [
///       PaymentOption(
///         scheme: 'exact',
///         price: Money('0.10'),
///         network: EvmNetwork(chainId: 84532),
///         payTo: '0xYourAddress',
///       ),
///       PaymentOption(
///         scheme: 'exact',
///         price: Money('0.05'),
///         network: SolanaCluster.devnet.network,
///         payTo: 'YourSolanaAddress',
///       ),
///     ],
///     description: 'Access to premium content',
///   ),
/// };
///
/// final handler = Pipeline()
///     .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
///     .addHandler(router);
/// ```
Middleware x402PaymentMiddleware(
  PaymentRoutes routes,
  X402ResourceServer server,
) {
  return (Handler innerHandler) {
    return (Request request) async {
      final matched = _matchRoute(
        routes,
        request.method,
        '/${request.url.path}',
      );

      if (matched == null) {
        return innerHandler(request);
      }

      final (pattern, config) = matched;

      // Build requirements lazily per request
      final requirements = await _buildRequirements(config, server);

      final paymentHeader = request.headers['x-payment-proof'];

      if (paymentHeader == null) {
        return _paymentRequiredResponse(
          pattern,
          config,
          requirements,
        );
      }

      final payload = _parsePayload(paymentHeader);

      if (payload == null) {
        return _paymentRequiredResponse(
          pattern,
          config,
          requirements,
        );
      }

      final matching = server.findMatchingRequirements(
        requirements,
        payload,
      );

      if (matching == null) {
        return _paymentRequiredResponse(
          pattern,
          config,
          requirements,
        );
      }

      final verify = await server.verifyPayment(
        payload,
        matching,
      );

      if (!verify.isValid) {
        return _paymentRequiredResponse(
          pattern,
          config,
          requirements,
        );
      }

      // Payment verified — continue
      return innerHandler(request);
    };
  };
}

(RoutePattern, RouteConfig)? _matchRoute(
  PaymentRoutes routes,
  String method,
  String path,
) {
  for (final entry in routes.entries) {
    if (entry.key.method.value == method && entry.key.normalizedPath == path) {
      return (entry.key, entry.value);
    }
  }
  return null;
}

Future<List<PaymentRequirement>> _buildRequirements(
  RouteConfig config,
  X402ResourceServer server,
) async {
  final requirements = <PaymentRequirement>[];

  for (final option in config.accepts) {
    final resourceConfig = ResourceConfig(
      scheme: option.scheme,
      network: option.network,
      price: option.price,
      payTo: option.payTo,
      maxTimeoutSeconds:
          option.maxTimeoutSeconds ?? ResourceConfig.defaultTimeoutSeconds,
    );

    final requirement = await server.buildPaymentRequirement(resourceConfig);

    requirements.add(requirement);
  }

  return requirements;
}

PaymentPayload? _parsePayload(String header) {
  try {
    final decoded = jsonDecode(header) as Map<String, dynamic>;
    return PaymentPayload.fromJson(decoded);
  } catch (_) {
    return null;
  }
}

Response _paymentRequiredResponse(
  RoutePattern pattern,
  RouteConfig config,
  List<PaymentRequirement> requirements,
) {
  final paymentRequired = PaymentRequiredResponse(
    x402Version: kX402Version,
    error: 'Payment Required',
    resource: ResourceInfo(
      url: pattern.normalizedPath,
      description: config.description ?? 'This resource requires payment.',
      mimeType: 'application/json',
    ),
    accepts: requirements,
  );

  final encoded =
      base64Encode(utf8.encode(jsonEncode(paymentRequired.toJson())));

  return Response(
    402,
    headers: {
      'content-type': 'application/json',
      kPaymentRequiredHeader: encoded,
    },
    body: '',
  );
}
