import 'dart:io';

import 'package:x402_evm/x402_evm.dart';

void main() {
  final signer = EvmSigner.fromPrivateKeyHex(
    chainId: 1, // Ethereum Mainnet
    privateKeyHex: 'YOUR_PRIVATE_KEY',
  );

  stdout.writeln('EVM Signer Address: ${signer.address}');
  stdout.writeln('Supported Network: ${signer.network}');

  // This signer can now be passed to the X402Client or used manually
}
