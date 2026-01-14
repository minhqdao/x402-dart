class X402Exception implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const X402Exception(this.message, {this.code, this.originalError});

  @override
  String toString() {
    if (code != null) {
      return 'X402Exception [$code]: $message';
    }
    return 'X402Exception: $message';
  }
}

/// Invalid payment payload
class InvalidPayloadException extends X402Exception {
  const InvalidPayloadException(super.message, {super.code, super.originalError});
}

/// Unsupported scheme or network
class UnsupportedSchemeException extends X402Exception {
  const UnsupportedSchemeException(super.message, {super.code, super.originalError});
}
