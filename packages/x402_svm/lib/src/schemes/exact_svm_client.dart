import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/utils/transaction_builder.dart';

/// Client-side implementation of the exact scheme for SVM
class ExactSvmSchemeClient implements SchemeClient {
  final Ed25519HDKeyPair _signer;
  final SolanaClient _solanaClient;

  const ExactSvmSchemeClient(
      {required Ed25519HDKeyPair signer, required SolanaClient solanaClient})
      : _signer = signer,
        _solanaClient = solanaClient;

  @override
  String get scheme => 'v2:solana:exact';

  @override
  Future<PaymentPayload> createPaymentPayload(
    PaymentRequirement requirements,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  }) async {
    // Validate scheme
    if (requirements.scheme != scheme && requirements.scheme != 'exact') {
      throw UnsupportedSchemeException(
          'Expected scheme "$scheme" or "exact", got "${requirements.scheme}"');
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

    // Extract feePayer from requirements.extra
    final feePayer = requirements.extra['feePayer'] as String?;
    if (feePayer == null) {
      throw const InvalidPayloadException(
          'feePayer is required in paymentRequirements.extra for SVM transactions');
    }

    // Build transfer transaction
    final encodedTransaction =
        await SvmTransactionBuilder.createTransferTransaction(
      signer: _signer,
      recipient: requirements.payTo,
      amount: amount,
      tokenMint: requirements.asset,
      feePayer: feePayer,
      solanaClient: _solanaClient,
    );

    // Create payment payload
    return PaymentPayload(
      x402Version: kX402Version,
      resource: resource,
      accepted: requirements,
      payload: {'transaction': encodedTransaction},
      extensions: extensions,
    );
  }
}
