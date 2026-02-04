import 'dart:io';

import 'package:x402_server/x402_server.dart';

void main() async {
  final verifier = PaymentVerifier([
    ExampleSchemeVerifier(),
  ]);

  final request = ExampleRequest();

  final result = await verifier.verify(
    paymentHeader: 'example-payment-header',
    request: request,
  );

  if (result.isValid) {
    stdout.writeln('✅ Payment verified');
  } else {
    stdout.writeln('❌ Payment rejected: ${result.reason}');
  }
}

/// Minimal example request implementation.
class ExampleRequest implements X402Request {
  @override
  HttpMethod get method => HttpMethod.get;

  @override
  Uri get uri => Uri.parse('https://api.example.com/premium');

  @override
  Map<String, String> get headers => {};
}

/// Minimal example payment scheme verifier.
class ExampleSchemeVerifier implements PaymentSchemeVerifier {
  @override
  bool supports(String paymentHeader) {
    return paymentHeader == 'example-payment-header';
  }

  @override
  Future<VerificationResult> verify({
    required String paymentHeader,
    required X402Request request,
  }) async {
    // In a real implementation, verification logic would go here.
    return const VerificationResult.valid();
  }
}
