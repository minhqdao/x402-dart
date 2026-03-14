import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// The payload sent by the client in the `payment-signature` (or `x-payment`) header.
///
/// This object contains the proof of payment (signature or transaction) and
/// the context of the payment being made.
final class PaymentPayload {
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

  PaymentPayload({
    required this.x402Version,
    required this.resource,
    required this.accepted,
    required Map<String, dynamic> payload,
    Map<String, dynamic>? extensions,
  })  : payload = Map.unmodifiable(payload),
        extensions = extensions != null ? Map.unmodifiable(extensions) : null {
    if (x402Version <= 0) {
      throw ArgumentError.value(
        x402Version,
        'x402Version',
        'Must be a positive integer.',
      );
    }

    if (x402Version <= 0) {
      throw ArgumentError.value(
        x402Version,
        'x402Version',
        'Must be a positive integer.',
      );
    }
  }

  factory PaymentPayload.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'];

    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Invalid or missing "payload" field.');
    }

    final extensions = json['extensions'];

    if (extensions != null && extensions is! Map<String, dynamic>) {
      throw const FormatException('"extensions" must be a map if provided.');
    }

    return PaymentPayload(
      x402Version: json['x402Version'] as int,
      resource: ResourceInfo.fromJson(json['resource'] as Map<String, dynamic>),
      accepted:
          PaymentRequirement.fromJson(json['accepted'] as Map<String, dynamic>),
      payload: payload,
      extensions: extensions as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'x402Version': x402Version,
      'resource': resource.toJson(),
      'accepted': accepted.toJson(),
      'payload': payload,
      if (extensions != null) 'extensions': extensions,
    };

    return Map.unmodifiable(map);
  }
}
