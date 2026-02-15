// /// Callback function to generate custom responses for unpaid API requests.
// ///
// /// Invoked when a request lacks valid payment and is not a browser request.
// /// For browser requests, [RouteConfig.customPaywallHtml] takes precedence.
// ///
// /// Example:
// /// ```dart
// /// unpaidResponseBody: (context) async {
// ///   final preview = await database.getPreview(context.path);
// ///   return UnpaidResponseResult(
// ///     contentType: 'application/json',
// ///     body: {'preview': preview, 'totalItems': 100},
// ///   );
// /// }
// /// ```
// typedef UnpaidResponseBody = FutureOr<UnpaidResponseResult> Function(
//   ShelfRequestContext context,
// );

/// Result returned by [UnpaidResponseBody] callbacks.
///
/// Specifies the content type and body for the 402 Payment Required response.
class UnpaidResponseResult {
  /// The MIME type for the response (e.g., 'application/json', 'text/plain')
  final String contentType;

  /// The response body (String, Map, List, or any JSON-serializable object)
  final Object body;

  const UnpaidResponseResult({
    required this.contentType,
    required this.body,
  });
}
