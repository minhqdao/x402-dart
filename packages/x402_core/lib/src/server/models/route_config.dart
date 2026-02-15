import 'package:x402_core/src/server/models/payment_option.dart';
import 'package:x402_core/src/server/models/route_pattern.dart';

/// Payment routes configuration
typedef PaymentRoutes = Map<RoutePattern, RouteConfig>;

/// Configuration for a single route
class RouteConfig {
  final List<PaymentOption> accepts;
  final String? resource;
  final String? description;
  final String? mimeType;
  final String? customPaywallHtml;

  /// Optional callback to generate a custom response for unpaid API requests.
  /// This allows servers to return preview data, error messages, or other content
  /// when a request lacks payment.
  ///
  /// For browser requests (Accept: text/html), the paywall HTML takes precedence.
  /// This callback is only used for API clients.
  ///
  /// If not provided, defaults to `{ contentType: 'application/json', body: {} }`.
  // final UnpaidResponseBody? unpaidResponseBody;
  final Map<String, dynamic>? extensions;

  const RouteConfig({
    required this.accepts,
    this.resource,
    this.description,
    this.mimeType,
    this.customPaywallHtml,
    // this.unpaidResponseBody,
    this.extensions,
  });
}
