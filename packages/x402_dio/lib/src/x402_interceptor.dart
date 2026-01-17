import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:x402_core/x402_core.dart';

/// A Dio interceptor that automatically handles 402 Payment Required responses.
///
/// When a server responds with 402, this interceptor:
/// 1. Parses the payment requirements from the response headers
/// 2. Finds a compatible signer from the provided list (in order of preference)
/// 3. Optionally requests user approval via [onPaymentRequired]
/// 4. Signs the payment and automatically retries the request with payment proof
///
/// ## Example
///
/// ```dart
/// import 'package:x402/x402.dart';  // For EvmSigner, SvmSigner
/// import 'package:x402_dio/x402_dio.dart';
///
/// // Create signers for your supported networks
/// final evmSigner = EvmSigner.fromHex(
///   chainId: 8453,  // Base
///   privateKeyHex: 'your_private_key_hex',
/// );
///
/// // Add the interceptor to your Dio instance
/// final dio = Dio();
/// dio.interceptors.add(X402Interceptor(
///   dio: dio,
///   signers: [evmSigner],  // Add your signers here in order of preference
///   onPaymentRequired: (req, resource, signer) async {
///     print('Payment of ${req.amount} required for ${resource.url}');
///     return true; // or show UI dialog and return user's choice
///   },
/// ));
///
/// // Requests that receive 402 are automatically handled
/// final response = await dio.get('https://api.example.com/premium');
/// ```
///
/// See also:
/// - [EvmSigner] from `package:x402` for Ethereum/EVM chains
/// - [SvmSigner] from `package:x402` for Solana/SVM chains
class X402Interceptor extends Interceptor {
  final List<X402Signer> _signers;
  final Dio _dio;

  /// Callback invoked when a 402 Payment Required response is received.
  ///
  /// This allows the application to request user approval before a payment
  /// is signed and sent.
  ///
  /// Parameters:
  /// - [PaymentRequirement]: The matched payment requirement from the server
  /// - [ResourceInfo]: Information about the resource being accessed
  /// - [X402Signer]: The signer that will be used for the payment
  ///
  /// Returns `true` to approve and process the payment, or `false` to abort.
  ///
  /// If this callback is `null`, payments are automatically approved using
  /// the first compatible signer.
  final PaymentApprovalCallback? onPaymentRequired;

  /// Creates an [X402Interceptor] that automatically handles 402 Payment Required responses.
  ///
  /// The [dio] parameter must be the same Dio instance this interceptor is added to.
  /// This is required to retry requests after payment.
  ///
  /// The [signers] list provides available payment methods. They are checked
  /// in order, so place preferred payment methods first (e.g., put cheaper
  /// networks before expensive ones).
  ///
  /// The [onPaymentRequired] callback is optional. If provided, it will be
  /// invoked before each payment to allow user approval. If omitted, payments
  /// are automatically approved.
  ///
  /// Throws [ArgumentError] if [signers] is empty.
  ///
  /// Example:
  /// ```dart
  /// final dio = Dio();
  /// dio.interceptors.add(X402Interceptor(
  ///   dio: dio,
  ///   signers: [evmSigner, svmSigner], // EVM checked first
  ///   onPaymentRequired: (req, resource, signer) async {
  ///     if (int.parse(req.amount) > 1000000) {
  ///       return false; // Deny expensive payments
  ///     }
  ///     return true;
  ///   },
  /// ));
  /// ```
  X402Interceptor({
    required Dio dio,
    required List<X402Signer> signers,
    this.onPaymentRequired,
  })  : _dio = dio,
        _signers = signers {
    if (signers.isEmpty) {
      throw ArgumentError('At least one signer must be provided');
    }
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    // Only handle 402 errors
    if (response?.statusCode != kPaymentRequiredStatus) {
      return handler.next(err);
    }

    // Check if we already tried to pay to prevent infinite loops.
    // Use the header key that we add during signing.
    final existingSignature =
        err.requestOptions.headers[kPaymentSignatureHeader];
    // print('DEBUG: Headers keys: ${err.requestOptions.headers.keys.toList()}');
    // print('DEBUG: Checking for $kPaymentSignatureHeader. Found: $existingSignature');

    if (existingSignature != null) {
      // We already signed this request, but it still failed with 402.
      // This likely means the signature was invalid or the payment failed.
      // Pass the error through.
      return handler.next(err);
    }

    final header = response?.headers.value(kPaymentRequiredHeader);
    if (header == null) return handler.next(err);

    try {
      final paymentRequired = _parseHeader(header);
      final requirements = paymentRequired.accepts;

      if (requirements.isEmpty) return handler.next(err);

      // Find compatible signer
      for (final signer in _signers) {
        PaymentRequirement? match;
        for (final req in requirements) {
          if (signer.supports(req)) {
            match = req;
            break;
          }
        }

        if (match != null) {
          // Optional Consent Check
          if (onPaymentRequired != null) {
            final approved = await onPaymentRequired!(
                match, paymentRequired.resource, signer);
            if (!approved) return handler.next(err);
          }

          final signature = await signer.sign(
            match,
            paymentRequired.resource,
            extensions: paymentRequired.extensions,
          );

          // Retry Request
          final opts = Options(
            method: err.requestOptions.method,
            headers: Map.of(err.requestOptions.headers)
              ..addAll({
                kPaymentSignatureHeader: signature,
                kPaymentHeader: signature,
              }),
            responseType: err.requestOptions.responseType,
            contentType: err.requestOptions.contentType,
            validateStatus: err.requestOptions.validateStatus,
            receiveTimeout: err.requestOptions.receiveTimeout,
            sendTimeout: err.requestOptions.sendTimeout,
            extra: err.requestOptions.extra,
            followRedirects: err.requestOptions.followRedirects,
            maxRedirects: err.requestOptions.maxRedirects,
            requestEncoder: err.requestOptions.requestEncoder,
            responseDecoder: err.requestOptions.responseDecoder,
            listFormat: err.requestOptions.listFormat,
          );

          final response = await _dio.request(
            err.requestOptions.path,
            data: err.requestOptions.data,
            queryParameters: err.requestOptions.queryParameters,
            cancelToken: err.requestOptions.cancelToken,
            options: opts,
            onSendProgress: err.requestOptions.onSendProgress,
            onReceiveProgress: err.requestOptions.onReceiveProgress,
          );

          return handler.resolve(response);
        }
      }
    } catch (e) {
      // If anything fails during negotiation/signing, pass the original error
    }

    return handler.next(err);
  }

  /// Parses the X-Payment-Required header value.
  PaymentRequiredResponse _parseHeader(String headerBase64) {
    final json = jsonDecode(utf8.decode(base64Decode(headerBase64)))
        as Map<String, dynamic>;
    return PaymentRequiredResponse.fromJson(json);
  }
}
