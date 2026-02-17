import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/utils/svm_transaction_builder.dart';

/// Scheme implementation for the "exact" SVM (Solana) payment flow.
///
/// This client handles the creation of a Solana transaction that performs
/// an SPL Token transfer satisfying the provided [PaymentRequirement].
class ExactSvmSchemeClient implements SchemeClient {
  static const _schemeId = 'v2:solana:exact';

  final Ed25519HDKeyPair _signer;
  final SolanaClient _solanaClient;

  /// Creates an [ExactSvmSchemeClient] with the given [signer] and [solanaClient].
  const ExactSvmSchemeClient(
      {required Ed25519HDKeyPair signer, required SolanaClient solanaClient})
      : _signer = signer,
        _solanaClient = solanaClient;

  @override
  String get scheme => _schemeId;

  /// Creates a [PaymentPayload] for an SVM transaction.
  ///
  /// The [requirement] must:
  /// 1. Use a supported scheme ("v2:solana:exact" or "exact").
  /// 2. Use a valid Solana network format ("solana:genesisHash").
  /// 3. Specify a 'feePayer' in the `extra` field.
  ///
  /// This method constructs a transfer transaction, signs it, and
  /// returns it within a [PaymentPayload].
  ///
  /// Throws [UnsupportedSchemeException] if the scheme is not supported.
  /// Throws [InvalidPayloadException] if the network format is invalid or
  /// required data (like feePayer) is missing.
  @override
  Future<PaymentPayload> createPaymentPayload(
    PaymentRequirement requirement,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  }) async {
    _validateRequirement(requirement);

    // Parse amount
    final amount = BigInt.parse(requirement.amount);

    // Extract feePayer from requirements.extra
    final feePayer = requirement.extra['feePayer'] as String?;
    if (feePayer == null) {
      throw const InvalidPayloadException(
          'feePayer is required in paymentRequirements.extra for SVM transactions');
    }

    // Build transfer transaction
    final encodedTransaction =
        await SvmTransactionBuilder.createTransferTransaction(
      signer: _signer,
      recipient: requirement.payTo,
      amount: amount,
      tokenMint: requirement.asset,
      feePayer: feePayer,
      solanaClient: _solanaClient,
    );

    // Create payment payload
    return PaymentPayload(
      x402Version: kX402Version,
      resource: resource,
      accepted: requirement,
      payload: {'transaction': encodedTransaction.transaction},
      extensions: extensions,
    );
  }

  /// Returns the public address (Base58) of the signer.
  String get address => _signer.publicKey.toBase58();

  void _validateRequirement(PaymentRequirement r) {
    if (r.scheme != scheme && r.scheme != 'exact') {
      throw UnsupportedSchemeException(
        'Expected scheme "$scheme" or "exact", got "${r.scheme}"',
      );
    }

    if (r.network.namespace != 'solana') {
      throw InvalidPayloadException(
        'Invalid network. Expected Solana network, got "${r.network}"',
      );
    }

    if (!r.extra.containsKey('feePayer')) {
      throw const InvalidPayloadException(
        'feePayer is required in paymentRequirements.extra for SVM transactions',
      );
    }
  }
}
