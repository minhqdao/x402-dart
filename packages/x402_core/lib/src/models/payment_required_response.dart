import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// Response sent by server when payment is required (HTTP 402)
class PaymentRequiredResponse {
  /// x402 protocol version
  final int x402Version;

  /// Error message (if any)
  final String? error;

  /// Resource information
  final ResourceInfo resource;

  /// List of accepted payment requirements
  final List<PaymentRequirement> accepts;

  /// Optional extensions
  final Map<String, dynamic>? extensions;

  const PaymentRequiredResponse({
    required this.x402Version,
    this.error,
    required this.resource,
    required this.accepts,
    this.extensions,
  });

  factory PaymentRequiredResponse.fromJson(Map<String, dynamic> json) {
    return PaymentRequiredResponse(
      x402Version: json['x402Version'] as int,
      error: json['error'] as String?,
      resource: ResourceInfo.fromJson(json['resource'] as Map<String, dynamic>),
      accepts: (json['accepts'] as List).map((e) => PaymentRequirement.fromJson(e as Map<String, dynamic>)).toList(),
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x402Version': x402Version,
      if (error != null) 'error': error,
      'resource': resource.toJson(),
      'accepts': accepts.map((e) => e.toJson()).toList(),
      if (extensions != null) 'extensions': extensions,
    };
  }
}
