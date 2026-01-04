import 'package:x402_core/x402_core.dart';

/// EIP-3009 authorization data for exact scheme
class ExactAuthorization {
  final String from;
  final String to;
  final String value;
  final String validAfter;
  final String validBefore;
  final String nonce;

  const ExactAuthorization({
    required this.from,
    required this.to,
    required this.value,
    required this.validAfter,
    required this.validBefore,
    required this.nonce,
  });

  factory ExactAuthorization.fromJson(Map<String, dynamic> json) {
    return ExactAuthorization(
      from: json['from'] as String,
      to: json['to'] as String,
      value: json['value'] as String,
      validAfter: json['validAfter'] as String,
      validBefore: json['validBefore'] as String,
      nonce: json['nonce'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from': from,
      'to': to,
      'value': value,
      'validAfter': validAfter,
      'validBefore': validBefore,
      'nonce': nonce,
    };
  }
}

/// Parsed exact scheme payload
class ExactPayloadData {
  final String signature;
  final ExactAuthorization authorization;

  const ExactPayloadData({required this.signature, required this.authorization});

  factory ExactPayloadData.fromPaymentPayload(PaymentPayload payload) {
    final payloadData = payload.payload;
    return ExactPayloadData(
      signature: payloadData['signature'] as String,
      authorization: ExactAuthorization.fromJson(payloadData['authorization'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {'signature': signature, 'authorization': authorization.toJson()};
  }
}
