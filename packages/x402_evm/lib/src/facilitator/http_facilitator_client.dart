import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:x402_core/x402_core.dart';

/// HTTP client for interacting with x402 facilitator servers
class HttpFacilitatorClient implements FacilitatorClient {
  @override
  final String baseUrl;
  final http.Client _httpClient;

  HttpFacilitatorClient({required this.baseUrl, http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  @override
  Future<VerificationResponse> verify({
    required int x402Version,
    required String paymentHeader,
    required PaymentRequirements paymentRequirements,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'x402Version': x402Version,
          'paymentHeader': paymentHeader,
          'paymentRequirements': paymentRequirements.toJson(),
        }),
      );

      if (response.statusCode != 200) {
        throw PaymentVerificationException(
          'Verification failed with status ${response.statusCode}',
          code: 'HTTP_ERROR',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return VerificationResponse.fromJson(json);
    } catch (e) {
      if (e is X402Exception) rethrow;
      throw PaymentVerificationException('Failed to verify payment: $e', originalError: e);
    }
  }

  @override
  Future<SettlementResponse> settle({
    required int x402Version,
    required String paymentHeader,
    required PaymentRequirements paymentRequirements,
  }) async {
    try {
      final response = await _httpClient.post(
        Uri.parse('$baseUrl/settle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'x402Version': x402Version,
          'paymentHeader': paymentHeader,
          'paymentRequirements': paymentRequirements.toJson(),
        }),
      );

      if (response.statusCode != 200) {
        throw PaymentSettlementException('Settlement failed with status ${response.statusCode}', code: 'HTTP_ERROR');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return SettlementResponse.fromJson(json);
    } catch (e) {
      if (e is X402Exception) rethrow;
      throw PaymentSettlementException('Failed to settle payment: $e', originalError: e);
    }
  }

  @override
  Future<List<SupportedKind>> getSupported() async {
    try {
      final response = await _httpClient.get(Uri.parse('$baseUrl/supported'));

      if (response.statusCode != 200) {
        throw X402Exception('Failed to get supported schemes with status ${response.statusCode}', code: 'HTTP_ERROR');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final kinds = json['kinds'] as List;

      return kinds.map((k) => SupportedKind.fromJson(k as Map<String, dynamic>)).toList();
    } catch (e) {
      if (e is X402Exception) rethrow;
      throw X402Exception('Failed to get supported schemes: $e', originalError: e);
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
