import 'package:x402_core/src/models/payment_requirements.dart';

/// Response sent by server when payment is required (HTTP 402)
class PaymentRequiredResponse {
  /// x402 protocol version
  final int x402Version;

  /// List of accepted payment requirements
  final List<X402Requirement> accepts;

  /// Error message (if any)
  final String? error;

  const PaymentRequiredResponse({required this.x402Version, required this.accepts, this.error});

  factory PaymentRequiredResponse.fromJson(Map<String, dynamic> json) {
    return PaymentRequiredResponse(
      x402Version: json['x402Version'] as int,
      accepts: (json['accepts'] as List).map((e) => X402Requirement.fromJson(e as Map<String, dynamic>)).toList(),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x402Version': x402Version,
      'accepts': accepts.map((e) => e.toJson()).toList(),
      if (error != null) 'error': error,
    };
  }
}
