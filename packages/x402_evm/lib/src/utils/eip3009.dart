import 'dart:math';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_evm/src/utils/eip712.dart';

/// EIP-3009 utilities for transferWithAuthorization
class EIP3009 {
  const EIP3009._();

  /// Generate a random nonce (32 bytes)
  static Uint8List generateNonce() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
  }

  /// Create authorization signature for transferWithAuthorization
  static MsgSignature createAuthorizationSignature({
    required EthPrivateKey privateKey,
    required String tokenAddress,
    required int chainId,
    required String tokenName,
    required String tokenVersion,
    required String to,
    required BigInt value,
    required BigInt validAfter,
    required BigInt validBefore,
    required Uint8List nonce,
  }) {
    final domain = EIP712Domain(
      name: tokenName,
      version: tokenVersion,
      chainId: chainId,
      verifyingContract: tokenAddress,
    );

    final structHash = EIP712Utils.hashTransferWithAuthorization(
      from: privateKey.address.hex,
      to: to,
      value: value,
      validAfter: validAfter,
      validBefore: validBefore,
      nonce: nonce,
    );

    return EIP712Utils.signTypedData(
        privateKey: privateKey, domain: domain, structHash: structHash);
  }

  /// Verify authorization signature
  static bool verifyAuthorizationSignature({
    required String tokenAddress,
    required int chainId,
    required String tokenName,
    required String tokenVersion,
    required String from,
    required String to,
    required BigInt value,
    required BigInt validAfter,
    required BigInt validBefore,
    required Uint8List nonce,
    required MsgSignature signature,
  }) {
    final domain = EIP712Domain(
      name: tokenName,
      version: tokenVersion,
      chainId: chainId,
      verifyingContract: tokenAddress,
    );

    final structHash = EIP712Utils.hashTransferWithAuthorization(
      from: from,
      to: to,
      value: value,
      validAfter: validAfter,
      validBefore: validBefore,
      nonce: nonce,
    );

    final recoveredAddress = EIP712Utils.recoverSigner(
        domain: domain, structHash: structHash, signature: signature);

    return recoveredAddress.hex.toLowerCase() == from.toLowerCase();
  }

  static Uint8List _toFixedLengthBytes(BigInt value, {int length = 32}) {
    final bytes = unsignedIntToBytes(value);

    if (bytes.length > length) {
      // Return only the last N bytes if it overflows (standard for EVM)
      return bytes.sublist(bytes.length - length);
    }

    // Create a fixed-length list and fill it from the right
    final padded = Uint8List(length);
    padded.setRange(length - bytes.length, length, bytes);
    return padded;
  }

  /// Encode signature as hex string
  static String encodeSignature(MsgSignature signature) {
    final r = hex.encode(_toFixedLengthBytes(signature.r));
    final s = hex.encode(_toFixedLengthBytes(signature.s));
    final v = signature.v.toRadixString(16).padLeft(2, '0');
    return '0x$r$s$v';
  }

  /// Decode signature from hex string
  static MsgSignature decodeSignature(String encodedSignature) {
    final signatureBytes = hexToBytes(encodedSignature);

    final rBytes = signatureBytes.sublist(0, 32);
    final sBytes = signatureBytes.sublist(32, 64);
    final vValue = signatureBytes[64];

    return MsgSignature(
        bytesToUnsignedInt(rBytes), bytesToUnsignedInt(sBytes), vValue);
  }
}
