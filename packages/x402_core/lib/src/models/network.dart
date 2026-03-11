/// Represents a CAIP-2 blockchain network identifier.
///
/// A CAIP-2 network is composed of:
/// - a namespace (e.g. `eip155`, `solana`)
/// - a reference (e.g. chain ID or genesis hash)
///
/// The canonical string form is `<namespace>:<reference>`.
///
/// Examples:
/// - `eip155:1` (Ethereum mainnet)
/// - `eip155:8453` (Base mainnet)
/// - `solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d`
///
/// Instances are immutable and compare by value.
class Network {
  /// The CAIP-2 namespace (e.g. `eip155`, `solana`).
  final String namespace;

  /// The CAIP-2 reference (e.g. chain ID or genesis hash).
  final String reference;

  /// Creates a CAIP-2 network identifier.
  ///
  /// Prefer using chain-specific helpers.
  ///
  /// The caller is responsible for ensuring the namespace and reference
  /// conform to the CAIP-2 specification.
  const Network({
    required this.namespace,
    required this.reference,
  });

  /// Parses a CAIP-2 formatted string (`<namespace>:<reference>`).
  ///
  /// Throws a [FormatException] if the value is not valid CAIP-2 format.
  factory Network.parse(String value) {
    final separatorIndex = value.indexOf(':');
    if (separatorIndex <= 0 || separatorIndex == value.length - 1) {
      throw FormatException('Invalid CAIP-2 network: $value');
    }

    return Network(
      namespace: value.substring(0, separatorIndex),
      reference: value.substring(separatorIndex + 1),
    );
  }

  /// Returns the CAIP-2 identifier string (`<namespace>:<reference>`).
  String get identifier => '$namespace:$reference';

  /// Returns the canonical CAIP-2 string representation.
  @override
  String toString() => identifier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Network &&
          namespace == other.namespace &&
          reference == other.reference;

  @override
  int get hashCode => Object.hash(namespace, reference);
}
