import 'dart:typed_data';
import 'package:web3dart/crypto.dart';

Uint8List toBytes(BigInt value, {int length = 32}) {
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
