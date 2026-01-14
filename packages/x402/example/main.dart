import 'dart:io';

import 'package:x402/x402.dart';

void main() async {
  final evmSigner = EvmSigner.fromHex(
    chainId: 84532, // Base Sepolia
    privateKeyHex: 'YOUR_EVM_PRIVATE_KEY',
  );

  final svmSigner = await SvmSigner.fromHex(
    privateKeyHex: 'YOUR_SVM_PRIVATE_KEY',
    network: SolanaNetwork.devnet,
  );

  final client = X402Client(
    signers: [evmSigner, svmSigner],
    onPaymentRequired: (requirement, resource, signer) async {
      final paymentCondition = int.parse(requirement.amount) <= 5000000;
      if (paymentCondition) {
        stdout.writeln('✅ Payment Approved for ${resource.url}');
        return true;
      } else {
        stdout.writeln('❌ Payment Denied for ${resource.url}: Amount too high');
        return false;
      }
    },
  );

  try {
    final response = await client.get(Uri.parse('https://api.example.com/premium-content'));

    if (response.statusCode == 200) {
      stdout.writeln('✅ Success! Received premium content:');
      stdout.writeln(response.body);
      // 402 is handled internally by the X402Client
    } else {
      throw Exception('Request failed with status ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    stdout.writeln('❌ Error during request: $e');
  } finally {
    client.close();
  }
}
