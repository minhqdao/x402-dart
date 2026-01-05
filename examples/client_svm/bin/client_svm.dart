import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:solana/solana.dart';
import 'package:x402/x402.dart';

// Constants
const _defaultHost = 'http://127.0.0.1:8081';
const _svmRpcUrl = 'https://api.devnet.solana.com';
const _svmWsUrl = 'wss://api.devnet.solana.com';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('host', abbr: 'h', defaultsTo: _defaultHost)
    ..addOption('seed', abbr: 's', help: 'SVM Wallet Seed (mnemonic)');

  final result = parser.parse(args);
  final host = result['host'] as String;
  final seed = result['seed'] as String?;

  // Initialize wallet
  final Ed25519HDKeyPair signer;
  if (seed != null) {
    signer = await Ed25519HDKeyPair.fromMnemonic(seed);
  } else {
    // Generate random wallet for demo
    signer = await Ed25519HDKeyPair.random();
  }

  stdout.writeln('Using address: ${signer.address}');

  final solanaClient = SolanaClient(rpcUrl: Uri.parse(_svmRpcUrl), websocketUrl: Uri.parse(_svmWsUrl));

  final client = http.Client();
  try {
    // 1. Request content
    stdout.writeln('Requesting premium content from $host...');
    final response = await client.get(Uri.parse('$host/premium-content'));

    if (response.statusCode == 200) {
      stdout.writeln('Success! Content: ${response.body}');
      return;
    }

    if (response.statusCode != 402) {
      stdout.writeln('Error: Unexpected status code ${response.statusCode}');
      stdout.writeln('Body: ${response.body}');
      return;
    }

    // 2. Handle 402 Payment Required
    stdout.writeln('Payment required. Parsing requirements...');
    final paymentResponse = PaymentRequiredResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);

    // Find SVM requirement
    final solReq = paymentResponse.accepts.firstWhere(
      (req) => req.scheme == 'exact' && req.network.startsWith('svm'),
      orElse: () => throw Exception('No supported SVM payment method found'),
    );

    stdout.writeln('Found SVM requirement for ${solReq.network}');
    stdout.writeln('Asset: ${solReq.asset}');
    stdout.writeln('Amount: ${solReq.amount}');

    // 3. Create payment payload
    final schemeClient = ExactSvmSchemeClient(signer: signer, solanaClient: solanaClient);
    final paymentPayload = await schemeClient.createPaymentPayload(solReq);

    // 4. Retry with authorization
    stdout.writeln('Generated payment payload. Retrying request...');
    final token = base64Encode(utf8.encode(jsonEncode(paymentPayload.toJson())));

    final authResponse = await client.get(Uri.parse('$host/premium-content'), headers: {'Authorization': '402 $token'});

    if (authResponse.statusCode == 200) {
      stdout.writeln('Success! Content: ${authResponse.body}');
    } else {
      stdout.writeln('Failed to authorize payment. Status: ${authResponse.statusCode}');
      stdout.writeln('Body: ${authResponse.body}');
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    client.close();
  }
}
