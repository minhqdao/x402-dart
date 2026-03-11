/// Represents an HTTP request method.
///
/// This enum is used by x402 server-side components to describe
/// the HTTP method of a request in a structured, type-safe way,
/// instead of relying on raw strings.
///
/// It is typically exposed via [X402Request.method] and implemented
/// by framework adapters (e.g. Shelf).
enum HttpMethod {
  /// HTTP GET
  get('GET'),

  /// HTTP POST
  post('POST'),

  /// HTTP PUT
  put('PUT'),

  /// HTTP DELETE
  delete('DELETE'),

  /// HTTP PATCH
  patch('PATCH'),

  /// HTTP HEAD
  head('HEAD'),

  /// HTTP OPTIONS
  options('OPTIONS');

  /// Creates an [HttpMethod] with its canonical HTTP string value.
  const HttpMethod(this.value);

  /// The uppercase string representation of the HTTP method
  /// as used in HTTP requests (e.g. `GET`, `POST`).
  final String value;
}
