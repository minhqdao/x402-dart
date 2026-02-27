import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('VerifyResponse', () {
    const json = {
      'isValid': false,
      'invalidReason': 'Insufficient funds',
      'payer': '0x123',
      'extensions': {'foo': 1},
    };

    test('fromJson', () {
      final response = VerifyResponse.fromJson(json);
      expect(response.isValid, false);
      expect(response.invalidReason, 'Insufficient funds');
      expect(response.payer, '0x123');
      expect(response.extensions?['foo'], 1);
    });

    test('toJson', () {
      const response = VerifyResponse(
        isValid: true,
        payer: '0x123',
      );
      final out = response.toJson();
      expect(out['isValid'], true);
      expect(out['payer'], '0x123');
      expect(out.containsKey('invalidReason'), isFalse);
    });
  });
}
