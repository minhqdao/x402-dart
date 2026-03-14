import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('Constants', () {
    test('should have correct values', () {
      expect(kX402Version, equals(2));
      expect(kPaymentHeader, equals('x-payment'));
      expect(kPaymentRequiredStatus, equals(402));
    });
  });
}
