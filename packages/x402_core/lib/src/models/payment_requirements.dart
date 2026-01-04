/// Represents payment requirements for accessing a resource
class PaymentRequirements {
  /// Scheme of the payment protocol (e.g., "exact")
  final String scheme;

  /// Network identifier (e.g., "eip155:8453" for Base)
  final String network;

  /// Maximum amount required in atomic units
  final String maxAmountRequired;

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

  /// Scheme-specific extra data
  final Map<String, dynamic>? extra;

  const PaymentRequirements({
    required this.scheme,
    required this.network,
    required this.maxAmountRequired,
    required this.resource,
    required this.description,
    required this.mimeType,
    this.outputSchema,
    required this.payTo,
    required this.maxTimeoutSeconds,
    required this.asset,
    this.extra,
  });

  factory PaymentRequirements.fromJson(Map<String, dynamic> json) {
    return PaymentRequirements(
      scheme: json['scheme'] as String,
      network: json['network'] as String,
      maxAmountRequired: json['maxAmountRequired'] as String,
      resource: json['resource'] as String,
      description: json['description'] as String,
      mimeType: json['mimeType'] as String,
      outputSchema: json['outputSchema'] as Map<String, dynamic>?,
      payTo: json['payTo'] as String,
      maxTimeoutSeconds: json['maxTimeoutSeconds'] as int,
      asset: json['asset'] as String,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scheme': scheme,
      'network': network,
      'maxAmountRequired': maxAmountRequired,
      'resource': resource,
      'description': description,
      'mimeType': mimeType,
      if (outputSchema != null) 'outputSchema': outputSchema,
      'payTo': payTo,
      'maxTimeoutSeconds': maxTimeoutSeconds,
      'asset': asset,
      if (extra != null) 'extra': extra,
    };
  }
}
