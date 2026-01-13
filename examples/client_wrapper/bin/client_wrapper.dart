import 'dart:io';
import 'package:dotenv/dotenv.dart';
import 'package:x402/x402.dart';

void main(List<String> args) async {
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

  final evmSigner = EvmSigner.fromHex(chainId: 84532, privateKeyHex: evmPrivateKey);
  final svmSigner = await SvmSigner.fromHex(privateKeyHex: svmPrivateKey, network: SolanaNetwork.devnet);

  final client = X402Client(
    signers: [
      evmSigner,
      svmSigner, // Move this to the top to prefer SVM over EVM
    ],
    onPaymentRequired: (req, resource, signer) async {
      if (int.parse(req.amount) > 10000000) {
        stdout.writeln('--- Payment Denied: Amount too high ---');
        return false;
      }

      stdout.writeln('--- Payment Approved ---');
      stdout.writeln('Paying for ${resource.url}...');
      stdout.writeln('Payment on ${signer.network} from ${signer.address}');
      return true;
    },
  );

  try {
    stdout.writeln('Requesting premium content...');
    final response = await client.get(Uri.parse('$host$endpointPath'));

    if (response.statusCode == 200) {
      stdout.writeln('--- Success! ---');
      stdout.writeln('Data received: ${response.body}');
      // 402 case handled in the callback function
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
