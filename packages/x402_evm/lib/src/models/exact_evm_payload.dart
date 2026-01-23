/// EIP-3009 payload data for exact scheme
class ExactEvmPayload {
  final String from;
  final String to;
  final String value;
  final String validAfter;
  final String validBefore;
  final String nonce;

  const ExactEvmPayload({
    required this.from,
    required this.to,
    required this.value,
    required this.validAfter,
    required this.validBefore,
    required this.nonce,
  });

  factory ExactEvmPayload.fromJson(Map<String, dynamic> json) {
    return ExactEvmPayload(
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
