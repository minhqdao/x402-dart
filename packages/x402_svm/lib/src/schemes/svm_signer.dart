import 'dart:convert';
import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/schemes/exact_svm_client.dart';

/// Concrete implementation of X402Signer for SVM chains
class SvmSigner extends X402Signer {
  @override
  final String networkId;
  final ExactSvmSchemeClient _client;
  final Ed25519HDKeyPair signer; // Exposed for convenience

  /// Creates an SvmSigner.
  /// `networkNamespace` defaults to "svm".
  SvmSigner({
    required String networkType,
    required this.signer,
    required SolanaClient solanaClient,
    String networkNamespace = 'svm',
  }) : networkId = '$networkNamespace:$networkType',
       _client = ExactSvmSchemeClient(signer: signer, solanaClient: solanaClient);

  /// Creates an SvmSigner from a mnemonic phrase.
  /// `networkNamespace` defaults to "svm".
  static Future<SvmSigner> fromMnemonic({
    required String mnemonic,
    required String networkType,
    required SolanaClient solanaClient,
    String networkNamespace = 'svm',
  }) async {
    final signer = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    return SvmSigner(
      networkType: networkType,
      signer: signer,
      solanaClient: solanaClient,
      networkNamespace: networkNamespace,
    );
  }

  @override
  String get scheme => _client.scheme;

  @override
  Future<String> sign(X402Requirement requirement) async {
    final payload = await _client.createPaymentPayload(requirement);
    return base64Encode(utf8.encode(jsonEncode(payload.toJson())));
  }
}
