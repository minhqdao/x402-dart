import 'package:x402_core/src/models/payment_payload.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// Interface for payment scheme clients (e.g., "exact", "stream")
abstract class SchemeClient {
  /// The scheme identifier
  String get scheme;

  /// Creates a payment payload based on requirements and resource info.
  Future<PaymentPayload> createPaymentPayload(
    PaymentRequirement requirements,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  });
}
