import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/models/exact_evm_payload.dart';
import 'package:x402_evm/src/network/evm_network.dart';
import 'package:x402_evm/src/utils/eip3009.dart';

/// Function type that provides the current Unix timestamp in seconds.
typedef NowProvider = int Function();

/// Function type that provides a unique nonce for signing.
typedef NonceProvider = Uint8List Function();

/// Client-side implementation of the "exact" payment scheme for EVM-based chains.
///
/// This client uses EIP-3009 (transferWithAuthorization) to authorize payments.
/// By default, it uses the current system time and a random nonce, but these can
/// be overridden via [nowProvider] and [nonceProvider] for deterministic behavior
/// in testing or specific application flows.
class ExactEvmSchemeClient implements SchemeClient {
  static const _schemeId = 'exact';

  final EthPrivateKey _privateKey;
  final NowProvider _nowProvider;
  final NonceProvider _nonceProvider;

  @override
  final EvmNetwork network;

  /// Creates an [ExactEvmSchemeClient] with the given [privateKey].
  ///
  /// Optional [nowProvider] and [nonceProvider] can be supplied to control
  /// time and nonce generation.
  ExactEvmSchemeClient({
    required EthPrivateKey privateKey,
    String networkNamespace = 'eip155',
    required int chainId,
    NowProvider? nowProvider,
    NonceProvider? nonceProvider,
  })  : network = EvmNetwork(namespace: networkNamespace, chainId: chainId),
        _privateKey = privateKey,
        _nowProvider = nowProvider ??
            (() => DateTime.now().millisecondsSinceEpoch ~/ 1000),
        _nonceProvider = nonceProvider ?? EIP3009.generateNonce;

  @override
  String get scheme => _schemeId;

  /// Creates a signed [PaymentPayload] for an EVM transaction using EIP-3009.
  ///
  /// The [requirements] must include 'name' and 'version' in the `extra` field,
  /// representing the token metadata.
  ///
  /// Throws [UnsupportedSchemeException] if the scheme is not "exact".
  /// Throws [InvalidPayloadException] if the network format is invalid or
  /// required metadata is missing.
  @override
  Future<PaymentPayload> createPaymentPayload(
    PaymentRequirement requirements,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  }) async {
    // Validate scheme
    if (requirements.scheme != scheme) {
      throw UnsupportedSchemeException(
          'Expected scheme "$scheme", got "${requirements.scheme}"');
    }

    // Parse network (format: eip155:chainId)
    if (requirements.network.namespace != 'eip155') {
      throw InvalidPayloadException(
          'Invalid network format. Expected "eip155:chainId", got "${requirements.network}"');
    }
    final chainId = int.parse(requirements.network.reference);

    // Parse amount
    final amount = BigInt.parse(requirements.amount);

    // Get token metadata from extra
    final tokenName = requirements.extra['name']?.toString();
    final tokenVersion = requirements.extra['version']?.toString();
    if (tokenName == null || tokenVersion == null) {
      throw const InvalidPayloadException(
          'Missing name or version in extra field');
    }

    // Generate nonce and validity window
    final nonce = _nonceProvider();
    final now = _nowProvider();

    // Using 0 for validAfter is standard for "valid immediately" and avoids clock skew
    final validAfter = BigInt.zero;
    final validBefore = BigInt.from(now + requirements.maxTimeoutSeconds);

    // Create signature
    final signature = EIP3009.createAuthorizationSignature(
      privateKey: _privateKey,
      tokenAddress: requirements.asset.toLowerCase(),
      chainId: chainId,
      tokenName: tokenName,
      tokenVersion: tokenVersion,
      to: requirements.payTo.toLowerCase(),
      value: amount,
      validAfter: validAfter,
      validBefore: validBefore,
      nonce: nonce,
    );

    // Create authorization object
    final authorization = ExactEvmPayload(
      from: _privateKey.address.hex.toLowerCase(),
      to: requirements.payTo.toLowerCase(),
      value: amount.toString(),
      validAfter: validAfter.toString(),
      validBefore: validBefore.toString(),
      nonce: '0x${hex.encode(nonce)}',
    );

    // Create payment payload
    return PaymentPayload(
      x402Version: kX402Version,
      resource: resource,
      accepted: requirements,
      payload: {
        'signature': EIP3009.encodeSignature(signature),
        'authorization': authorization.toJson()
      },
      extensions: extensions,
    );
  }

  /// Returns the Ethereum address associated with the private key.
  String get address => _privateKey.address.hex;
}
