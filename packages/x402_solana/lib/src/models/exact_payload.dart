import 'package:x402_core/x402_core.dart';

/// Solana transaction data for exact scheme
class SolanaTransactionData {
  /// Base64-encoded serialized transaction
  final String transaction;

  /// Optional: Recent blockhash used
  final String? blockhash;

  const SolanaTransactionData({required this.transaction, this.blockhash});

  factory SolanaTransactionData.fromJson(Map<String, dynamic> json) {
    return SolanaTransactionData(transaction: json['transaction'] as String, blockhash: json['blockhash'] as String?);
  }

  Map<String, dynamic> toJson() {
    return {'transaction': transaction, if (blockhash != null) 'blockhash': blockhash};
  }
}

/// Parsed exact scheme payload for Solana
class ExactSolanaPayloadData {
  final SolanaTransactionData transactionData;

  const ExactSolanaPayloadData({required this.transactionData});

  factory ExactSolanaPayloadData.fromPaymentPayload(PaymentPayload payload) {
    return ExactSolanaPayloadData(transactionData: SolanaTransactionData.fromJson(payload.payload));
  }

  Map<String, dynamic> toJson() {
    return transactionData.toJson();
  }
}
