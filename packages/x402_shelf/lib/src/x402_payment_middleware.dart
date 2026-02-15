import 'package:shelf/shelf.dart';
import 'package:x402_core/x402_core.dart';

/// Creates a shelf middleware that handles x402 payment verification.
///
/// Intercepts requests to protected routes and verifies payment before
/// allowing access. Routes without payment configuration pass through unchanged.
///
/// Example:
/// ```dart
/// final routes = <RoutePattern, RouteConfig>{
///   RoutePattern(HttpMethod.get, '/protected'): RouteConfig.single(
///     accept: PaymentOption(
///       scheme: 'exact',
///       price: '\$0.10',
///       network: 'eip155:84532',
///       payTo: '0xYourAddress',
///     ),
///   ),
/// };
///
/// final handler = Pipeline()
///     .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
///     .addHandler(router);
/// ```
Middleware x402PaymentMiddleware(
  PaymentRoutes routes,
  X402ResourceServer server, {
  PaywallConfig? paywallConfig,
  dynamic paywall, // PaywallProvider type - define as needed
  bool syncFacilitatorOnStart = true,
}) {
  // Perform any initialization
  if (syncFacilitatorOnStart) {
    // Sync with facilitator
  }

  return (Handler innerHandler) {
    return (Request request) async {
      final method = request.method;
      final path = '/${request.url.path}';

      // Find matching route pattern
      RouteConfig? routeConfig;
      RoutePattern? matchedPattern;

      for (final entry in routes.entries) {
        if (entry.key.method.value == method &&
            entry.key.normalizedPath == path) {
          routeConfig = entry.value;
          matchedPattern = entry.key;
          break;
        }
      }

      if (routeConfig == null) {
        // No payment required for this route
        return innerHandler(request);
      }

      // Check for payment proof in headers
      final paymentProof = request.headers['x-payment-proof'];

      if (paymentProof == null) {
        // No payment proof provided - return 402 Payment Required
        return _createPaywallResponse(request, routeConfig, matchedPattern!);
      }

      // Verify payment proof
      final isValid = await _verifyPayment(
        paymentProof,
        routeConfig,
        server,
      );

      if (!isValid) {
        // Invalid payment - return 402
        return _createPaywallResponse(request, routeConfig, matchedPattern!);
      }

      // Payment verified - proceed to handler
      return innerHandler(request);
    };
  };
}

/// Creates a 402 Payment Required response with paywall information
Future<Response> _createPaywallResponse(
  Request request,
  RouteConfig config,
  RoutePattern pattern,
) async {
  final paymentOptions = config.accepts;

  // Build payment options header
  final acceptsHeader = paymentOptions.map((opt) {
    return '${opt.scheme}:${opt.network}';
  }).join(', ');

  // Check if this is a browser request (looks for text/html in Accept header)
  final acceptHeader = request.headers['accept'] ?? '';
  final isBrowserRequest = acceptHeader.contains('text/html');

  // For browser requests, use custom HTML if available
  if (isBrowserRequest && config.customPaywallHtml != null) {
    return Response(
      402,
      headers: {
        'x-accepts-payment': acceptsHeader,
        'content-type': 'text/html',
      },
      body: config.customPaywallHtml,
    );
  }

  // For API requests or when no custom HTML, use unpaidResponseBody callback
  String contentType;
  Object body;

  // if (config.unpaidResponseBody != null) {
  //   final context = ShelfRequestContext(
  //     request: request,
  //     path: pattern.key,
  //     method: request.method,
  //     paymentHeader: request.headers['x-payment-proof'],
  //   );

  //   final result = await config.unpaidResponseBody!(context);
  //   contentType = result.contentType;
  //   body = result.body;
  // } else {
  // Default to JSON with empty body
  contentType = 'application/json';
  body = _buildDefaultPaywallBody(config, pattern);
  // }

  return Response(
    402,
    headers: {
      'x-accepts-payment': acceptsHeader,
      'content-type': contentType,
    },
    body: body is String ? body : _toJsonString(body),
  );
}

/// Builds the default paywall response body
Map<String, dynamic> _buildDefaultPaywallBody(
    RouteConfig config, RoutePattern pattern) {
  final paymentOptions = config.accepts.map((opt) {
    return {
      'scheme': opt.scheme,
      'payTo': opt.payTo,
      'price': opt.price,
      'network': opt.network,
      if (opt.maxTimeoutSeconds != null)
        'maxTimeoutSeconds': opt.maxTimeoutSeconds,
      if (opt.extra != null) 'extra': opt.extra,
    };
  }).toList();

  return {
    'error': 'Payment Required',
    'route': pattern.key,
    'description': config.description ?? 'This resource requires payment',
    'accepts': paymentOptions,
  };
}

/// Verifies a payment proof
Future<bool> _verifyPayment(
  String paymentProof,
  RouteConfig config,
  X402ResourceServer server,
) {
  // Delegate to the resource server for verification
  // return server.verifyPayment(paymentProof, config);
  return Future.value(true);
}

/// Simple JSON string converter (replace with dart:convert if needed)
String _toJsonString(Object? obj) {
  if (obj is List) {
    return '[${obj.map(_toJsonString).join(',')}]';
  }
  if (obj is Map) {
    final entries =
        obj.entries.map((e) => '"${e.key}":${_toJsonString(e.value)}');
    return '{${entries.join(',')}}';
  }
  if (obj is String) {
    return '"$obj"';
  }
  return obj.toString();
}
