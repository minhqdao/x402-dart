import 'package:test/test.dart';
import 'package:x402_svm/src/models/exact_svm_payload.dart';

void main() {
  group('ExactSvmPayload', () {
    const transaction = 'base64_encoded_transaction_data';

    test('should create instance with required fields', () {
      const payload = ExactSvmPayload(transaction);
      expect(payload.transaction, transaction);
    });
  });
}
