import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:solana/solana.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402/x402.dart';

const _defaultHost = 'http://localhost:3002';
const _svmRpcUrl = 'https://api.devnet.solana.com';
const _svmWsUrl = 'wss://api.devnet.solana.com';

void main(List<String> args) async {
  final parser = ArgParser()..addOption('host', abbr: 'h', defaultsTo: _defaultHost);
  final result = parser.parse(args);
  final host = result['host'] as String;

  final client = http.Client();

  try {
    // 1. Initial HTTP Request
    stdout.writeln('Making initial request to $host/premium-content...');
    final initialResponse = await client.get(Uri.parse('$host/api/data'));

    if (initialResponse.statusCode == 200) {
      stdout.writeln('--- Success (no payment required) ---');
      stdout.writeln('Content: ${initialResponse.body}');
      return;
    }

    if (initialResponse.statusCode != kPaymentRequiredStatus) {
      stdout.writeln('--- Error: Unexpected status code ---');
      stdout.writeln('Status: ${initialResponse.statusCode}');
      stdout.writeln('Body: ${initialResponse.body}');
      return;
    }

    // 2. Handle 402 Payment Required
    stdout.writeln('--- 402 Payment Required ---');
    final header = initialResponse.headers[kPaymentRequiredHeader];
    if (header == null) {
      stdout.writeln('Error: Missing $kPaymentRequiredHeader header.');
      return;
    }

    final paymentResponse = PaymentRequiredResponse.fromJson(
      jsonDecode(utf8.decode(base64Decode(header))) as Map<String, dynamic>,
    );

    // 3. Negotiate Requirements and Sign
    X402Signer? chosenSigner;
    X402Requirement? chosenRequirement;
    String? signature;

    // Initialize EVM signer
    final evmPrivateKey = EthPrivateKey.fromHex('0x1234567890123456789012345678901234567890123456789012345678901234');
    final evmSigner = EvmSigner(networkId: 'eip155:31337', privateKey: evmPrivateKey);
    stdout.writeln('EVM Address: ${evmPrivateKey.address.hex}');

    // Try EVM first
    final evmReq = paymentResponse.accepts.firstWhereOrNull(
      (req) => req.network == evmSigner.networkId && req.scheme == evmSigner.scheme,
    );
    if (evmReq != null) {
      stdout.writeln('Negotiated EVM payment via ${evmReq.network} (amount: ${evmReq.amount})');
      chosenSigner = evmSigner;
      chosenRequirement = evmReq;
    } else {
      // Initialize SVM signer
      final svmSignerKeypair = await Ed25519HDKeyPair.random();
      final svmSolanaClient = SolanaClient(rpcUrl: Uri.parse(_svmRpcUrl), websocketUrl: Uri.parse(_svmWsUrl));
      final svmSigner = SvmSigner(networkId: 'svm:mainnet', signer: svmSignerKeypair, solanaClient: svmSolanaClient);
      stdout.writeln('SVM Address: ${svmSignerKeypair.address}');

      // Try SVM
      final svmReq = paymentResponse.accepts.firstWhereOrNull(
        (req) => req.network == svmSigner.networkId && req.scheme == svmSigner.scheme,
      );
      if (svmReq != null) {
        stdout.writeln('Negotiated SVM payment via ${svmReq.network} (amount: ${svmReq.amount})');
        chosenSigner = svmSigner;
        chosenRequirement = svmReq;
      }
    }

    if (chosenSigner == null || chosenRequirement == null) {
      stdout.writeln('Error: No compatible signer found for requirements.');
      return;
    }

    stdout.writeln('Signing payment payload...');
    signature = await chosenSigner.sign(chosenRequirement);

    // 4. Retry Request with Signature
    stdout.writeln('Retrying request with signature...');
    final retryResponse = await client.get(
      Uri.parse('$host/premium-content'),
      headers: {kPaymentSignatureHeader: signature},
    );

    if (retryResponse.statusCode == 200) {
      stdout.writeln('--- Success (payment approved) ---');
      stdout.writeln('Content: ${retryResponse.body}');
    } else {
      stdout.writeln('--- Failed (payment rejected) ---');
      stdout.writeln('Status: ${retryResponse.statusCode}');
      stdout.writeln('Body: ${retryResponse.body}');
    }
  } catch (e) {
    stdout.writeln('--- Error ---');
    stdout.writeln('An unexpected error occurred: $e');
  } finally {
    client.close();
  }
}
