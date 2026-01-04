import 'package:x402_core/src/models/payment_requirements.dart';
import 'package:x402_core/src/models/settlement_response.dart';
import 'package:x402_core/src/models/verification_response.dart';

/// Interface for interacting with a facilitator server
abstract class FacilitatorClient {
  /// Base URL of the facilitator
  String get baseUrl;

  /// Verify a payment payload
  Future<VerificationResponse> verify({
    required int x402Version,
    required String paymentHeader,
    required PaymentRequirements paymentRequirements,
  });

  /// Settle a payment
  Future<SettlementResponse> settle({
    required int x402Version,
    required String paymentHeader,
    required PaymentRequirements paymentRequirements,
  });

  /// Get supported schemes and networks
  Future<List<SupportedKind>> getSupported();
}

/// Represents a supported (scheme, network) pair
class SupportedKind {
  final String scheme;
  final String network;

  const SupportedKind({required this.scheme, required this.network});

  factory SupportedKind.fromJson(Map<String, dynamic> json) {
    return SupportedKind(scheme: json['scheme'] as String, network: json['network'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'scheme': scheme, 'network': network};
  }
}
