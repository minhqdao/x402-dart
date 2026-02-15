/// Normalizes a decimal string into a fixed-precision token amount string.
///
/// Example (decimals = 6):
///   "1" -> "1000000"
///   "1.23" -> "1230000"
///   "0.000001" -> "1"
///   "0001.23" -> "1230000"
///
/// Throws [ArgumentError] if:
/// - format is invalid
/// - fractional precision exceeds [decimals]
class TokenAmountNormalizer {
  const TokenAmountNormalizer._();

  static String normalize(
    String input, {
    required int decimals,
  }) {
    if (decimals < 0) {
      throw ArgumentError.value(
        decimals,
        'decimals',
        'Must be >= 0',
      );
    }

    final match = RegExp(r'^\d+(\.\d+)?$').firstMatch(input);
    if (match == null) {
      throw ArgumentError('Invalid decimal format: $input');
    }

    final parts = input.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';

    if (fractionalPart.length > decimals) {
      throw ArgumentError(
        'Too many decimal places. Max allowed: $decimals',
      );
    }

    final paddedFraction = fractionalPart.padRight(decimals, '0');

    final combined = integerPart + paddedFraction;

    return combined.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  }
}
