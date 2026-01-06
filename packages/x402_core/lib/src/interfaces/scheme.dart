import 'package:x402_core/src/models/payment_payload.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// Interface for payment scheme clients (e.g., "exact", "stream")
abstract class SchemeClient {
  /// The scheme identifier
  String get scheme;

  /// Creates a payment payload for the given requirements
  Future<PaymentPayload> createPaymentPayload(PaymentRequirement requirements, ResourceInfo resource);
}

/// Interface for payment scheme servers
abstract class SchemeServer {
  /// The scheme identifier
  String get scheme;

  /// Verifies a payment payload against requirements
  Future<bool> verifyPayload(PaymentPayload payload, PaymentRequirement requirements);
}
