import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/utils/transaction_builder.dart';

/// Client-side implementation of the exact scheme for SVM
class ExactSvmSchemeClient implements SchemeClient {
  final Ed25519HDKeyPair signer;
  final SolanaClient solanaClient;

  const ExactSvmSchemeClient({required this.signer, required this.solanaClient});

  @override
  String get scheme => 'v2:solana:exact';

  @override
  Future<PaymentPayload> createPaymentPayload(
    PaymentRequirement requirements,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  }) async {
    // Validate scheme
    if (requirements.scheme != scheme) {
      throw UnsupportedSchemeException('Expected scheme "$scheme", got "${requirements.scheme}"');
    }

    // Parse network (format: solana:genesisHash)
    final networkParts = requirements.network.split(':');
    if (networkParts.length != 2 || networkParts[0] != 'solana') {
      throw InvalidPayloadException(
        'Invalid network format. Expected "solana:genesisHash", got "${requirements.network}"',
      );
    }

    // Parse amount
    final amount = BigInt.parse(requirements.amount);

    // Build transfer transaction
    final encodedTransaction = await SvmTransactionBuilder.createTransferTransaction(
      signer: signer,
      recipient: requirements.payTo,
      amount: amount,
      tokenMint: requirements.asset,
      solanaClient: solanaClient,
    );

    // Get recent blockhash for reference
    final blockhashResult = await solanaClient.rpcClient.getLatestBlockhash();
    final blockhash = blockhashResult.value.blockhash;

    // Create payment payload
    return PaymentPayload(
      x402Version: kX402Version,
      resource: resource,
      accepted: requirements,
      payload: {'transaction': encodedTransaction, 'blockhash': blockhash},
      extensions: extensions,
    );
  }
}
