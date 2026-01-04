/// Response from facilitator's /verify endpoint
class VerificationResponse {
  /// Whether the payment is valid
  final bool isValid;

  /// Reason for invalidity (if any)
  final String? invalidReason;

  const VerificationResponse({required this.isValid, this.invalidReason});

  factory VerificationResponse.fromJson(Map<String, dynamic> json) {
    return VerificationResponse(isValid: json['isValid'] as bool, invalidReason: json['invalidReason'] as String?);
  }

  Map<String, dynamic> toJson() {
    return {'isValid': isValid, if (invalidReason != null) 'invalidReason': invalidReason};
  }
}
