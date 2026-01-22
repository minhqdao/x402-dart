/// SVM transaction data for exact scheme
class ExactSvmPayload {
  /// Base64-encoded serialized transaction
  final String transaction;

  /// Optional: Recent blockhash used
  final String? blockhash;

  const ExactSvmPayload({required this.transaction, this.blockhash});

  factory ExactSvmPayload.fromJson(Map<String, dynamic> json) {
    return ExactSvmPayload(
        transaction: json['transaction'] as String,
        blockhash: json['blockhash'] as String?);
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction': transaction,
      if (blockhash != null) 'blockhash': blockhash
    };
  }
}
