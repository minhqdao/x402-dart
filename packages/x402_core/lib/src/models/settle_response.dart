import 'dart:convert';

import 'package:x402_core/src/models/network.dart';
import 'package:x402_core/src/x402_exception.dart';

/// Response returned by a facilitator when settling a payment.
class SettleResponse {
  /// Whether settlement succeeded.
  final bool success;

  /// Error reason if settlement failed.
  final String? errorReason;

  /// Error message if settlement failed.
  final String? errorMessage;

  /// Address or identifier of the payer.
  final String? payer;

  /// Transaction identifier.
  final String transaction;

  /// Network on which settlement occurred.
  final Network network;

  /// Optional facilitator-specific extensions.
  final Map<String, dynamic>? extensions;

  const SettleResponse({
    required this.success,
    this.errorReason,
    this.errorMessage,
    this.payer,
    required this.transaction,
    required this.network,
    this.extensions,
  });

  /// Parses the SettleResponse from a base64-encoded header string.
  ///
  /// Throws an [InvalidPayloadException] if the header is not a valid base64 or
  /// cannot be decoded into a valid [SettleResponse].
  factory SettleResponse.fromHeader(String header) {
    try {
      return SettleResponse.fromJson(
        jsonDecode(utf8.decode(base64Decode(header))) as Map<String, dynamic>,
      );
    } catch (e) {
      throw InvalidPayloadException(
        'Invalid settle response (payment-response header)',
        originalError: e,
      );
    }
  }

  factory SettleResponse.fromJson(Map<String, dynamic> json) {
    return SettleResponse(
      success: json['success'] as bool,
      errorReason: json['errorReason'] as String?,
      errorMessage: json['errorMessage'] as String?,
      payer: json['payer'] as String?,
      transaction: json['transaction'] as String,
      network: Network.parse(json['network'] as String),
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (errorReason != null) 'errorReason': errorReason,
        if (errorMessage != null) 'errorMessage': errorMessage,
        if (payer != null) 'payer': payer,
        'transaction': transaction,
        'network': network.identifier,
        if (extensions != null) 'extensions': extensions,
      };

  /// Encodes this response as a base64-encoded JSON string.
  String get encoded => base64Encode(utf8.encode(jsonEncode(toJson())));
}
