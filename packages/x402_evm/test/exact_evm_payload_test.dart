import 'package:test/test.dart';
import 'package:x402_evm/src/models/exact_evm_payload.dart';

void main() {
  group('ExactEvmPayload', () {
    const from = '0x1234567890123456789012345678901234567890';
    const to = '0x0987654321098765432109876543210987654321';
    const value = '1000000';
    const validAfter = '0';
    const validBefore = '1737130000';
    const nonce =
        '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    test('should serialize to JSON with all fields', () {
      const auth = ExactEvmPayload(
        from: from,
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
      );

      final json = auth.toJson();

      expect(json['from'], equals(from));
      expect(json['to'], equals(to));
      expect(json['value'], equals(value));
      expect(json['validAfter'], equals(validAfter));
      expect(json['validBefore'], equals(validBefore));
      expect(json['nonce'], equals(nonce));
    });

    test('should deserialize from JSON with all fields', () {
      final json = {
        'from': from,
        'to': to,
        'value': value,
        'validAfter': validAfter,
        'validBefore': validBefore,
        'nonce': nonce,
      };

      final auth = ExactEvmPayload.fromJson(json);

      expect(auth.from, equals(from));
      expect(auth.to, equals(to));
      expect(auth.value, equals(value));
      expect(auth.validAfter, equals(validAfter));
      expect(auth.validBefore, equals(validBefore));
      expect(auth.nonce, equals(nonce));
    });

    test('should handle round-trip serialization', () {
      const auth = ExactEvmPayload(
        from: from,
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
      );

      final json = auth.toJson();
      final deserialized = ExactEvmPayload.fromJson(json);

      expect(deserialized.from, equals(auth.from));
      expect(deserialized.to, equals(auth.to));
      expect(deserialized.value, equals(auth.value));
      expect(deserialized.validAfter, equals(auth.validAfter));
      expect(deserialized.validBefore, equals(auth.validBefore));
      expect(deserialized.nonce, equals(auth.nonce));
    });
  });
}
