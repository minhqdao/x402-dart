import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/schemes/exact_evm_scheme_client.dart';

/// Concrete implementation of [X402Signer] for EVM chains.
///
/// This signer uses an [EthPrivateKey] to sign EIP-3009 authorizations.
class EvmSigner extends X402Signer {
  @override
  final String network;
  final ExactEvmSchemeClient _client;

  /// Creates an [EvmSigner] from an [ExactEvmSchemeClient] and a [chainId].
  ///
  /// [networkNamespace] defaults to "eip155" (standard for EVM).
  ///
  /// Usually use [EvmSigner.fromHex] for convenience.
  EvmSigner.fromClient({
    required ExactEvmSchemeClient client,
    required int chainId,
    String networkNamespace = 'eip155',
  })  : network = '$networkNamespace:$chainId',
        _client = client;

  /// Creates an EvmSigner from a hexadecimal private key string.
  /// The `privateKeyHex` string can optionally be prefixed with "0x".
  factory EvmSigner.fromHex({
    required String privateKeyHex,
    required int chainId,
    String networkNamespace = 'eip155',
  }) {
    final cleanedHex =
        privateKeyHex.startsWith('0x') ? privateKeyHex : '0x$privateKeyHex';
    return EvmSigner.fromClient(
      client:
          ExactEvmSchemeClient(privateKey: EthPrivateKey.fromHex(cleanedHex)),
      chainId: chainId,
      networkNamespace: networkNamespace,
    );
  }

  @override
  String get address => _client.address;

  @override
  String get scheme => _client.scheme;

  /// Signs a payment request and returns a serialized payment payload.
  ///
  /// This method creates a scheme-specific payment payload for the given
  /// [requirement] and [resource], signs it using the underlying EVM signer,
  /// and serializes the result into a Base64-encoded string.
  ///
  /// The returned string is:
  /// 1. A JSON representation of the payment payload
  /// 2. UTF-8 encoded
  /// 3. Base64 encoded for safe transport over text-based protocols
  ///
  /// Optional [extensions] can be provided to include additional
  /// scheme- or application-specific metadata in the payload.
  ///
  /// Returns a Base64-encoded string containing the signed payment payload.
  ///
  /// Throws an [UnsupportedSchemeException] or [InvalidPayloadException]
  /// if the payment requirement is incompatible with this signer.
  @override
  Future<String> sign(PaymentRequirement requirement, ResourceInfo resource,
      {Map<String, dynamic>? extensions}) async {
    final payload = await _client.createPaymentPayload(requirement, resource,
        extensions: extensions);
    return base64Encode(utf8.encode(jsonEncode(payload.toJson())));
  }
}
