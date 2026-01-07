import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/models/exact_payload.dart';
import 'package:x402_evm/src/utils/eip3009.dart';

/// Server-side implementation of the exact scheme for EVM chains
class ExactEvmSchemeServer implements SchemeServer {
  const ExactEvmSchemeServer();

  @override
  String get scheme => 'exact';

  @override
  Future<bool> verifyPayload(PaymentPayload payload, PaymentRequirement requirements) async {
    try {
      // Validate scheme
      if (payload.accepted.scheme != scheme || requirements.scheme != scheme) {
        return false;
      }

      // Validate network
      if (payload.accepted.network != requirements.network) {
        return false;
      }

      // Parse network
      final networkParts = requirements.network.split(':');
      if (networkParts.length != 2 || networkParts[0] != 'eip155') {
        return false;
      }
      final chainId = int.parse(networkParts[1]);

      // Parse payload
      final exactPayload = ExactPayloadData.fromPaymentPayload(payload);
      final auth = exactPayload.authorization;

      // Verify amounts match
      final expectedAmount = BigInt.parse(requirements.amount);
      final actualAmount = BigInt.parse(auth.value);
      if (actualAmount != expectedAmount) {
        return false;
      }

      // Verify recipient
      if (auth.to.toLowerCase() != requirements.payTo.toLowerCase()) {
        return false;
      }

      // Verify validity window
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final validAfter = int.parse(auth.validAfter);
      final validBefore = int.parse(auth.validBefore);

      if (now < validAfter || now > validBefore) {
        return false;
      }

      // Get token metadata
      final tokenName = requirements.extra['name'] as String?;
      final tokenVersion = requirements.extra['version'] as String?;
      if (tokenName == null || tokenVersion == null) {
        return false;
      }

      // Decode signature
      final signature = EIP3009.decodeSignature(exactPayload.signature);

      // Parse nonce
      final nonceHex = auth.nonce.startsWith('0x') ? auth.nonce.substring(2) : auth.nonce;
      final nonce = Uint8List.fromList(hex.decode(nonceHex));

      // Verify signature
      return EIP3009.verifyAuthorizationSignature(
        tokenAddress: requirements.asset,
        chainId: chainId,
        tokenName: tokenName,
        tokenVersion: tokenVersion,
        from: auth.from,
        to: auth.to,
        value: actualAmount,
        validAfter: BigInt.from(validAfter),
        validBefore: BigInt.from(validBefore),
        nonce: nonce,
        signature: signature,
      );
    } catch (e) {
      return false;
    }
  }
}
