import 'dart:convert';

/// Represents a payment option offered by the server
class PaymentRequirement {
  /// Scheme of the payment protocol (e.g., "exact")
  final String scheme;

  /// Network identifier (e.g., "eip155:8453")
  final String network;

  /// Amount required in atomic units
  final String amount;

  /// URL of the resource to pay for
  final String resource;

  /// Description of the resource
  final String description;

  /// MIME type of the resource response
  final String mimeType;

  /// Output schema of the resource response (optional)
  final Map<String, dynamic>? outputSchema;

  /// Address to send payment to
  final String payTo;

  /// Maximum timeout in seconds
  final int maxTimeoutSeconds;

  /// Token/asset contract address
  final String asset;

  /// Scheme-specific data
  final Map<String, dynamic> data;

  const PaymentRequirement({
    required this.scheme,
    required this.network,
    required this.amount,
    required this.resource,
    required this.description,
    required this.mimeType,
    this.outputSchema,
    required this.payTo,
    required this.maxTimeoutSeconds,
    required this.asset,
    this.data = const {},
  });

  factory PaymentRequirement.fromJson(Map<String, dynamic> json) {
    return PaymentRequirement(
      scheme: json['scheme'] as String,
      network: json['network'] as String,
      amount: (json['amount'] ?? json['maxAmountRequired']) as String,
      resource: json['resource'] as String,
      description: json['description'] as String,
      mimeType: json['mimeType'] as String,
      outputSchema: json['outputSchema'] as Map<String, dynamic>?,
      payTo: json['payTo'] as String,
      maxTimeoutSeconds: json['maxTimeoutSeconds'] as int,
      asset: json['asset'] as String,
      data: (json['data'] ?? json['extra'] ?? <String, dynamic>{}) as Map<String, dynamic>,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scheme': scheme,
      'network': network,
      'amount': amount,
      'maxAmountRequired': amount, // Backward compatibility
      'resource': resource,
      'description': description,
      'mimeType': mimeType,
      if (outputSchema != null) 'outputSchema': outputSchema,
      'payTo': payTo,
      'maxTimeoutSeconds': maxTimeoutSeconds,
      'asset': asset,
      'data': data,
      'extra': data, // Backward compatibility
    };
  }

  /// Factory to decode the Base64 JSON from the payment-required header
  factory PaymentRequirement.fromHeader(String base64Json) {
    final decoded = jsonDecode(utf8.decode(base64Decode(base64Json)));
    return PaymentRequirement.fromJson(decoded as Map<String, dynamic>);
  }
}
