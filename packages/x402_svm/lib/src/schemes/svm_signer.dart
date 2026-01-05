import 'dart:convert';
import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/schemes/exact_svm_client.dart';

/// Concrete implementation of X402Signer for SVM chains
class SvmSigner extends X402Signer {
  @override
  final String networkId;
  final ExactSvmSchemeClient _client;

  SvmSigner({
    required this.networkId,
    required Ed25519HDKeyPair signer,
    required SolanaClient solanaClient,
  }) : _client = ExactSvmSchemeClient(signer: signer, solanaClient: solanaClient);

  @override
  String get scheme => _client.scheme;

  @override
  Future<String> sign(X402Requirement requirement) async {
    final payload = await _client.createPaymentPayload(requirement);
    return base64Encode(utf8.encode(jsonEncode(payload.toJson())));
  }
}
