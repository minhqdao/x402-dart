import 'package:x402_core/src/models/payment_payload.dart';
import 'package:x402_core/src/models/payment_requirements.dart';

/// Interface for implementing payment schemes (client-side)
abstract class SchemeClient {
  /// The scheme identifier (e.g., "exact")
  String get scheme;

  /// Creates a payment payload for the given requirements
  Future<PaymentPayload> createPaymentPayload(X402Requirement requirements);
}

/// Interface for implementing payment schemes (server-side)
abstract class SchemeServer {
  /// The scheme identifier (e.g., "exact")
  String get scheme;

  /// Verifies a payment payload locally (optional, may delegate to facilitator)
  Future<bool> verifyPayload(PaymentPayload payload, X402Requirement requirements);
}
