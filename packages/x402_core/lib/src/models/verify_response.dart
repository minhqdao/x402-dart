/// Response returned by a facilitator when verifying a payment.
class VerifyResponse {
  /// Whether the payment is valid.
  final bool isValid;

  /// Reason for invalidation, if any.
  final String? invalidReason;

  /// Address or identifier of the payer, if known.
  final String? payer;

  /// Optional facilitator-specific extensions.
  final Map<String, dynamic>? extensions;

  const VerifyResponse({
    required this.isValid,
    this.invalidReason,
    this.payer,
    this.extensions,
  });

  factory VerifyResponse.fromJson(Map<String, dynamic> json) {
    return VerifyResponse(
      isValid: json['isValid'] as bool,
      invalidReason: json['invalidReason'] as String?,
      payer: json['payer'] as String?,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'isValid': isValid,
        if (invalidReason != null) 'invalidReason': invalidReason,
        if (payer != null) 'payer': payer,
        if (extensions != null) 'extensions': extensions,
      };
}
