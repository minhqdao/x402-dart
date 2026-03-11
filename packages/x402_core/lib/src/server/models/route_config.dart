import 'package:x402_core/src/server/models/payment_option.dart';

/// Configuration for a protected route.
///
/// A route may define one or more accepted payment options.
/// Each [PaymentOption] represents a valid way a client can
/// pay to access the resource.
///
/// If multiple options are provided, the client may satisfy
/// any one of them. The server evaluates the configured options in order and
/// selects the first requirement that matches the provided payload.
/// Matching and verification are handled by [X402ResourceServer].
///
/// This class contains route-level metadata only.
/// Payment semantics are delegated to the resource server.
///
/// Fields:
/// - [accepts]: List of accepted payment options (must not be empty)
/// - [resource]: Optional logical resource identifier
/// - [description]: Human-readable description of the resource
/// - [mimeType]: Optional content type hint
/// - [customPaywallHtml]: Optional HTML paywall for browser clients
/// - [extensions]: Optional scheme-specific metadata
///
/// Note:
/// For API clients, a JSON 402 response is returned.
/// For browser requests (`Accept: text/html`), the custom
/// paywall HTML takes precedence if provided.
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
  }) : assert(accepts.length > 0, 'RouteConfig.accepts must not be empty');
}
