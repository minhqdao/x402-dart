/// The result of a payment verification attempt.
class VerificationResult {
  /// Whether the payment is valid.
  final bool isValid;

  /// Optional reason explaining why verification failed.
  ///
  /// This is `null` when [isValid] is true.
  final String? reason;

  /// Creates a successful verification result.
  const VerificationResult.valid()
      : isValid = true,
        reason = null;

  /// Creates a failed verification result with a reason.
  const VerificationResult.invalid(this.reason) : isValid = false;
}
