/// Configuration for a single payment option.
///
/// Defines how a client can pay for access to a protected resource.
///
/// Example:
/// ```dart
/// PaymentOption(
///   scheme: 'exact',
///   price: '\$0.10',
///   network: 'eip155:84532',
///   payTo: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
/// )
/// ```
class PaymentOption {
  /// The payment scheme identifier (e.g., 'exact', 'subscription')
  final String scheme;

  /// The payment recipient address or identifier
  final String payTo;

  /// The price for this payment option (e.g., '\$0.10', '0.001 ETH')
  final String price;

  /// The blockchain network (CAIP-2 format, e.g., 'eip155:1')
  final String network;

  /// Optional maximum timeout in seconds for payment verification
  final int? maxTimeoutSeconds;

  /// Optional additional data specific to the payment scheme
  final Map<String, dynamic>? extra;

  const PaymentOption({
    required this.scheme,
    required this.payTo,
    required this.price,
    required this.network,
    this.maxTimeoutSeconds,
    this.extra,
  });
}
