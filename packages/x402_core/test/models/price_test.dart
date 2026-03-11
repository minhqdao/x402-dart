import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('Price Models', () {
    test('Money', () {
      const money = Money('0.10');
      expect(money.amount, '0.10');
    });

    test('AssetAmount', () {
      const asset = AssetAmount(
        asset: 'USDC',
        amount: '100000',
        extra: {'decimals': 6},
      );
      expect(asset.asset, 'USDC');
      expect(asset.amount, '100000');
      expect(asset.extra?['decimals'], 6);
    });
  });
}
