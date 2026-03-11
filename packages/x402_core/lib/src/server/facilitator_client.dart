import 'package:x402_core/src/models/payment_payload.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/settle_response.dart';
import 'package:x402_core/src/models/supported_response.dart';
import 'package:x402_core/src/models/verify_response.dart';

/// Interface for facilitator clients.
///
/// Can be implemented for HTTP-based or local facilitators.
abstract interface class FacilitatorClient {
  /// Verify a payment with the facilitator.
  Future<VerifyResponse> verify(
    PaymentPayload paymentPayload,
    PaymentRequirement paymentRequirement,
  );

  /// Settle a payment with the facilitator.
  Future<SettleResponse> settle(
    PaymentPayload paymentPayload,
    PaymentRequirement paymentRequirement,
  );

  /// Get supported payment kinds and extensions.
  Future<SupportedResponse> getSupported();
}
