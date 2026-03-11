import 'package:x402_core/src/models/network.dart';

/// Signature for custom money parsers.
///
/// A parser receives:
/// - [amount]: canonical decimal string (e.g. `'1.50'`)
/// - [network]: CAIP-2 network identifier
///
/// It should return:
/// - An [AssetAmount] if it can resolve the value for the given network
/// - `null` to allow the next parser to attempt resolution
///
/// The [amount] is guaranteed to be a string representation and will
/// never be provided as a floating-point value.
typedef MoneyParser = Future<AssetAmount?> Function(
  String amount,
  Network network,
);

/// Base type for all resource prices.
///
/// A price is either:
/// - An abstract monetary value ([Money]), or
/// - A fully resolved on-chain amount ([AssetAmount]).
sealed class Price {
  const Price();
}

/// A user-defined monetary price.
///
/// Represents an abstract decimal amount that must be resolved
/// by a scheme into a concrete on-chain [AssetAmount].
///
/// The [amount] must:
/// - Be a canonical decimal string
/// - Not use scientific notation
/// - Not contain currency symbols
///
/// Example:
/// ```dart
/// const Money('0.10');
/// const Money('10');
/// ```
final class Money extends Price {
  /// Canonical decimal representation of the amount.
  final String amount;

  const Money(this.amount);
}

/// A concrete asset-based price.
///
/// Represents a fully resolved on-chain payment requirement.
/// The [asset] identifies the token or contract, and [amount]
/// is expressed in the asset’s expected format (typically
/// smallest denomination units).
final class AssetAmount extends Price {
  /// Identifier of the asset (e.g. contract address, mint, symbol).
  final String asset;

  /// Canonical amount representation.
  final String amount;

  /// Optional scheme-specific metadata.
  final Map<String, dynamic>? extra;

  const AssetAmount({
    required this.asset,
    required this.amount,
    this.extra,
  });
}
