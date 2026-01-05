import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/models/payment_payload.dart';
import 'package:x402_core/src/models/payment_required_response.dart';
import 'package:x402_core/src/models/payment_requirements.dart';

/// Callback to approve a payment requirement
typedef PaymentApprovalCallback = Future<bool> Function(
  PaymentRequirements requirement,
);

/// Interface for x402 signers
abstract class X402Signer {
  /// The CAIP-2 network identifier this signer supports (e.g., 'eip155:8453')
  String get networkId;

  /// The scheme this signer supports (e.g., 'exact')
  String get scheme;

  /// Signs the payload and returns the Base64 string for the header.
  Future<PaymentPayload> sign(PaymentRequirements requirement);
}

/// A client wrapper that automatically handles 402 Payment Required flows
class X402Client extends http.BaseClient {
  final http.Client _inner;
  final List<X402Signer> _signers;
  final PaymentApprovalCallback? onPaymentRequired;

  X402Client({
    http.Client? inner,
    required List<X402Signer> signers,
    this.onPaymentRequired,
  }) : _inner = inner ?? http.Client(),
       _signers = signers;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 1. Buffer the request for potential retry
    final bytes = await request.finalize().toBytes();

    // 2. Initial Request
    final response = await _inner.send(_recreateRequest(request, bytes));

    // 3. Handle 402 Flow
    if (response.statusCode == kPaymentRequiredStatus) {
      final header = response.headers[kPaymentRequiredHeader];
      if (header == null) return response;

      try {
        // 4. Scheme Negotiation
        final paymentResponse = PaymentRequiredResponse.fromJson(
          jsonDecode(utf8.decode(base64Decode(header))) as Map<String, dynamic>,
        );

        for (final req in paymentResponse.accepts) {
          // Find a matching signer
          final signer = _findSigner(req.network, req.scheme);
          if (signer == null) continue;

          // 5. User Approval Hook
          if (onPaymentRequired != null) {
            final approved = await onPaymentRequired!(req);
            if (!approved) continue;
          }

          // 6. Sign & Retry
          final payload = await signer.sign(req);
          final signature = base64Encode(utf8.encode(jsonEncode(payload.toJson())));
          
          final retryRequest = _recreateRequest(request, bytes);
          retryRequest.headers[kPaymentSignatureHeader] = signature;
          
          // Also add legacy header for compatibility
          retryRequest.headers[kPaymentHeader] = signature;

          return await _inner.send(retryRequest);
        }
      } catch (e) {
        stdout.writeln('Error handling 402 flow: $e');
        return response;
      }
    }

    return response;
  }

  X402Signer? _findSigner(String networkId, String scheme) {
    for (final signer in _signers) {
      if (signer.networkId == networkId && signer.scheme == scheme) {
        return signer;
      }
    }
    return null;
  }

  /// Recreates a request from buffered bytes so it can be sent multiple times.
  http.Request _recreateRequest(http.BaseRequest original, List<int> body) {
    final request = http.Request(original.method, original.url)
      ..headers.addAll(original.headers)
      ..bodyBytes = body;
    return request;
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
