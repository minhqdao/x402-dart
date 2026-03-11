import 'package:x402_core/src/models/network.dart';

/// Response returned by a facilitator when settling a payment.
class SettleResponse {
  /// Whether settlement succeeded.
  final bool success;

  /// Error reason if settlement failed.
  final String? errorReason;

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
    this.payer,
    required this.transaction,
    required this.network,
    this.extensions,
  });

  factory SettleResponse.fromJson(Map<String, dynamic> json) {
    return SettleResponse(
      success: json['success'] as bool,
      errorReason: json['errorReason'] as String?,
      payer: json['payer'] as String?,
      transaction: json['transaction'] as String,
      network: Network.parse(json['network'] as String),
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        if (errorReason != null) 'errorReason': errorReason,
        if (payer != null) 'payer': payer,
        'transaction': transaction,
        'network': network.identifier,
        if (extensions != null) 'extensions': extensions,
      };
}
