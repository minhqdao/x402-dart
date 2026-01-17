import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dotenv/dotenv.dart';
import 'package:x402/x402.dart';
import 'package:x402_dio/x402_dio.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load();

  final evmPrivateKey = env['EVM_PRIVATE_KEY'];
  if (evmPrivateKey == null) {
    stdout.writeln('Error: EVM_PRIVATE_KEY is not set in .env file.');
    return;
  }

  final svmPrivateKey = env['SVM_PRIVATE_KEY'];
  if (svmPrivateKey == null) {
    stdout.writeln('Error:SVM_PRIVATE_KEY is not set in .env file.');
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

  // 1. Create signers
  final evmSigner =
      EvmSigner.fromHex(chainId: 84532, privateKeyHex: evmPrivateKey);
  final svmSigner = await SvmSigner.fromHex(
      privateKeyHex: svmPrivateKey, network: SolanaNetwork.devnet);

  // 2. Setup Dio with the interceptor
  final dio = Dio();
  dio.interceptors.add(X402Interceptor(
    dio: dio,
    signers: [
      evmSigner, // This signer will be tried first
      svmSigner, // Move this signer to the top to try it first
    ],
    onPaymentRequired: (req, resource, signer) async {
      stdout.writeln('💰 Payment required: ${req.amount} for ${resource.url}');
      stdout.writeln('   Signer: ${signer.address} (${signer.network})');
      return true; // Auto-approve for this example
    },
  ));

  // 3. Make requests as normal
  try {
    final response = await dio.get('$host$endpointPath');
    stdout.writeln('✅ Success: ${response.data}');
  } on DioException catch (e) {
    stderr.writeln('❌ Error: ${e.message}');
    if (e.response != null) {
      stderr.writeln('   Status: ${e.response?.statusCode}');
      stderr.writeln('   Data: ${e.response?.data}');
    }
  }
}
