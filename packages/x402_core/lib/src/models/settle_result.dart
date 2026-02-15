import 'package:x402_core/src/models/settle_response.dart';

/// Result returned before a payment is settled.
///
/// This allows you to decide whether the settlement process
/// should continue or stop.
///
/// It can be used for:
/// - Custom validation
/// - Business rule enforcement
/// - Additional safety checks
sealed class BeforeSettleResult {
  const BeforeSettleResult();
}

/// Indicates that settlement should proceed normally.
///
/// Use this when all checks have passed and there is no
/// reason to stop the payment process.
final class ContinueSettle extends BeforeSettleResult {
  const ContinueSettle();
}

/// Indicates that settlement should be aborted.
///
/// This stops the payment process before it is finalized.
/// The [reason] should explain why the payment was rejected.
final class AbortSettle extends BeforeSettleResult {
  /// A human-readable explanation of why settlement was stopped.
  final String reason;
  const AbortSettle(this.reason);
}

/// Describes what should happen after a settlement failure.
///
/// When a payment fails during settlement, the server can either:
/// - Give up entirely
/// - Attempt to recover and return a valid settlement response
///
/// This type models those two possibilities.
sealed class SettleFailureResult {
  const SettleFailureResult();
}

/// Indicates that the failed settlement cannot be recovered.
///
/// No fallback or recovery logic is applied.
final class NoSettleRecovery extends SettleFailureResult {
  const NoSettleRecovery();
}

/// Indicates that the failed settlement was recovered.
///
/// The [result] contains a settlement response that should
/// be treated as successful from the caller's perspective.
final class RecoverSettle extends SettleFailureResult {
  /// The recovered settlement response.
  final SettleResponse result;
  const RecoverSettle(this.result);
}
