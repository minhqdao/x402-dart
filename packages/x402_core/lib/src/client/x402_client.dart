import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/models/payment_requirements.dart';

/// Callback to let the user approve a payment before the 'magic' happens.
typedef PaymentApprovalCallback = Future<bool> Function(
  X402Requirement requirement,
);

/// The interface every blockchain-specific package must implement.
abstract class X402Signer {
  /// The CAIP-2 network identifier this signer supports (e.g., 'eip155:8453')
  String get networkId;

  /// The scheme this signer supports (e.g., 'exact')
  String get scheme;

  /// Signs the requirements and returns the Base64 signature string.
  Future<String> sign(X402Requirement requirement);
}

/// A high-level client that automatically handles 402 Payment Required flows
class X402Client extends http.BaseClient {
  final List<X402Signer> _signers;
  final http.Client _inner;
  final PaymentApprovalCallback? onPaymentRequired;

  X402Client({
    required List<X402Signer> signers,
    this.onPaymentRequired,
    http.Client? inner,
  }) : _signers = signers,
       _inner = inner ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // 1. Buffer the request bytes (so we can replay it for the retry)
    final bytes = await request.finalize().toBytes();

    // 2. Initial Request
    final response = await _inner.send(_recreate(request, bytes));

    // 3. Automated Handshake Loop
    if (response.statusCode == kPaymentRequiredStatus) {
      final header = response.headers[kPaymentRequiredHeader];
      if (header == null) return response;

      try {
        // 4. Parse the requirements (The 'accepts' array from server)
        final List<X402Requirement> requirements = _parseHeader(header);

        // 5. Negotiation: Iterate through YOUR signers (in order)
        for (final signer in _signers) {
          // Does this signer match ANY of the server's requirements?
          final match = requirements.firstWhereOrNull(
            (req) => req.network == signer.networkId && req.scheme == signer.scheme,
          );

          if (match != null) {
            // 6. Optional Consent Check (Safety first!)
            if (onPaymentRequired != null) {
              final approved = await onPaymentRequired!(match);
              if (!approved) return response; // Return the 402 if denied
            }

            // 7. Magic: Sign & Automatically Retry
            final signature = await signer.sign(match);
            final retryRequest = _recreate(request, bytes);

            // Attach the proof using both v2 standard and legacy headers
            retryRequest.headers[kPaymentSignatureHeader] = signature;
            retryRequest.headers[kPaymentHeader] = signature;

            return await _inner.send(retryRequest);
          }
        }
      } catch (e) {
        stdout.writeln('Error handling 402 magic flow: $e');
        // Return original response if magic fails
        return response;
      }
    }

    return response;
  }

  /// Helper to clone the request for retries
  http.Request _recreate(http.BaseRequest orig, List<int> body) {
    final req = http.Request(orig.method, orig.url)
      ..headers.addAll(orig.headers)
      ..bodyBytes = body;
    return req;
  }

  List<X402Requirement> _parseHeader(String headerBase64) {
    final json = jsonDecode(utf8.decode(base64Decode(headerBase64))) as Map<String, dynamic>;
    final list = json['accepts'] as List? ?? [];
    return list.map((m) => X402Requirement.fromJson(m as Map<String, dynamic>)).toList();
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
