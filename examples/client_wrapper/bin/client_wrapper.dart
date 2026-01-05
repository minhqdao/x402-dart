import 'dart:io';
import 'package:args/args.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402/x402.dart';

// Constants
const _defaultHost = 'http://127.0.0.1:8080';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('host', abbr: 'h', defaultsTo: _defaultHost)
    ..addOption('private-key', abbr: 'k', help: 'EVM Private key (hex)');

  final result = parser.parse(args);
  final host = result['host'] as String;
  final privateKeyHex = result['private-key'] as String?;

  // 1. Initialize signer
  final EthPrivateKey privateKey;
  if (privateKeyHex != null) {
    privateKey = EthPrivateKey.fromHex(privateKeyHex);
  } else {
    // Fixed test key for deterministic demo
    privateKey = EthPrivateKey.fromHex(
      '0x1234567890123456789012345678901234567890123456789012345678901234',
    );
  }

  final evmSigner = EvmSigner(networkId: 'eip155:8453', privateKey: privateKey);

  stdout.writeln('Using EVM address: ${privateKey.address.hex}');

  // 2. Initialize X402Client wrapper
  final x402Client = X402Client(
    signers: [evmSigner],
    onPaymentRequired: (requirement) async {
      stdout.writeln('--- Payment Approval Required ---');
      stdout.writeln('Resource: ${requirement.resource}');
      stdout.writeln('Network: ${requirement.network}');
      stdout.writeln('Asset: ${requirement.asset}');
      stdout.writeln('Amount: ${requirement.maxAmountRequired}');
      stdout.writeln('Approving payment...');
      return true; // Auto-approve for demo
    },
  );

  try {
    // 3. Simple GET request
    // The wrapper handles 402 -> sign -> retry automatically
    stdout.writeln('Requesting premium content from $host...');
    final response = await x402Client.get(Uri.parse('$host/premium-content'));

    if (response.statusCode == 200) {
      stdout.writeln('--- Success! ---');
      stdout.writeln('Content: ${response.body}');
    } else {
      stdout.writeln('--- Failed ---');
      stdout.writeln('Status: ${response.statusCode}');
      stdout.writeln('Body: ${response.body}');
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    x402Client.close();
  }
}
