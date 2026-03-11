import 'package:x402_core/src/models/verify_response.dart';

/// Result of a before-verify hook.
sealed class BeforeVerifyResult {
  const BeforeVerifyResult();
}

/// Continue verification.
final class ContinueVerify extends BeforeVerifyResult {
  const ContinueVerify();
}

/// Abort verification.
final class AbortVerify extends BeforeVerifyResult {
  final String reason;
  const AbortVerify(this.reason);
}

/// Result of a verify failure hook.
sealed class VerifyFailureResult {
  const VerifyFailureResult();
}

/// Do not recover.
final class NoVerifyRecovery extends VerifyFailureResult {
  const NoVerifyRecovery();
}

/// Recover and return this verification result.
final class RecoverVerify extends VerifyFailureResult {
  final VerifyResponse result;
  const RecoverVerify(this.result);
}
