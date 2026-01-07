import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

/// EIP-712 domain separator
class EIP712Domain {
  final String name;
  final String version;
  final int chainId;
  final String verifyingContract;

  const EIP712Domain({
    required this.name,
    required this.version,
    required this.chainId,
    required this.verifyingContract,
  });

  Map<String, dynamic> toJson() {
    return {'name': name, 'version': version, 'chainId': chainId, 'verifyingContract': verifyingContract};
  }
}

/// EIP-712 typed data utilities
class EIP712Utils {
  const EIP712Utils._();

  static const String domainTypeHash = '0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f';

  /// Compute domain separator
  static Uint8List computeDomainSeparator(EIP712Domain domain) {
    final encoded = encodePacked([
      hexToBytes(domainTypeHash),
      keccak256(utf8.encode(domain.name)),
      keccak256(utf8.encode(domain.version)),
      _uint256(domain.chainId),
      _addressToBytes(domain.verifyingContract),
    ]);
    return keccak256(encoded);
  }

  /// Hash struct for EIP-3009 TransferWithAuthorization
  static Uint8List hashTransferWithAuthorization({
    required String from,
    required String to,
    required BigInt value,
    required BigInt validAfter,
    required BigInt validBefore,
    required Uint8List nonce,
  }) {
    const typeHash = '0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267';

    final encoded = encodePacked([
      hexToBytes(typeHash),
      _addressToBytes(from),
      _addressToBytes(to),
      _uint256Bytes(value),
      _uint256Bytes(validAfter),
      _uint256Bytes(validBefore),
      nonce,
    ]);

    return keccak256(encoded);
  }

  /// Create EIP-712 message hash
  static Uint8List createMessageHash({required Uint8List domainSeparator, required Uint8List structHash}) {
    final encoded = encodePacked([
      Uint8List.fromList([0x19, 0x01]),
      domainSeparator,
      structHash,
    ]);
    return keccak256(encoded);
  }

  /// Sign EIP-712 typed data
  static MsgSignature signTypedData({
    required EthPrivateKey privateKey,
    required EIP712Domain domain,
    required Uint8List structHash,
  }) {
    final domainSeparator = computeDomainSeparator(domain);
    final messageHash = createMessageHash(domainSeparator: domainSeparator, structHash: structHash);

    return sign(messageHash, privateKey.privateKey);
  }

  /// Recover signer from EIP-712 signature
  static EthereumAddress recoverSigner({
    required EIP712Domain domain,
    required Uint8List structHash,
    required MsgSignature signature,
  }) {
    final domainSeparator = computeDomainSeparator(domain);
    final messageHash = createMessageHash(domainSeparator: domainSeparator, structHash: structHash);

    final publicKey = ecRecover(messageHash, signature);
    final addressBytes = publicKeyToAddress(publicKey);

    return EthereumAddress(addressBytes);
  }

  // Helper functions
  static Uint8List _uint256(int value) {
    return _uint256Bytes(BigInt.from(value));
  }

  static Uint8List _uint256Bytes(BigInt value) {
    final bytes = value.toRadixString(16).padLeft(64, '0');
    return hexToBytes('0x$bytes');
  }

  static Uint8List _addressToBytes(String address) {
    final addr = EthereumAddress.fromHex(address.toLowerCase());
    return Uint8List.fromList([...List.filled(12, 0), ...addr.addressBytes]);
  }

  static Uint8List encodePacked(List<Uint8List> values) {
    final result = <int>[];
    for (final value in values) {
      result.addAll(value);
    }
    return Uint8List.fromList(result);
  }

  static Uint8List hexToBytes(String hexString) {
    final cleanHex = hexString.startsWith('0x') ? hexString.substring(2) : hexString;
    return Uint8List.fromList(List<int>.from(hex.decode(cleanHex)));
  }
}
