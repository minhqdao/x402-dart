import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('X402Exception', () {
    test('initializes with message and originalError', () {
      const msg = 'Something went wrong';
      final innerError = Exception('Inner cause');
      final exception = X402Exception(msg, originalError: innerError);

      expect(exception.message, equals(msg));
      expect(exception.originalError, equals(innerError));
      expect(
        exception.toString(),
        equals(
          'X402Exception: $msg, originalError: Exception: Inner cause',
        ),
      );
    });

    test('without originalError omits it from toString', () {
      const exception = X402Exception('Simple error');

      expect(exception.message, equals('Simple error'));
      expect(exception.originalError, isNull);
      expect(exception.toString(), equals('X402Exception: Simple error'));
    });
  });

  group('InvalidPayloadException', () {
    test('is an X402Exception and inherits originalError', () {
      const innerError = FormatException('Invalid JSON');
      const exception = InvalidPayloadException(
        'Payload invalid',
        originalError: innerError,
      );

      expect(exception, isA<X402Exception>());
      expect(exception.message, equals('Payload invalid'));
      expect(exception.originalError, equals(innerError));
      expect(
        exception.toString(),
        equals(
          'X402Exception: Payload invalid, '
          'originalError: FormatException: Invalid JSON',
        ),
      );
    });
  });

  group('UnsupportedSchemeException', () {
    test('is an X402Exception and inherits originalError', () {
      final innerError = StateError('Scheme not found');
      final exception = UnsupportedSchemeException(
        'Unknown scheme',
        originalError: innerError,
      );

      expect(exception, isA<X402Exception>());
      expect(exception.message, equals('Unknown scheme'));
      expect(exception.originalError, equals(innerError));
      expect(
        exception.toString(),
        equals(
          'X402Exception: Unknown scheme, '
          'originalError: Bad state: Scheme not found',
        ),
      );
    });
  });

  group('FacilitatorException', () {
    test('is an X402Exception', () {
      const exception = FacilitatorException('Facilitator failed');

      expect(exception, isA<X402Exception>());
      expect(exception.message, equals('Facilitator failed'));
      expect(
        exception.toString(),
        equals('X402Exception: Facilitator failed'),
      );
    });

    test('maintains originalError if provided', () {
      final inner = Exception('socket error');
      final exception =
          FacilitatorException('Network fail', originalError: inner);

      expect(exception.originalError, equals(inner));
      expect(
        exception.toString(),
        contains('originalError: Exception: socket error'),
      );
    });
  });

  group('FacilitatorResponseException', () {
    test('is an X402Exception and FacilitatorException', () {
      final body = {'error': 'Not authorized'};
      final exception = FacilitatorResponseException(
        'HTTP error',
        statusCode: 403,
        responseBody: body,
      );

      expect(exception, isA<X402Exception>());
      expect(exception, isA<FacilitatorException>());
      expect(exception.statusCode, equals(403));
      expect(exception.responseBody, equals(body));
      expect(exception.message, equals('HTTP error'));
      expect(
        exception.toString(),
        equals('X402Exception: HTTP error'),
      );
    });

    test('works with null responseBody', () {
      const exception = FacilitatorResponseException(
        'Server error',
        statusCode: 500,
      );

      expect(exception.statusCode, equals(500));
      expect(exception.responseBody, isNull);
    });

    test('includes originalError in toString', () {
      final inner = Exception('timeout');
      final exception = FacilitatorResponseException(
        'Gateway error',
        statusCode: 504,
        originalError: inner,
      );

      expect(
        exception.toString(),
        equals(
          'X402Exception: Gateway error, originalError: Exception: timeout',
        ),
      );
    });
  });
}
