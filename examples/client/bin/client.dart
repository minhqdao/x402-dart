// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:math';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
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

  // Initialize wallet
  final EthPrivateKey privateKey;
  if (privateKeyHex != null) {
    privateKey = EthPrivateKey.fromHex(privateKeyHex);
  } else {
    // Generate random key for demo
    final rng = Random.secure();
    privateKey = EthPrivateKey.createRandom(rng);
  }

  print('Using address: ${privateKey.address.hex}');

  final client = http.Client();
  try {
    // 1. Request content
    print('Requesting premium content...');
    final response = await client.get(Uri.parse('$host/premium-content'));

    if (response.statusCode == 200) {
      print('Success! Content: ${response.body}');
      return;
    }

    if (response.statusCode != 402) {
      print('Error: Unexpected status code ${response.statusCode}');
      print('Body: ${response.body}');
      return;
    }

    // 2. Handle 402 Payment Required
    print('Payment required. Parsing requirements...');
    final paymentResponse = PaymentRequiredResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    // Find EVM requirement
    final evmReq = paymentResponse.accepts.firstWhere(
      (req) => req.scheme == 'exact' && req.network.startsWith('eip155'),
      orElse: () => throw Exception('No supported EVM payment method found'),
    );

    print('Found EVM requirement for ${evmReq.network}');
    print('Asset: ${evmReq.asset}');
    print('Amount: ${evmReq.maxAmountRequired}');

    // 3. Create payment payload
    final schemeClient = ExactEvmSchemeClient(privateKey: privateKey);
    final paymentPayload = await schemeClient.createPaymentPayload(evmReq);

    // 4. Retry with authorization
    print('Generated payment payload. Retrying request...');
    final token = base64Encode(
      utf8.encode(jsonEncode(paymentPayload.toJson())),
    );

    final authResponse = await client.get(
      Uri.parse('$host/premium-content'),
      headers: {'Authorization': '402 $token'},
    );

    if (authResponse.statusCode == 200) {
      print('Success! Content: ${authResponse.body}');
    } else {
      print('Failed to authorize payment. Status: ${authResponse.statusCode}');
      print('Body: ${authResponse.body}');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
