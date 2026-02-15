import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// The payload sent by the client in the `payment-signature` (or `X-PAYMENT`) header.
///
/// This object contains the proof of payment (signature or transaction) and
/// the context of the payment being made.
class PaymentPayload {
  /// The version of the x402 protocol being used.
  final int x402Version;

  /// Metadata about the resource being accessed.
  final ResourceInfo resource;

  /// The specific requirement from the server that this payload satisfies.
  final PaymentRequirement accepted;

  /// The actual proof of payment (e.g., a signature or a transaction hash).
  final Map<String, dynamic> payload;

  /// Arbitrary extra data included in the payload.
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
      accepted:
          PaymentRequirement.fromJson(json['accepted'] as Map<String, dynamic>),
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
