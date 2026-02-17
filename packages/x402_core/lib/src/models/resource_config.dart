import 'package:x402_core/src/models/network.dart';
import 'package:x402_core/src/models/price.dart';

/// Configuration for a protected resource.
///
/// Contains only payment-specific configuration.
/// Does not include resource metadata such as URL or MIME type.
class ResourceConfig {
  /// Payment scheme identifier (e.g. "exact-evm").
  final String scheme;

  /// Recipient address.
  final String payTo;

  /// Price definition understood by the scheme.
  final Price price;

  /// Network identifier (e.g. "eip155:84532").
  final Network network;

  /// Maximum allowed payment timeout in seconds.
  ///
  /// Defaults to 300 seconds.
  final int maxTimeoutSeconds;

  const ResourceConfig({
    required this.scheme,
    required this.payTo,
    required this.price,
    required this.network,
    this.maxTimeoutSeconds = 300,
  });
}
