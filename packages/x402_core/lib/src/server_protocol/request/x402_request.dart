import 'package:x402_core/src/server_protocol/request/http_method.dart';

/// A framework-agnostic representation of an incoming HTTP request.
///
/// This interface is implemented by server adapters (e.g. Shelf)
/// and consumed by x402 payment verification logic.
///
/// It intentionally exposes only the minimal information required
/// for payment verification.
abstract class X402Request {
  /// The HTTP method of the request.
  HttpMethod get method;

  /// The full request URI.
  Uri get uri;

  /// The request headers.
  Map<String, String> get headers;
}
