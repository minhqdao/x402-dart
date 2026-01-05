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

  // 2. Initialize X402Client
  final x402Client = X402Client();

  try {
    // 3. Perform request
    stdout.writeln('Requesting premium content from $host...');
    final result = await x402Client.get(Uri.parse('$host/premium-content'));

    // 4. Handle results sequentially using pattern matching
    final finalResponse = await (switch (result) {
      X402StandardResponse(response: final r) => Future.value(r),
      X402PaymentRequired(requirements: final reqs) => () async {
        stdout.writeln('--- Payment Required ---');
        final req = reqs.first; // Pick first for demo
        stdout.writeln('Need to pay: ${req.amount} ${req.asset}');

        // Sign the requirement
        final signature = await evmSigner.sign(req);

        // Retry with signature
        stdout.writeln('Retrying with signature...');
        final retryResult = await x402Client.get(
          Uri.parse('$host/premium-content'),
          signature: signature,
        );

        return switch (retryResult) {
          X402StandardResponse(response: final r) => r,
          X402PaymentRequired() => throw Exception('Payment failed after retry'),
        };
      }(),
    });

    if (finalResponse.statusCode == 200) {
      stdout.writeln('--- Success! ---');
      stdout.writeln('Content: ${finalResponse.body}');
    } else {
      stdout.writeln('--- Failed ---');
      stdout.writeln('Status: ${finalResponse.statusCode}');
      stdout.writeln('Body: ${finalResponse.body}');
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    x402Client.close();
  }
}
