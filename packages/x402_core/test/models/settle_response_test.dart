import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('SettleResponse', () {
    const json = {
      'success': true,
      'errorReason': null,
      'payer': '0xPayer',
      'transaction': '0xTx',
      'network': 'eip155:1',
      'extensions': {'foo': 'bar'},
    };

    test('fromJson', () {
      final response = SettleResponse.fromJson(json);
      expect(response.success, true);
      expect(response.errorReason, isNull);
      expect(response.payer, '0xPayer');
      expect(response.transaction, '0xTx');
      expect(response.network.identifier, 'eip155:1');
      expect(response.extensions?['foo'], 'bar');
    });

    test('toJson', () {
      const response = SettleResponse(
        success: true,
        payer: '0xPayer',
        transaction: '0xTx',
        network: Network(namespace: 'eip155', reference: '1'),
        extensions: {'foo': 'bar'},
      );
      final out = response.toJson();
      expect(out['success'], true);
      expect(out['payer'], '0xPayer');
      expect(out['transaction'], '0xTx');
      expect(out['network'], 'eip155:1');
      expect(out['extensions'], {'foo': 'bar'});
      expect(out.containsKey('errorReason'), isFalse);
    });
  });
}
