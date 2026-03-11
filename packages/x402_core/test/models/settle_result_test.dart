import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('Sealed Settle Results', () {
    test('BeforeSettleResult types', () {
      expect(const ContinueSettle(), isA<BeforeSettleResult>());
      expect(const AbortSettle('reason'), isA<BeforeSettleResult>());
    });

    test('SettleFailureResult types', () {
      expect(const NoSettleRecovery(), isA<SettleFailureResult>());
      expect(
        const RecoverSettle(SettleResponse(
          success: true,
          transaction: 'tx',
          network: Network(namespace: 'n', reference: 'r'),
        )),
        isA<SettleFailureResult>(),
      );
    });
  });
}
