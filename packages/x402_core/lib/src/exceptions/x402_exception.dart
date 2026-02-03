class X402Exception implements Exception {
  final String message;
  final dynamic originalError;

  const X402Exception(this.message, {this.originalError});

  @override
  String toString() => 'X402Exception: $message';
}

/// Invalid payment payload
class InvalidPayloadException extends X402Exception {
  const InvalidPayloadException(super.message, {super.originalError});
}

/// Unsupported scheme or network
class UnsupportedSchemeException extends X402Exception {
  const UnsupportedSchemeException(super.message, {super.originalError});
}
