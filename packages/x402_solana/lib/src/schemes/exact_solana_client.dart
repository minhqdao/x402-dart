import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_solana/src/utils/transaction_builder.dart';

/// Client-side implementation of the exact scheme for Solana
class ExactSolanaSchemeClient implements SchemeClient {
  final Ed25519HDKeyPair signer;
  final SolanaClient solanaClient;

  ExactSolanaSchemeClient({required this.signer, required this.solanaClient});

  @override
  String get scheme => 'exact';

  @override
  Future<PaymentPayload> createPaymentPayload(PaymentRequirements requirements) async {
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
    final amount = BigInt.parse(requirements.maxAmountRequired);

    // Build transfer transaction
    final encodedTransaction = await SolanaTransactionBuilder.createTransferTransaction(
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
      scheme: scheme,
      network: requirements.network,
      payload: {'transaction': encodedTransaction, 'blockhash': blockhash},
    );
  }
}
