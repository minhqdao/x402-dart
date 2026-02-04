import 'package:x402_server/request/x402_request.dart';
import 'package:x402_server/schemes/payment_scheme_verifier.dart';
import 'package:x402_server/verifier/verification_result.dart';

/// Orchestrates payment verification across multiple payment schemes.
///
/// Schemes are evaluated in order, and the first scheme that reports
/// support for a payment header is used to verify the payment.
class PaymentVerifier {
  final List<PaymentSchemeVerifier> _schemes;

  /// Creates a [PaymentVerifier] with the given list of scheme verifiers.
  ///
  /// The order of [schemes] defines the preference order.
  PaymentVerifier(this._schemes);

  /// Verifies a payment using the first supporting scheme.
  ///
  /// Returns [VerificationResult.invalid] if no scheme supports
  /// the given payment header.
  Future<VerificationResult> verify({
    required String paymentHeader,
    required X402Request request,
  }) async {
    for (final scheme in _schemes) {
      if (scheme.supports(paymentHeader)) {
        return scheme.verify(
          paymentHeader: paymentHeader,
          request: request,
        );
      }
    }
    return const VerificationResult.invalid('No supported payment scheme');
  }
}
