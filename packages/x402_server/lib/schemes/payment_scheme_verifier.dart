import 'package:x402_server/request/x402_request.dart';
import 'package:x402_server/verifier/verification_result.dart';

/// Interface for verifying payments for a specific x402 payment scheme.
///
/// Implementations are responsible for:
/// - Determining whether they support a given payment header
/// - Verifying the payment according to the scheme's rules
abstract class PaymentSchemeVerifier {
  /// Returns true if this verifier can handle the given payment header.
  bool supports(String paymentHeader);

  /// Verifies the payment for the given request.
  ///
  /// Implementations should return a [VerificationResult] indicating
  /// whether the payment is valid.
  Future<VerificationResult> verify({
    required String paymentHeader,
    required X402Request request,
  });
}
