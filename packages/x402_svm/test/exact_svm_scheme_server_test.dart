import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/schemes/exact_svm_scheme_server.dart';

void main() {
  group('ExactSvmSchemeServer', () {
    final network = Network.parse('solana:mainnet'); // 6 decimals

    group('Constructor & Basic Properties', () {
      test('exposes correct scheme identifier', () {
        final server = ExactSvmSchemeServer();
        expect(server.scheme, equals('exact'));
      });
    });

    group('BASIC BEHAVIOR TESTS (Empty Parsers)', () {
      late ExactSvmSchemeServer server;

      setUp(() {
        server = ExactSvmSchemeServer();
      });

      test('Money("1") converts correctly using defaults', () async {
        final result = await server.parsePrice(const Money('1'), network);
        expect(result.amount, equals('1000000'));
        expect(result.asset,
            equals('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'));
      });

      test('Money("1.23") converts correctly for 6 decimals', () async {
        final result = await server.parsePrice(const Money('1.23'), network);
        expect(result.amount, equals('1230000'));
      });

      test('AssetAmount is returned unchanged (except extra defaulting)',
          () async {
        const original = AssetAmount(
          asset: 'MintTest11111111111111111111111111111111111',
          amount: '500',
        );
        final result = await server.parsePrice(original, network);
        expect(result.asset, equals(original.asset));
        expect(result.amount, equals('500'));
        expect(result.extra, equals(const <String, dynamic>{}));
      });

      test('AssetAmount with empty asset throws', () {
        const original = AssetAmount(
          asset: '',
          amount: '500',
        );
        expect(
          () => server.parsePrice(original, network),
          throwsArgumentError,
        );
      });
    });

    group('PRECISION TESTS', () {
      final server = ExactSvmSchemeServer();

      test('Money("0.1") → correct smallest unit conversion', () async {
        final result = await server.parsePrice(const Money('0.1'), network);
        expect(result.amount, equals('100000'));
      });

      test('Money("0.000001") → valid for 6 decimals', () async {
        final result =
            await server.parsePrice(const Money('0.000001'), network);
        expect(result.amount, equals('1'));
      });

      test('Money("0.0000001") → throws precision overflow', () {
        expect(
          () => server.parsePrice(const Money('0.0000001'), network),
          throwsArgumentError,
        );
      });

      test('Large integer amounts', () async {
        final result = await server.parsePrice(const Money('123456'), network);
        expect(result.amount, equals('123456000000'));
      });

      test('Very large integer strings', () async {
        const large = '1000000000000000000000';
        final result = await server.parsePrice(const Money(large), network);
        expect(result.amount, equals('${large}000000'));
      });
    });

    group('EXTREME VALID DECIMAL TESTS', () {
      final server = ExactSvmSchemeServer();

      test('Very large integer with valid fractional precision', () async {
        const input = '123456789012345678901234567890.123456';

        final result = await server.parsePrice(const Money(input), network);

        expect(
          result.amount,
          equals('123456789012345678901234567890123456'),
        );
      });
    });

    group('LEADING ZERO TESTS', () {
      final server = ExactSvmSchemeServer();

      test('Money("0001") converts correctly', () async {
        final result = await server.parsePrice(const Money('0001'), network);
        expect(result.amount, equals('1000000'));
      });

      test('Money("0001.23") converts correctly', () async {
        final result = await server.parsePrice(const Money('0001.23'), network);
        expect(result.amount, equals('1230000'));
      });

      test('Money("0000.000001") converts to 1', () async {
        final result =
            await server.parsePrice(const Money('0000.000001'), network);
        expect(result.amount, equals('1'));
      });

      test('Money("0000.000000") converts to 0', () async {
        final result =
            await server.parsePrice(const Money('0000.000000'), network);
        expect(result.amount, equals('0'));
      });
    });

    group('FLOATING POINT FAILURE CASE', () {
      final server = ExactSvmSchemeServer();

      test('Money("0.1") produces exactly 100000', () async {
        // This test demonstrates correctness for Money("0.1").
        // If double was used, 0.1 cannot be represented exactly in binary,
        // which often leads to precision issues (e.g. 0.1 * 10^6 might
        // result in 99999.99999999999).
        // String-based conversion ensures "0.1" is always "100000".
        final result = await server.parsePrice(const Money('0.1'), network);
        expect(result.amount, equals('100000'));
      });

      test('Money("0.30000000000000004") is treated as literal string', () {
        // "0.30000000000000004" is a classic float precision error for 0.1 + 0.2.
        // By treating it as a literal string, we ensure it isn't rounded or
        // corrupted by floating-point behavior.
        // For 6 decimals, this exceeds precision and must throw.
        expect(
          () => server.parsePrice(const Money('0.30000000000000004'), network),
          throwsArgumentError,
        );
      });
    });

    group('INVALID INPUT TESTS', () {
      final server = ExactSvmSchemeServer();

      test('Money("abc") throws', () {
        expect(
          () => server.parsePrice(const Money('abc'), network),
          throwsArgumentError,
        );
      });

      test('Money("1e-6") throws (scientific notation rejected)', () {
        expect(
          () => server.parsePrice(const Money('1e-6'), network),
          throwsArgumentError,
        );
      });

      test('Money("-1") throws', () {
        expect(
          () => server.parsePrice(const Money('-1'), network),
          throwsArgumentError,
        );
      });

      test('Money("") throws', () {
        expect(
          () => server.parsePrice(const Money(''), network),
          throwsArgumentError,
        );
      });

      test('Money(" 1.0") throws (leading whitespace)', () {
        expect(
          () => server.parsePrice(const Money(' 1.0'), network),
          throwsArgumentError,
        );
      });

      test('Money("\$1.00") throws (currency symbols)', () {
        expect(
          () => server.parsePrice(const Money('\$1.00'), network),
          throwsArgumentError,
        );
      });
    });

    group('DECIMAL FORMAT EDGE CASES', () {
      final server = ExactSvmSchemeServer();

      test('Money("1.") throws', () {
        expect(
          () => server.parsePrice(const Money('1.'), network),
          throwsArgumentError,
        );
      });

      test('Money(".1") throws', () {
        expect(
          () => server.parsePrice(const Money('.1'), network),
          throwsArgumentError,
        );
      });

      test('Money(".") throws', () {
        expect(
          () => server.parsePrice(const Money('.'), network),
          throwsArgumentError,
        );
      });
    });

    group('NETWORK TESTS', () {
      final server = ExactSvmSchemeServer();

      test('Unsupported network throws', () {
        expect(
          () => server.parsePrice(
              const Money('1'), Network.parse('solana:unknown')),
          throwsArgumentError,
        );
      });

      test('Supported networks produce correct default asset', () async {
        final mainnet = await server.parsePrice(
            const Money('1'), Network.parse('solana:mainnet'));
        expect(mainnet.asset,
            equals('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'));

        final devnet = await server.parsePrice(
            const Money('1'), Network.parse('solana:devnet'));
        expect(devnet.asset,
            equals('4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU'));
      });
    });

    group('MONEY PARSER INJECTION TESTS', () {
      test('Single injected parser works', () async {
        final server = ExactSvmSchemeServer(
          moneyParsers: [
            (amount, net) async {
              if (amount == 'special') {
                return const AssetAmount(
                    asset: 'MintSpecial1111111111', amount: '777');
              }
              return null;
            }
          ],
        );

        final result = await server.parsePrice(const Money('special'), network);
        expect(result.asset, equals('MintSpecial1111111111'));
        expect(result.amount, equals('777'));
      });

      test('Parsers are tried in order and can short-circuit', () async {
        final server = ExactSvmSchemeServer(
          moneyParsers: [
            (amount, net) async =>
                const AssetAmount(asset: 'MintFirst1111111111', amount: '1'),
            (amount, net) async =>
                throw UnimplementedError('Should not be called'),
          ],
        );

        final result = await server.parsePrice(const Money('any'), network);
        expect(result.asset, equals('MintFirst1111111111'));
      });

      test('Fallback to next parser when first returns null', () async {
        final server = ExactSvmSchemeServer(
          moneyParsers: [
            (amount, net) async => null,
            (amount, net) async =>
                const AssetAmount(asset: 'MintSecond1111111111', amount: '2'),
          ],
        );

        final result = await server.parsePrice(const Money('any'), network);
        expect(result.asset, equals('MintSecond1111111111'));
      });

      test('Fallback to default conversion when all parsers return null',
          () async {
        final server = ExactSvmSchemeServer(
          moneyParsers: [
            (amount, net) async => null,
            (amount, net) async => null,
          ],
        );

        final result = await server.parsePrice(const Money('1'), network);
        expect(result.amount, equals('1000000'));
      });
    });

    group('CONSTRUCTOR IMMUTABILITY TESTS', () {
      test('Mutating original parser list does not affect server', () async {
        final parsers = <MoneyParser>[
          (amount, net) async => null,
        ];

        final server = ExactSvmSchemeServer(moneyParsers: parsers);

        // mutate after construction
        parsers.add(
          (amount, net) async =>
              const AssetAmount(asset: 'InjectedMint', amount: '999'),
        );

        final result = await server.parsePrice(const Money('1'), network);

        // Should still use default conversion
        expect(result.amount, equals('1000000'));
      });
    });

    group('SVM-SPECIFIC TESTS', () {
      final server = ExactSvmSchemeServer();

      test('enhancePaymentRequirement adds feePayer when present', () async {
        final req = PaymentRequirement(
          scheme: 'exact',
          network: network,
          asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          amount: '1000000',
          payTo: 'Receiver11111111111111111111111111111111',
          maxTimeoutSeconds: 60,
          extra: const {},
        );

        final kind = SupportedKind(
          x402Version: 1,
          scheme: 'exact',
          network: network,
          extra: const {
            'feePayer': 'FeePayer111111111111111111111111111111111'
          },
        );

        final enhanced =
            await server.enhancePaymentRequirement(req, kind: kind);
        expect(enhanced.extra['feePayer'],
            equals('FeePayer111111111111111111111111111111111'));
      });

      test('enhancePaymentRequirement leaves object unchanged when absent',
          () async {
        final req = PaymentRequirement(
          scheme: 'exact',
          network: network,
          asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          amount: '1000000',
          payTo: 'Receiver11111111111111111111111111111111',
          maxTimeoutSeconds: 60,
          extra: const {'existing': 'data'},
        );

        final kind = SupportedKind(
          x402Version: 1,
          scheme: 'exact',
          network: network,
        );

        final enhanced =
            await server.enhancePaymentRequirement(req, kind: kind);
        expect(enhanced.extra, equals(const {'existing': 'data'}));
      });

      test('enhancePaymentRequirement merges with existing extra', () async {
        final req = PaymentRequirement(
          scheme: 'exact',
          network: network,
          asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          amount: '1000000',
          payTo: 'Receiver11111111111111111111111111111111',
          maxTimeoutSeconds: 60,
          extra: const {'existing': 'value'},
        );

        final kind = SupportedKind(
          x402Version: 1,
          scheme: 'exact',
          network: network,
          extra: const {'feePayer': 'FeePayerXYZ'},
        );

        final enhanced =
            await server.enhancePaymentRequirement(req, kind: kind);

        expect(enhanced.extra['existing'], equals('value'));
        expect(enhanced.extra['feePayer'], equals('FeePayerXYZ'));
      });
    });
  });
}
