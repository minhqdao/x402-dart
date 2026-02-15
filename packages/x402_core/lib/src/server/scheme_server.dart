import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/price.dart';
import 'package:x402_core/src/models/supported_kind.dart';

/// Defines how a specific payment scheme behaves on a given network.
///
/// Implementations are responsible for:
/// - Converting user-friendly prices into scheme-specific asset/amount formats
/// - Enhancing payment requirements before they are sent to clients
///
/// Examples of implementations:
/// - ExactEvmScheme
/// - ExactSvmScheme
abstract class SchemeServer {
  /// The scheme identifier (e.g. "exact").
  String get scheme;

  /// Converts a user-friendly [price] into a scheme-specific [AssetAmount].
  ///
  /// This method normalizes input such as:
  /// - "$0.10"
  /// - "0.10"
  /// - An already structured asset amount
  ///
  /// The returned [AssetAmount] must contain:
  /// - The canonical asset identifier
  /// - The normalized on-chain amount
  ///
  /// The [network] provides context (e.g. chain ID, cluster).
  Future<AssetAmount> parsePrice(
    Price price,
    String network,
  );

  /// Enhances base [paymentRequirement] using scheme/network logic.
  ///
  /// This method allows the scheme to:
  /// - Add required metadata
  /// - Adjust fields depending on x402 version
  /// - Apply facilitator-specific extensions
  ///
  /// The returned object is sent to the client.
  Future<PaymentRequirement> enhancePaymentRequirement(
    PaymentRequirement paymentRequirement, {
    required SupportedKind kind,
    List<String> facilitatorExtensions = const [],
  });
}
