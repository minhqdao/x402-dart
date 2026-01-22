import 'package:test/test.dart';
import 'package:x402_svm/src/models/exact_svm_payload.dart';

void main() {
  group('ExactSvmPayload', () {
    const transaction = 'base64_encoded_transaction_data';
    const blockhash = 'base58_encoded_blockhash';

    test('should create instance with required fields', () {
      const payload = ExactSvmPayload(transaction: transaction);
      expect(payload.transaction, transaction);
      expect(payload.blockhash, isNull);
    });

    test('should create instance with all fields', () {
      const payload = ExactSvmPayload(
        transaction: transaction,
        blockhash: blockhash,
      );
      expect(payload.transaction, transaction);
      expect(payload.blockhash, blockhash);
    });

    group('toJson', () {
      test('should serialize correctly without blockhash', () {
        const payload = ExactSvmPayload(transaction: transaction);
        final json = payload.toJson();
        expect(json, {
          'transaction': transaction,
        });
      });

      test('should serialize correctly with blockhash', () {
        const payload = ExactSvmPayload(
          transaction: transaction,
          blockhash: blockhash,
        );
        final json = payload.toJson();
        expect(json, {
          'transaction': transaction,
          'blockhash': blockhash,
        });
      });
    });

    group('fromJson', () {
      test('should deserialize correctly without blockhash', () {
        final json = {'transaction': transaction};
        final payload = ExactSvmPayload.fromJson(json);
        expect(payload.transaction, transaction);
        expect(payload.blockhash, isNull);
      });

      test('should deserialize correctly with blockhash', () {
        final json = {
          'transaction': transaction,
          'blockhash': blockhash,
        };
        final payload = ExactSvmPayload.fromJson(json);
        expect(payload.transaction, transaction);
        expect(payload.blockhash, blockhash);
      });
    });

    test('ExactSvmPayload JSON round-trip preserves data', () {
      const original = ExactSvmPayload(
        transaction: transaction,
        blockhash: blockhash,
      );

      final json = original.toJson();
      final parsed = ExactSvmPayload.fromJson(json);

      expect(parsed.transaction, original.transaction);
      expect(parsed.blockhash, original.blockhash);
    });

    test('ExactSvmPayload.fromJson throws if transaction is missing', () {
      expect(
        () => ExactSvmPayload.fromJson({}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
