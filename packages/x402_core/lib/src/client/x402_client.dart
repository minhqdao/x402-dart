import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;
import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/models/payment_required_response.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// Callback to let the user approve a payment before it's signed and sent.
///
/// Returns `true` to approve the payment, `false` to deny.
typedef PaymentApprovalCallback = Future<bool> Function(
  PaymentRequirement requirement,
  ResourceInfo resource,
  X402Signer signer,
);

/// The interface every blockchain-specific package must implement to support
/// signing x402 payment requirements.
abstract class X402Signer {
  /// The CAIP-2 network identifier this signer supports (e.g., 'eip155:8453').
  String get network;

  /// The scheme this signer supports (e.g., 'exact').
  String get scheme;

  /// The public address or identifier this signer uses.
  String get address;

  /// Checks if this signer supports the given [requirement] based on its
  /// [network] and [scheme].
  bool supports(PaymentRequirement requirement) =>
      requirement.network == network && requirement.scheme == scheme;

  /// Signs the [requirement] and returns a Base64-encoded JSON string
  /// representing the [PaymentPayload].
  ///
  /// [resource] provides context about what is being paid for.
  /// [extensions] allow for arbitrary extra data to be included in the signature.
  Future<String> sign(
    PaymentRequirement requirement,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  });
}

/// A high-level HTTP client that automatically handles 402 Payment Required flows.
///
/// When a server responds with 402, this client:
/// 1. Parses the payment requirements
/// 2. Finds a compatible signer (in order of preference)
/// 3. Optionally asks for user approval via [onPaymentRequired]
/// 4. Signs and automatically retries the request
///
/// Example:
/// ```dart
/// final client = X402Client(
///   signers: [evmSigner, svmSigner],
///   onPaymentRequired: (req, resource, signer) async {
///     print('Pay ${req.amount} using ${signer.network}?');
///     return true; // or show UI and wait for user input
///   },
/// );
///
/// final response = await client.get(Uri.parse('https://api.example.com/premium'));
/// ```
class X402Client extends http.BaseClient {
  final List<X402Signer> _signers;
  final http.Client _inner;

  /// Callback invoked when a 402 Payment Required response is received.
  ///
  /// This allows the application to ask for user approval before a payment
  /// is signed and sent.
  ///
  /// If this callback returns `false`, the payment is aborted and the original
  /// 402 response is returned.
  ///
  /// If this callback is `null`, the client will automatically approve and
  /// process the payment using the first compatible signer found in [_signers].
  final PaymentApprovalCallback? onPaymentRequired;

  /// Creates an [X402Client] that automatically handles 402 Payment Required flows.
  ///
  /// The [signers] list provides the available payment methods. They are checked
  /// in the provided order; the first signer that supports a server's
  /// requirement will be used.
  ///
  /// The [onPaymentRequired] callback is called before any payment is made.
  /// You can use it to show a confirmation UI to the user. If omitted (or set to `null`),
  /// the client will proceed with payments automatically without user intervention.
  ///
  /// The [inner] parameter allows providing a custom [http.Client]. If omitted,
  /// a default [http.Client] is used.
  X402Client({
    required List<X402Signer> signers,
    this.onPaymentRequired,
    http.Client? inner,
  })  : _signers = signers,
        _inner = inner ?? http.Client() {
    if (signers.isEmpty) {
      throw ArgumentError('At least one signer must be provided');
    }
  }

  /// Sends an HTTP request and automatically handles any 402 Payment Required
  /// responses by attempting to negotiate a payment and retrying the request.
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
        final paymentRequired = _parseHeader(header);
        final requirements = paymentRequired.accepts;

        if (requirements.isEmpty) return response;

        // 5. Negotiation: Iterate through YOUR signers (client preference order)
        for (final signer in _signers) {
          // Does this signer match ANY of the server's requirements?
          final match = requirements.firstWhereOrNull(signer.supports);

          if (match != null) {
            // 6. Optional Consent Check
            if (onPaymentRequired != null) {
              final approved = await onPaymentRequired!(
                  match, paymentRequired.resource, signer);
              if (!approved) {
                await response.stream.drain();
                return response;
              }
            }

            // 7. Sign & Automatically Retry
            final signature = await signer.sign(
              match,
              paymentRequired.resource,
              extensions: paymentRequired.extensions,
            );

            final retryRequest = _recreate(request, bytes);

            // Attach the proof using both v2 standard and legacy headers
            retryRequest.headers[kPaymentSignatureHeader] = signature;
            retryRequest.headers[kPaymentHeader] = signature;

            // Consume the original 402 response stream
            await response.stream.drain();

            // Make the payment request
            return await _inner.send(retryRequest);
          }
        }
      } catch (e) {
        // Silently fail and return original response
        // Users can add their own error handling in onPaymentRequired
      }

      // Consume stream before returning
      await response.stream.drain();
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

  /// Parse the X-Payment-Required header
  PaymentRequiredResponse _parseHeader(String headerBase64) {
    final json = jsonDecode(utf8.decode(base64Decode(headerBase64)))
        as Map<String, dynamic>;
    return PaymentRequiredResponse.fromJson(json);
  }

  /// Closes the client and cleans up any resources used by the underlying
  /// HTTP client.
  @override
  void close() {
    _inner.close();
    super.close();
  }
}
