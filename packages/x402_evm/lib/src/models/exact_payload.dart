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
