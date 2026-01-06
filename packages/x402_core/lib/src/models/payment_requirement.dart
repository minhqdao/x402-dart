import 'dart:convert';

/// Represents a payment option offered by the server
class PaymentRequirement {
  /// Scheme of the payment protocol (e.g., "exact")
  final String scheme;

  /// Network identifier (e.g., "eip155:8453")
  final String network;

  /// Token/asset contract address
  final String asset;

  /// Amount required in atomic units
  final String amount;

  /// Address to send payment to
  final String payTo;

  /// Maximum timeout in seconds
  final int maxTimeoutSeconds;

  /// Scheme-specific data
  final Map<String, dynamic> extra;

  const PaymentRequirement({
    required this.scheme,
    required this.network,
    required this.asset,
    required this.amount,
    required this.payTo,
    required this.maxTimeoutSeconds,
    this.extra = const {},
  });

  factory PaymentRequirement.fromJson(Map<String, dynamic> json) {
    return PaymentRequirement(
      scheme: json['scheme'] as String,
      network: json['network'] as String,
      asset: json['asset'] as String,
      amount: (json['amount'] ?? json['maxAmountRequired']) as String,
      payTo: json['payTo'] as String,
      maxTimeoutSeconds: json['maxTimeoutSeconds'] as int,
      extra: (json['extra'] ?? json['data'] ?? <String, dynamic>{}) as Map<String, dynamic>,
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
