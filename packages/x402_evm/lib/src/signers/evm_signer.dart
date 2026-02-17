import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/network/evm_network.dart';
import 'package:x402_evm/src/schemes/exact_evm_scheme_client.dart';

/// Concrete implementation of [X402Signer] for EVM chains.
///
/// This signer uses an [EthPrivateKey] to sign EIP-3009 authorizations.
/// It delegates the scheme-specific payload creation to [ExactEvmSchemeClient].
class EvmSigner extends X402Signer {
  /// The CAIP-2 network this signer operates on.
  ///
  /// For EVM networks this is typically `eip155:<chainId>`.
  ///
  /// Example:
  /// - `eip155:1` (Ethereum mainnet)
  /// - `eip155:8453` (Base mainnet)
  @override
  final Network network;

  final ExactEvmSchemeClient _client;

  /// Creates an [EvmSigner] from an [ExactEvmSchemeClient] and a [chainId].
  ///
  /// [networkNamespace] defaults to "eip155" (standard for EVM-based chains).
  ///
  /// Usually use [EvmSigner.fromPrivateKeyHex] for convenience.
  EvmSigner.fromClient({
    required ExactEvmSchemeClient client,
    required int chainId,
    String networkNamespace = 'eip155',
  })  : network = EvmNetwork(namespace: networkNamespace, chainId: chainId),
        _client = client;

  /// Creates an [EvmSigner] from a hexadecimal private key string.
  ///
  /// The [privateKeyHex] string can optionally be prefixed with "0x".
  /// [chainId] specifies the target network.
  /// [networkNamespace] defaults to "eip155".
  factory EvmSigner.fromPrivateKeyHex({
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

  /// Signs a payment request and returns a [SignedPayment].
  ///
  /// This method:
  /// 1. Validates the [requirement] against the signer's supported network and asset.
  /// 2. Delegates payload creation to the underlying scheme client.
  /// 3. Returns a [SignedPayment] containing the base64-encoded result.
  ///
  /// Optional [extensions] can be provided to include additional metadata in the payload.
  ///
  /// Throws an [ArgumentError] if the requirement is invalid.
  /// Throws [UnsupportedSchemeException] or [InvalidPayloadException] if signing fails.
  @override
  Future<SignedPayment> sign(
      PaymentRequirement requirement, ResourceInfo resource,
      {Map<String, dynamic>? extensions}) async {
    _validateRequirement(requirement);
    final payload = await _client.createPaymentPayload(requirement, resource,
        extensions: extensions);
    return SignedPayment(
        base64Encode(utf8.encode(jsonEncode(payload.toJson()))));
  }

  /// Internal validation of the payment requirement.
  void _validateRequirement(PaymentRequirement requirement) {
    final amount = BigInt.tryParse(requirement.amount);
    if (amount == null) {
      throw ArgumentError.value(
        requirement.amount,
        'amount',
        'Amount must be a valid integer string',
      );
    }

    if (amount <= BigInt.zero) {
      throw ArgumentError.value(
        requirement.amount,
        'amount',
        'Amount must be greater than zero',
      );
    }

    if (requirement.maxTimeoutSeconds < 0) {
      throw ArgumentError.value(
        requirement.maxTimeoutSeconds,
        'maxTimeoutSeconds',
        'Must be non-negative',
      );
    }

    if (requirement.network != network) {
      throw ArgumentError(
        'Requirement network (${requirement.network}) '
        'does not match signer network ($network)',
      );
    }
  }
}
