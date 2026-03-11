import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('Sealed Verify Results', () {
    test('BeforeVerifyResult types', () {
      expect(const ContinueVerify(), isA<BeforeVerifyResult>());
      expect(const AbortVerify('reason'), isA<BeforeVerifyResult>());
    });

    test('VerifyFailureResult types', () {
      expect(const NoVerifyRecovery(), isA<VerifyFailureResult>());
      expect(
        const RecoverVerify(VerifyResponse(isValid: true)),
        isA<VerifyFailureResult>(),
      );
    });
  });
}
