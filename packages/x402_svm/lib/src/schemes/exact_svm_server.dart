import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/models/exact_payload.dart';
import 'package:x402_svm/src/utils/transaction_builder.dart';

/// Server-side implementation of the exact scheme for SVM
class ExactSvmSchemeServer implements SchemeServer {
  final SolanaClient? solanaClient;

  ExactSvmSchemeServer({this.solanaClient});

  @override
  String get scheme => 'exact';

  @override
  Future<bool> verifyPayload(PaymentPayload payload, X402Requirement requirements) async {
    try {
      // Validate scheme
      if (payload.scheme != scheme || requirements.scheme != scheme) {
        return false;
      }

      // Validate network
      if (payload.network != requirements.network) {
        return false;
      }

      // Parse payload
      final exactPayload = ExactSvmPayloadData.fromPaymentPayload(payload);
      final encodedTx = exactPayload.transactionData.transaction;

      // Decode transaction
      final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);

      // Verify transaction structure
      final expectedAmount = BigInt.parse(requirements.amount);
      final isValidStructure = await SvmTransactionBuilder.verifyTransactionStructure(
        decoded: decoded,
        expectedRecipient: requirements.payTo,
        expectedAmount: expectedAmount,
        tokenMint: requirements.asset,
      );

      if (!isValidStructure) {
        return false;
      }

      // Verify signatures
      if (decoded.signatures.isEmpty) {
        return false;
      }

      // Additional verification can be done here:
      // - Check blockhash is recent
      // - Verify signature validity
      // - Check instruction layout matches expected pattern

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Submit transaction to SVM network
  Future<String> submitTransaction(PaymentPayload payload) async {
    if (solanaClient == null) {
      throw const X402Exception('SolanaClient required for transaction submission', code: 'NO_CLIENT');
    }

    final exactPayload = ExactSvmPayloadData.fromPaymentPayload(payload);
    final encodedTx = exactPayload.transactionData.transaction;

    final signature = await solanaClient!.rpcClient.sendTransaction(encodedTx);

    return signature;
  }

  /// Wait for transaction confirmation
  Future<bool> confirmTransaction(String signature) async {
    if (solanaClient == null) {
      throw const X402Exception('SolanaClient required for transaction confirmation', code: 'NO_CLIENT');
    }

    try {
      final status = await solanaClient!.rpcClient.getSignatureStatuses([signature]);

      if (status.value.isEmpty) {
        return false;
      }

      final confirmationStatus = status.value.first?.confirmationStatus;
      return confirmationStatus == Commitment.finalized || confirmationStatus == Commitment.confirmed;
    } catch (e) {
      return false;
    }
  }
}
