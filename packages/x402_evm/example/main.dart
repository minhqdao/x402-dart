import 'dart:io';

import 'package:web3dart/web3dart.dart';
import 'package:x402_evm/x402_evm.dart';

void main() {
  final privateKey = EthPrivateKey.fromHex('YOUR_PRIVATE_KEY');
  final signer = EvmSigner(
    chainId: 1, // Ethereum Mainnet
    privateKey: privateKey,
  );

  stdout.writeln('EVM Signer Address: ${signer.address}');
  stdout.writeln('Supported Network: ${signer.network}');

  // This signer can now be passed to the X402Client or used manually
}
