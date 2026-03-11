import 'package:x402_core/src/server/models/http_method.dart';

/// Represents a type-safe route pattern with HTTP method and path.
///
/// Immutable value object used as a key for payment route configuration.
/// Paths are automatically normalized with a leading slash.
///
/// Example:
/// ```dart
/// RoutePattern(HttpMethod.get, '/protected'): RouteConfig(...)
/// ```
class RoutePattern {
  /// The HTTP method for this route
  final HttpMethod method;

  /// The path pattern (e.g., '/protected', '/api/data')
  final String path;

  /// Creates a route pattern with the given method and path.
  const RoutePattern(this.method, this.path);

  /// The normalized path with a guaranteed leading slash.
  String get normalizedPath => path.startsWith('/') ? path : '/$path';

  /// Returns the route key in the format "METHOD /path".
  String get key => '${method.value} $normalizedPath';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePattern &&
          runtimeType == other.runtimeType &&
          method == other.method &&
          normalizedPath == other.normalizedPath;

  @override
  int get hashCode => method.hashCode ^ normalizedPath.hashCode;

  @override
  String toString() => key;
}
