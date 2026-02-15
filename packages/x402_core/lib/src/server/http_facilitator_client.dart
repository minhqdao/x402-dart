import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/models/payment_payload.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/settle_response.dart';
import 'package:x402_core/src/models/supported_response.dart';
import 'package:x402_core/src/models/verify_response.dart';
import 'package:x402_core/src/server/facilitator_client.dart';
import 'package:x402_core/src/x402_exception.dart';

typedef AuthHeaderFactory = Future<Map<String, Map<String, String>>> Function();

class HttpFacilitatorClient implements FacilitatorClient {
  final String _url;
  final AuthHeaderFactory? _createAuthHeaders;
  final http.Client _httpClient;

  HttpFacilitatorClient({
    String? url,
    AuthHeaderFactory? createAuthHeaders,
    http.Client? httpClient,
  })  : _url = url ?? kDefaultFacilitatorUrl,
        _createAuthHeaders = createAuthHeaders,
        _httpClient = httpClient ?? http.Client();

  @override
  Future<VerifyResponse> verify(
    PaymentPayload paymentPayload,
    PaymentRequirement paymentRequirement,
  ) async {
    final headers = await _buildHeaders('verify');
    late final http.Response response;

    try {
      response = await _httpClient.post(
        Uri.parse('$_url/verify'),
        headers: headers,
        body: jsonEncode({
          'x402Version': paymentPayload.x402Version,
          'paymentPayload': _toJsonSafe(paymentPayload.toJson()),
          'paymentRequirements': _toJsonSafe(paymentRequirement.toJson()),
        }),
      );
    } catch (e) {
      throw FacilitatorException(
        'Network error during verify request',
        originalError: e,
      );
    }

    final data = await _decodeJson(response);

    if (data is Map<String, dynamic> && data.containsKey('isValid')) {
      final parsed = VerifyResponse.fromJson(data);

      if (response.statusCode != 200) {
        throw FacilitatorResponseException(
          'Facilitator verify failed',
          statusCode: response.statusCode,
          responseBody: data,
        );
      }

      return parsed;
    }

    throw FacilitatorResponseException(
      'Invalid verify response structure',
      statusCode: response.statusCode,
      responseBody: data is Map<String, dynamic> ? data : null,
    );
  }

  @override
  Future<SettleResponse> settle(
    PaymentPayload paymentPayload,
    PaymentRequirement paymentRequirement,
  ) async {
    final headers = await _buildHeaders('settle');
    late final http.Response response;

    try {
      response = await _httpClient.post(
        Uri.parse('$_url/settle'),
        headers: headers,
        body: jsonEncode({
          'x402Version': paymentPayload.x402Version,
          'paymentPayload': _toJsonSafe(paymentPayload.toJson()),
          'paymentRequirements': _toJsonSafe(paymentRequirement.toJson()),
        }),
      );
    } catch (e) {
      throw FacilitatorException(
        'Network error during settle request',
        originalError: e,
      );
    }

    final data = await _decodeJson(response);

    if (data is Map<String, dynamic> && data.containsKey('success')) {
      final parsed = SettleResponse.fromJson(data);

      if (response.statusCode != 200) {
        throw FacilitatorResponseException(
          'Facilitator settle failed',
          statusCode: response.statusCode,
          responseBody: data,
        );
      }

      return parsed;
    }

    throw FacilitatorResponseException(
      'Invalid settle response structure',
      statusCode: response.statusCode,
      responseBody: data is Map<String, dynamic> ? data : null,
    );
  }

  @override
  Future<SupportedResponse> getSupported() async {
    final headers = await _buildHeaders('supported');
    late final http.Response response;

    try {
      response = await _httpClient.get(
        Uri.parse('$_url/supported'),
        headers: headers,
      );
    } catch (e) {
      throw FacilitatorException(
        'Network error during getSupported request',
        originalError: e,
      );
    }

    if (response.statusCode != 200) {
      throw FacilitatorResponseException(
        'Facilitator getSupported failed',
        statusCode: response.statusCode,
        responseBody: await _decodeJson(response) as Map<String, dynamic>?,
      );
    }

    final data = await _decodeJson(response);

    if (data is Map<String, dynamic>) {
      return SupportedResponse.fromJson(data);
    }

    throw FacilitatorResponseException(
      'Invalid supported response structure',
      statusCode: response.statusCode,
      responseBody: await _decodeJson(response) as Map<String, dynamic>?,
    );
  }

  Future<Map<String, String>> _buildHeaders(String path) async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_createAuthHeaders != null) {
      late final Map<String, Map<String, String>> authHeaders;

      try {
        authHeaders = await _createAuthHeaders();
      } catch (e) {
        throw FacilitatorException(
          'Error creating auth headers',
          originalError: e,
        );
      }

      headers.addAll(authHeaders[path] ?? {});
    }

    return headers;
  }

  Future<dynamic> _decodeJson(http.Response response) async {
    try {
      return jsonDecode(response.body);
    } catch (e) {
      throw FacilitatorException(
        'Failed to decode JSON response',
        originalError: e,
      );
    }
  }

  dynamic _toJsonSafe(dynamic obj) {
    return jsonDecode(
      jsonEncode(
        obj,
        toEncodable: (value) => value is BigInt ? value.toString() : value,
      ),
    );
  }

  void dispose() => _httpClient.close();
}
