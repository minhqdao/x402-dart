import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/models/payment_required_response.dart';
import 'package:x402_core/src/models/payment_requirements.dart';

/// Sealed class representing the result of an x402 request
sealed class X402Result {}

/// The "Success" or "Normal" case (any status code that isn't 402)
class X402StandardResponse extends X402Result {
  final http.Response response;
  X402StandardResponse(this.response);
}

/// The "Payment Required" case
class X402PaymentRequired extends X402Result {
  final List<X402Requirement> requirements;
  X402PaymentRequired(this.requirements);
}

/// The interface every blockchain-specific package must implement.
abstract class X402Signer {
  /// The CAIP-2 network identifier this signer supports (e.g., 'eip155:8453')
  String get networkId;

  /// The scheme this signer supports (e.g., 'exact')
  String get scheme;

  /// Signs the payload and returns the Base64 string for the header.
  Future<String> sign(X402Requirement requirement);
}

/// A high-level client that returns type-safe results for branching logic
class X402Client {
  final http.Client _inner;

  X402Client({http.Client? inner}) : _inner = inner ?? http.Client();

  /// Perform a GET request and return an X402Result
  Future<X402Result> get(
    Uri url, {
    Map<String, String>? headers,
    String? signature,
  }) {
    final request = http.Request('GET', url);
    if (headers != null) request.headers.addAll(headers);
    if (signature != null) {
      request.headers[kPaymentSignatureHeader] = signature;
      request.headers[kPaymentHeader] = signature;
    }
    return send(request);
  }

  /// Perform a POST request and return an X402Result
  Future<X402Result> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    String? signature,
  }) {
    final request = http.Request('POST', url);
    if (headers != null) request.headers.addAll(headers);
    if (encoding != null) request.encoding = encoding;
    if (body != null) {
      if (body is String) {
        request.body = body;
      } else if (body is List<int>) {
        request.bodyBytes = body;
      } else if (body is Map<String, String>) {
        request.bodyFields = body;
      } else {
        throw ArgumentError('Invalid body type ${body.runtimeType}');
      }
    }
    if (signature != null) {
      request.headers[kPaymentSignatureHeader] = signature;
      request.headers[kPaymentHeader] = signature;
    }
    return send(request);
  }

  /// Send a custom request and return an X402Result
  Future<X402Result> send(http.BaseRequest request) async {
    final streamedResponse = await _inner.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == kPaymentRequiredStatus) {
      final header = response.headers[kPaymentRequiredHeader];
      if (header != null) {
        try {
          final decoded = jsonDecode(utf8.decode(base64Decode(header)));
          final paymentResponse = PaymentRequiredResponse.fromJson(
            decoded as Map<String, dynamic>,
          );
          return X402PaymentRequired(paymentResponse.accepts);
        } catch (_) {
          // Fallback to standard response if parsing fails
        }
      }
    }

    return X402StandardResponse(response);
  }

  void close() {
    _inner.close();
  }
}
