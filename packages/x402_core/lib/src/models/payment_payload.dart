/// Payment payload sent by client in X-PAYMENT header
class PaymentPayload {
  /// x402 protocol version
  final int x402Version;

  /// Payment scheme being used
  final String scheme;

  /// Network identifier
  final String network;

  /// Scheme-specific payload data
  final Map<String, dynamic> payload;

  const PaymentPayload({required this.x402Version, required this.scheme, required this.network, required this.payload});

  factory PaymentPayload.fromJson(Map<String, dynamic> json) {
    return PaymentPayload(
      x402Version: json['x402Version'] as int,
      scheme: json['scheme'] as String,
      network: json['network'] as String,
      payload: json['payload'] as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {'x402Version': x402Version, 'scheme': scheme, 'network': network, 'payload': payload};
  }
}
