import 'dart:convert';

import 'package:x402_core/src/client/x402_client.dart';
import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';
import 'package:x402_core/src/x402_exception.dart';

/// The structured response body returned by a server when it requires payment (HTTP 402).
///
/// This response contains the list of acceptable payment methods and the
/// metadata of the resource being requested.
final class PaymentRequiredResponse {
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

  PaymentRequiredResponse({
    required this.x402Version,
    this.error,
    required this.resource,
    required List<PaymentRequirement> accepts,
    Map<String, dynamic>? extensions,
  })  : accepts = List.unmodifiable(accepts),
        extensions = extensions == null ? null : Map.unmodifiable(extensions) {
    if (accepts.isEmpty) {
      throw const InvalidPayloadException(
        'PaymentRequiredResponse requires at least one payment requirement',
      );
    }
  }

  /// Parses the PaymentRequiredResponse from a base64-encoded header string.
  ///
  /// Throws an [InvalidPayloadException] if the header is not a valid base64 or
  /// cannot be decoded into a valid [PaymentRequiredResponse].
  factory PaymentRequiredResponse.fromHeader(String header) {
    try {
      return PaymentRequiredResponse.fromJson(
        jsonDecode(utf8.decode(base64Decode(header))) as Map<String, dynamic>,
      );
    } catch (e) {
      throw InvalidPayloadException(
        'Invalid payment-required header payload',
        originalError: e,
      );
    }
  }

  /// Creates a response from a decoded JSON map.
  ///
  /// Most users should prefer [PaymentRequiredResponse.fromHeader].
  factory PaymentRequiredResponse.fromJson(Map<String, dynamic> json) {
    final version = json['x402Version'] as int;

    if (version != kX402Version) {
      throw InvalidPayloadException('Unsupported x402 version: $version');
    }

    final accepts = json['accepts'] as List;

    if (accepts.isEmpty) {
      throw const InvalidPayloadException(
          '402 response contains no payment requirements');
    }

    return PaymentRequiredResponse(
      x402Version: version,
      error: json['error'] as String?,
      resource: ResourceInfo.fromJson(json['resource'] as Map<String, dynamic>),
      accepts: List.unmodifiable(accepts
          .map((e) => PaymentRequirement.fromJson(e as Map<String, dynamic>))),
      extensions: json['extensions'] == null
          ? null
          : Map<String, dynamic>.unmodifiable(
              json['extensions'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x402Version': x402Version,
      if (error != null) 'error': error,
      'resource': resource.toJson(),
      'accepts': List.unmodifiable(accepts.map((e) => e.toJson())),
      if (extensions != null) 'extensions': Map.unmodifiable(extensions!),
    };
  }

  /// Finds the first [PaymentRequirement] that the given [signer] supports.
  /// Returns `null` if none are supported.
  PaymentRequirement? findFirstSupportedBy(X402Signer signer) {
    for (final requirement in accepts) {
      if (signer.supports(requirement)) return requirement;
    }
    return null;
  }
}
