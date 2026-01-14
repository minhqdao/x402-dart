import 'dart:io';

import 'package:x402_core/x402_core.dart';

void main() async {
  final client = X402Client(
    signers: [
      // Signers would be added here in a real app
      // Example: EvmSigner, SvmSigner from the x402 package
    ],
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
    final response =
        await client.get(Uri.parse('https://api.example.com/premium-content'));

    if (response.statusCode == 200) {
      stdout.writeln('✅ Success! Received premium content:');
      stdout.writeln(response.body);
      // 402 is handled internally by X402Client
    } else {
      throw Exception(
          'Request failed with status ${response.statusCode}: ${response.body}');
    }
  } catch (e) {
    stdout.writeln('❌ Error during request: $e');
  } finally {
    client.close();
  }
}
