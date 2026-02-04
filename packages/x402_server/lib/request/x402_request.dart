/// A framework-agnostic representation of an incoming HTTP request
/// used for payment verification.
abstract class X402Request {
  /// HTTP method (e.g. GET, POST).
  String get method;

  /// Full request URI.
  Uri get uri;

  /// Request headers.
  Map<String, String> get headers;
}
