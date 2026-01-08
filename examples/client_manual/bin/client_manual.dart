import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:x402/x402.dart';

void main(List<String> args) async {
  // Load environment variables
  final env = DotEnv(includePlatformEnvironment: true)..load();

  final evmPrivateKey = env['EVM_PRIVATE_KEY'];
  if (evmPrivateKey == null) {
    stdout.writeln('Error: EVM_PRIVATE_KEY is not set in .env file.');
    return;
  }

  final host = env['RESOURCE_SERVER_URL'];
  if (host == null || host.isEmpty) {
    stdout.writeln('Error: RESOURCE_SERVER_URL is not set in .env file.');
    return;
  }

  final endpointPath = env['ENDPOINT_PATH'];
  if (endpointPath == null || endpointPath.isEmpty) {
    stdout.writeln('Error: ENDPOINT_PATH is not set in .env file.');
    return;
  }

  final client = http.Client();

  try {
    // 1. Initial HTTP Request
    stdout.writeln('Making initial request to $host$endpointPath...');
    http.Response initialResponse;
    try {
      initialResponse = await client.get(Uri.parse('$host$endpointPath'));
    } on http.ClientException catch (e) {
      stdout.writeln('--- Error: Connection Failed ---');
      stdout.writeln('Could not connect to $host.');
      stdout.writeln('Please set up or connect to a facilitator and a server');
      stdout.writeln('Details: $e');
      return;
    }

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
    stdout.writeln('Payment data mapped from header.');

    // 3. Negotiate Requirements and Sign
    X402Signer? chosenSigner;
    PaymentRequirement? chosenRequirement;
    String? signature;

    // Initialize EVM signer
    final evmSigner = EvmSigner.fromHex(chainId: 84532, privateKeyHex: privateKeyHex);
    stdout.writeln('EVM Address: ${evmSigner.privateKey.address.hex}');

    // Try EVM first
    final evmReq = paymentResponse.accepts.firstWhereOrNull(
      (req) => req.network == evmSigner.network && req.scheme == evmSigner.scheme,
    );
    if (evmReq != null) {
      stdout.writeln('Negotiated EVM payment via ${evmReq.network} (amount: ${evmReq.amount})');
      chosenSigner = evmSigner;
      chosenRequirement = evmReq;
    } else {
      // Initialize SVM signer
      final svmSigner = await SvmSigner.createRandom(network: SolanaNetwork.devnet);
      stdout.writeln('SVM Address: ${svmSigner.signer.address}');

      // Try SVM
      final svmReq = paymentResponse.accepts.firstWhereOrNull(
        (req) => req.network == svmSigner.network && req.scheme == svmSigner.scheme,
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
    signature = await chosenSigner.sign(
      chosenRequirement,
      paymentResponse.resource,
      extensions: paymentResponse.extensions,
    );

    // 4. Retry Request with Signature
    stdout.writeln('Retrying request with signature...');
    final retryResponse = await client.get(
      Uri.parse('$host$endpointPath'),
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
