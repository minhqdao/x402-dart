import 'dart:io';

import 'package:x402_svm/x402_svm.dart';

void main() async {
  final signer = await SvmSigner.fromHex(
    privateKeyHex: 'YOUR_SOLANA_PRIVATE_KEY_HEX',
    network: SolanaNetwork.devnet,
  );

  stdout.writeln('SVM Signer Address: ${signer.address}');
  stdout.writeln('Supported Network: ${signer.network}');

  // This signer can now be passed to the X402Client or used manually
}
