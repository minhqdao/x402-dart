import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// Payment payload sent by client in X-PAYMENT header
class PaymentPayload {
  /// x402 protocol version
  final int x402Version;

  /// Resource information
  final ResourceInfo resource;

  /// The accepted payment requirement
  final PaymentRequirement accepted;

  /// Scheme-specific payload data
  final Map<String, dynamic> payload;

  /// Optional extensions
  final Map<String, dynamic>? extensions;

  const PaymentPayload({
    required this.x402Version,
    required this.resource,
    required this.accepted,
    required this.payload,
    this.extensions,
  });

  factory PaymentPayload.fromJson(Map<String, dynamic> json) {
    return PaymentPayload(
      x402Version: json['x402Version'] as int,
      resource: ResourceInfo.fromJson(json['resource'] as Map<String, dynamic>),
      accepted: PaymentRequirement.fromJson(json['accepted'] as Map<String, dynamic>),
      payload: json['payload'] as Map<String, dynamic>,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x402Version': x402Version,
      'resource': resource.toJson(),
      'accepted': accepted.toJson(),
      'payload': payload,
      if (extensions != null) 'extensions': extensions,
    };
  }
}
