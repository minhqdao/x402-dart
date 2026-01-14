import 'package:x402_core/x402_core.dart';

/// SVM transaction data for exact scheme
class SvmTransactionData {
  /// Base64-encoded serialized transaction
  final String transaction;

  /// Optional: Recent blockhash used
  final String? blockhash;

  const SvmTransactionData({required this.transaction, this.blockhash});

  factory SvmTransactionData.fromJson(Map<String, dynamic> json) {
    return SvmTransactionData(
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

/// Parsed exact scheme payload for SVM
class ExactSvmPayloadData {
  final SvmTransactionData transactionData;

  const ExactSvmPayloadData({required this.transactionData});

  factory ExactSvmPayloadData.fromPaymentPayload(PaymentPayload payload) {
    return ExactSvmPayloadData(
        transactionData: SvmTransactionData.fromJson(payload.payload));
  }

  Map<String, dynamic> toJson() {
    return transactionData.toJson();
  }
}
