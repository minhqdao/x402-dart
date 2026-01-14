import 'package:convert/convert.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/models/exact_payload.dart';
import 'package:x402_evm/src/utils/eip3009.dart';

/// Client-side implementation of the exact scheme for EVM chains
class ExactEvmSchemeClient implements SchemeClient {
  final EthPrivateKey _privateKey;

  const ExactEvmSchemeClient({required EthPrivateKey privateKey}) : _privateKey = privateKey;

  @override
  String get scheme => 'exact';

  @override
  Future<PaymentPayload> createPaymentPayload(
    PaymentRequirement requirements,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  }) async {
    // Validate scheme
    if (requirements.scheme != scheme) {
      throw UnsupportedSchemeException('Expected scheme "$scheme", got "${requirements.scheme}"');
    }

    // Parse network (format: eip155:chainId)
    final networkParts = requirements.network.split(':');
    if (networkParts.length != 2 || networkParts[0] != 'eip155') {
      throw InvalidPayloadException('Invalid network format. Expected "eip155:chainId", got "${requirements.network}"');
    }
    final chainId = int.parse(networkParts[1]);

    // Parse amount
    final amount = BigInt.parse(requirements.amount);

    // Get token metadata from extra
    final tokenName = requirements.extra['name']?.toString();
    final tokenVersion = requirements.extra['version']?.toString();
    if (tokenName == null || tokenVersion == null) {
      throw const InvalidPayloadException('Missing name or version in extra field');
    }

    // Generate nonce and validity window
    final nonce = EIP3009.generateNonce();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
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
    final authorization = ExactAuthorization(
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
      payload: {'signature': EIP3009.encodeSignature(signature), 'authorization': authorization.toJson()},
      extensions: extensions,
    );
  }
}
