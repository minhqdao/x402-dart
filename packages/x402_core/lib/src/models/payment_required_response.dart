import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// The structured response body returned by a server when it requires payment (HTTP 402).
///
/// This response contains the list of acceptable payment methods and the
/// metadata of the resource being requested.
class PaymentRequiredResponse {
  /// The version of the x402 protocol the server is using.
  final int x402Version;

  /// A human-readable error message explaining why payment is required.
  final String? error;

  /// Metadata about the resource being protected by the 402 status.
  final ResourceInfo resource;

  /// A list of compatible payment options the server will accept.
  final List<PaymentRequirement> accepts;

  /// Arbitrary extra data included by the server.
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
      accepts: (json['accepts'] as List)
          .map((e) => PaymentRequirement.fromJson(e as Map<String, dynamic>))
          .toList(),
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
