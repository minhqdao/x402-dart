import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/schemes/exact_evm_client.dart';

/// Concrete implementation of X402Signer for EVM chains
class EvmSigner extends X402Signer {
  @override
  final String network;
  final ExactEvmSchemeClient _client;
  final EthPrivateKey _privateKey;

  /// Creates an EvmSigner.
  /// `networkNamespace` defaults to "eip155".
  EvmSigner(
      {required int chainId,
      required EthPrivateKey privateKey,
      String networkNamespace = 'eip155'})
      : network = '$networkNamespace:$chainId',
        _privateKey = privateKey,
        _client = ExactEvmSchemeClient(privateKey: privateKey);

  /// Creates an EvmSigner from a hexadecimal private key string.
  /// The `privateKeyHex` string can optionally be prefixed with "0x".
  /// `networkNamespace` defaults to "eip155".
  factory EvmSigner.fromHex(
      {required String privateKeyHex,
      required int chainId,
      String networkNamespace = 'eip155'}) {
    final cleanedHex =
        (privateKeyHex.startsWith('0x') ? privateKeyHex : '0x$privateKeyHex')
            .toLowerCase();
    final privateKey = EthPrivateKey.fromHex(cleanedHex);
    return EvmSigner(
        chainId: chainId,
        privateKey: privateKey,
        networkNamespace: networkNamespace);
  }

  @override
  String get address => _privateKey.address.hex;

  @override
  String get scheme => _client.scheme;

  @override
  Future<String> sign(PaymentRequirement requirement, ResourceInfo resource,
      {Map<String, dynamic>? extensions}) async {
    final payload = await _client.createPaymentPayload(requirement, resource,
        extensions: extensions);
    return base64Encode(utf8.encode(jsonEncode(payload.toJson())));
  }
}
