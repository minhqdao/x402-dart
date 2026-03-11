import 'dart:convert';

/// A [SignedPayment] represents the final result of the signing process.
///
/// The [encoded] field contains a Base64-encoded, UTF-8 JSON document
/// that includes the payment data, associated metadata, and the
/// cryptographic signature.
///
/// This object provides a convenience method to decode the payload back
/// into its JSON representation. It does **not** perform any validation
/// or signature verification.
class SignedPayment {
  /// Base64-encoded UTF-8 JSON payload.
  final String encoded;

  /// Creates a [SignedPayment] from a base64-encoded string.
  const SignedPayment(this.encoded);

  /// Decodes the base64 payload into a JSON map.
  ///
  /// Throws a [FormatException] if the payload is not valid base64
  /// or does not contain valid UTF-8 JSON.
  Map<String, dynamic> decode() =>
      jsonDecode(utf8.decode(base64Decode(encoded))) as Map<String, dynamic>;

  @override
  String toString() => encoded;
}
