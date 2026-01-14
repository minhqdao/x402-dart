import 'dart:convert';

/// Represents a specific payment option offered by a server in a 402 response.
///
/// A single 402 response may contain multiple [PaymentRequirement]s, allowing
/// the client to choose the most suitable network, asset, and scheme.
class PaymentRequirement {
  /// The protocol scheme to use for this payment (e.g., "exact", "v2:solana:exact").
  final String scheme;

  /// The CAIP-2 network identifier (e.g., "eip155:8453", "solana:5eykt4...").
  final String network;

  /// The contract address or identifier of the asset (e.g., USDC token address).
  final String asset;

  /// The exact amount required in the asset's smallest atomic unit (e.g., units of 10^-6 for USDC).
  final String amount;

  /// The destination address where the payment should be sent.
  final String payTo;

  /// The number of seconds this requirement remains valid after it is issued.
  final int maxTimeoutSeconds;

  /// Arbitrary extra data required by the specific [scheme] or [network].
  final Map<String, dynamic> extra;

  const PaymentRequirement({
    required this.scheme,
    required this.network,
    required this.asset,
    required this.amount,
    required this.payTo,
    required this.maxTimeoutSeconds,
    required this.extra,
  });

  factory PaymentRequirement.fromJson(Map<String, dynamic> json) {
    return PaymentRequirement(
      scheme: json['scheme'] as String,
      network: json['network'] as String,
      asset: json['asset'] as String,
      amount: (json['amount'] ?? json['maxAmountRequired']).toString(),
      payTo: json['payTo'] as String,
      maxTimeoutSeconds: json['maxTimeoutSeconds'] as int,
      extra: (json['extra'] ?? json['data']) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scheme': scheme,
      'network': network,
      'asset': asset,
      'amount': amount,
      'payTo': payTo,
      'maxTimeoutSeconds': maxTimeoutSeconds,
      'extra': extra,
    };
  }

  /// Factory to decode the Base64 JSON from the payment-required header
  factory PaymentRequirement.fromHeader(String base64Json) {
    final decoded = jsonDecode(utf8.decode(base64Decode(base64Json)));
    return PaymentRequirement.fromJson(decoded as Map<String, dynamic>);
  }
}
