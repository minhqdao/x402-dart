import 'package:x402_core/src/models/network.dart';
import 'package:x402_core/src/models/price.dart';

/// Configuration for a single payment option.
///
/// Represents one possible way a client can pay
/// for access to a protected route.
///
/// The [price] is expressed as a [Price]:
/// - Use [Money] for abstract monetary values
/// - Use [AssetAmount] for fully resolved on-chain prices
///
/// Example:
/// ```dart
/// PaymentOption(
///   scheme: 'exact',
///   price: Money('0.10'),
///   network: EvmNetwork(chainId: 84532),
///   payTo: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
/// )
/// ```
class PaymentOption {
  /// The payment scheme identifier (e.g., 'exact', 'subscription')
  final String scheme;

  /// The payment recipient address or identifier
  final String payTo;

  /// The price for this payment option
  final Price price;

  /// The blockchain network (CAIP-2 format)
  final Network network;

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
