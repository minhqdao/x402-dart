import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('TokenAmountNormalizer – DECIMALS = 6', () {
    const decimals = 6;

    test('integer converts correctly', () {
      final result = TokenAmountNormalizer.normalize('1', decimals: decimals);
      expect(result, equals('1000000'));
    });

    test('decimal converts correctly', () {
      final result =
          TokenAmountNormalizer.normalize('1.23', decimals: decimals);
      expect(result, equals('1230000'));
    });

    test('exact precision boundary', () {
      final result =
          TokenAmountNormalizer.normalize('0.000001', decimals: decimals);
      expect(result, equals('1'));
    });

    test('too many decimal places throws', () {
      expect(
        () => TokenAmountNormalizer.normalize(
          '0.0000001',
          decimals: decimals,
        ),
        throwsArgumentError,
      );
    });

    test('leading zeros removed', () {
      final result =
          TokenAmountNormalizer.normalize('0001.23', decimals: decimals);
      expect(result, equals('1230000'));
    });

    test('all zeros stays zero', () {
      final result =
          TokenAmountNormalizer.normalize('0000.000000', decimals: decimals);
      expect(result, equals('0'));
    });

    test('zero stays zero', () {
      final result = TokenAmountNormalizer.normalize('0', decimals: decimals);
      expect(result, equals('0'));
    });

    test('very large integer', () {
      final result = TokenAmountNormalizer.normalize(
        '123456789012345678901234567890',
        decimals: decimals,
      );

      expect(
        result,
        equals('123456789012345678901234567890000000'),
      );
    });

    test('very large integer with fraction', () {
      final result = TokenAmountNormalizer.normalize(
        '12345678901234567890.123456',
        decimals: decimals,
      );

      expect(
        result,
        equals('12345678901234567890123456'),
      );
    });
  });

  group('TokenAmountNormalizer – DECIMALS = 0', () {
    const decimals = 0;

    test('integer works', () {
      final result = TokenAmountNormalizer.normalize('123', decimals: decimals);
      expect(result, equals('123'));
    });

    test('decimal with non-zero fractional throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('1.1', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('decimal with zero fractional throws (strict policy)', () {
      expect(
        () => TokenAmountNormalizer.normalize('1.0', decimals: decimals),
        throwsArgumentError,
      );
    });
  });

  group('TokenAmountNormalizer – DECIMALS = 18 (EVM-style)', () {
    const decimals = 18;

    test('1 ETH converts correctly', () {
      final result = TokenAmountNormalizer.normalize('1', decimals: decimals);

      expect(
        result,
        equals('1000000000000000000'),
      );
    });

    test('exact 18 decimal precision', () {
      final result = TokenAmountNormalizer.normalize(
        '0.000000000000000001',
        decimals: decimals,
      );

      expect(result, equals('1'));
    });

    test('too many decimals throws', () {
      expect(
        () => TokenAmountNormalizer.normalize(
          '0.0000000000000000001',
          decimals: decimals,
        ),
        throwsArgumentError,
      );
    });
  });

  group('TokenAmountNormalizer – DECIMALS = 50', () {
    const decimals = 50;

    test('very large decimals configuration works', () {
      final result = TokenAmountNormalizer.normalize(
        '1',
        decimals: decimals,
      );

      expect(result, equals('1${'0' * 50}'));
    });
  });

  group('INVALID FORMAT TESTS', () {
    const decimals = 6;

    test('negative number throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('-1', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('negative decimal throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('-1.23', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('empty string throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('whitespace throws', () {
      expect(
        () => TokenAmountNormalizer.normalize(' 1', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('trailing decimal point throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('1.', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('leading decimal point throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('.1', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('only decimal point throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('.', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('multiple decimal points throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('1.2.3', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('alphabetic input throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('abc', decimals: decimals),
        throwsArgumentError,
      );
    });

    test('mixed alphanumeric throws', () {
      expect(
        () => TokenAmountNormalizer.normalize('1a', decimals: decimals),
        throwsArgumentError,
      );
    });
  });

  group('BOUNDARY EDGE CASES', () {
    const decimals = 6;

    test('fraction shorter than decimals pads correctly', () {
      final result = TokenAmountNormalizer.normalize('1.2', decimals: decimals);

      expect(result, equals('1200000'));
    });

    test('fraction empty (integer) pads correctly', () {
      final result = TokenAmountNormalizer.normalize('5', decimals: decimals);

      expect(result, equals('5000000'));
    });

    test('zero fractional but with decimal', () {
      final result =
          TokenAmountNormalizer.normalize('1.000000', decimals: decimals);

      expect(result, equals('1000000'));
    });
  });

  group('INVALID DECIMALS CONFIGURATION', () {
    test('decimals = -1 throws immediately', () {
      expect(
        () => TokenAmountNormalizer.normalize(
          '1',
          decimals: -1,
        ),
        throwsArgumentError,
      );
    });

    test('decimals = -100 throws immediately', () {
      expect(
        () => TokenAmountNormalizer.normalize(
          '1.23',
          decimals: -100,
        ),
        throwsArgumentError,
      );
    });
  });
}
