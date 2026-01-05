import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/schemes/exact_evm_client.dart';

/// Concrete implementation of X402Signer for EVM chains
class EvmSigner extends X402Signer {
  @override
  final String networkId;
  final ExactEvmSchemeClient _client;

  EvmSigner({required this.networkId, required EthPrivateKey privateKey})
    : _client = ExactEvmSchemeClient(privateKey: privateKey);

  @override
  String get scheme => _client.scheme;

  @override
  Future<String> sign(X402Requirement requirement) async {
    final payload = await _client.createPaymentPayload(requirement);
    return base64Encode(utf8.encode(jsonEncode(payload.toJson())));
  }
}
