import 'package:shelf/shelf.dart';

/// Shelf-specific request context provided to [UnpaidResponseBody] callbacks.
///
/// Contains information about the request that failed payment verification.
/// Provides access to the full shelf [Request] object and extracted metadata.
class ShelfRequestContext {
  /// The original shelf request object
  final Request request;

  /// The request path (e.g., 'GET /api/data')
  final String path;

  /// The HTTP method (e.g., 'GET', 'POST')
  final String method;

  /// The payment proof header value, if provided
  final String? paymentHeader;

  const ShelfRequestContext({
    required this.request,
    required this.path,
    required this.method,
    this.paymentHeader,
  });
}
