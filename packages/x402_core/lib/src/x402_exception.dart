class X402Exception implements Exception {
  final String message;
  final dynamic originalError;

  const X402Exception(this.message, {this.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'X402Exception: $message, originalError: $originalError';
    }
    return 'X402Exception: $message';
  }
}

/// Invalid payment payload
class InvalidPayloadException extends X402Exception {
  const InvalidPayloadException(super.message, {super.originalError});
}

/// Unsupported scheme or network
class UnsupportedSchemeException extends X402Exception {
  const UnsupportedSchemeException(super.message, {super.originalError});
}

/// Base facilitator error
class FacilitatorException extends X402Exception {
  const FacilitatorException(super.message, {super.originalError});
}

/// Facilitator endpoint error (HTTP non-2xx)
class FacilitatorResponseException extends FacilitatorException {
  final int statusCode;
  final Map<String, dynamic>? responseBody;

  const FacilitatorResponseException(
    super.message, {
    required this.statusCode,
    this.responseBody,
    super.originalError,
  });
}
