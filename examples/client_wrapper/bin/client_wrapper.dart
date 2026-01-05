import 'dart:io';
import 'package:web3dart/web3dart.dart';
import 'package:x402/x402.dart';

// Constants
const _defaultHost = 'http://127.0.0.1:8080';

void main(List<String> args) async {
  // 1. Setup (Once per app)
  final EthPrivateKey privateKey = EthPrivateKey.fromHex(
    '0x1234567890123456789012345678901234567890123456789012345678901234',
  );

  final client = X402Client(
    signers: [
      EvmSigner(networkId: 'eip155:8453', privateKey: privateKey), // Prefer Base
    ],
    onPaymentRequired: (req) async {
      stdout.writeln('--- Magic Payment Approval ---');
      stdout.writeln('Paying ${req.amount} for ${req.resource}...');
      return true; // Simple auto-approve
    },
  );

  stdout.writeln('Using EVM address: ${privateKey.address.hex}');

  try {
    // 2. Usage (Anywhere in your app)
    // The developer doesn't even see the 402. It just works.
    stdout.writeln('Requesting premium content...');
    final response = await client.get(Uri.parse('$_defaultHost/premium-content'));

    if (response.statusCode == 200) {
      stdout.writeln('--- Success! ---');
      stdout.writeln('Data received: ${response.body}');
    } else {
      stdout.writeln('--- Failed ---');
      stdout.writeln('Status: ${response.statusCode}');
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    client.close();
  }
}
