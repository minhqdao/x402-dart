import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/network/evm_network.dart';
import 'package:x402_evm/src/schemes/exact_evm_scheme_server.dart';

void main() {
  group('ExactEvmSchemeServer', () {
    final network = Network.parse('eip155:8453'); // Base Mainnet (6 decimals)

    group('Constructor & Basic Properties', () {
      test('exposes correct scheme identifier', () {
        final server = ExactEvmSchemeServer();
        expect(server.scheme, equals('exact'));
      });
    });

    group('BASIC BEHAVIOR TESTS (Empty Parsers)', () {
      late ExactEvmSchemeServer server;

      setUp(() {
        server = ExactEvmSchemeServer();
      });

      test('Money("1") converts correctly using defaults', () async {
        final result = await server.parsePrice(const Money('1'), network);
        expect(result.amount, equals('1000000'));
        expect(
            result.asset, equals('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'));
      });

      test('Money("1.23") converts correctly for 6 decimals', () async {
        final result = await server.parsePrice(const Money('1.23'), network);
        expect(result.amount, equals('1230000'));
      });

      test('AssetAmount is returned unchanged (except extra defaulting)',
          () async {
        const original = AssetAmount(
          asset: '0xTest',
          amount: '500',
        );
        final result = await server.parsePrice(original, network);
        expect(result.asset, equals('0xTest'));
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

      test('AssetAmount preserves extra fields', () async {
        const original = AssetAmount(
          asset: '0xTest',
          amount: '500',
          extra: {'foo': 'bar'},
        );

        final result = await server.parsePrice(original, network);
        expect(result.extra, equals({'foo': 'bar'}));
      });
    });

    group('PRECISION TESTS', () {
      final server = ExactEvmSchemeServer();

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
      final server = ExactEvmSchemeServer();

      test('Very large integer with valid fractional precision', () async {
        const input = '123456789012345678901234567890.123456';
        final result = await server.parsePrice(const Money(input), network);

        expect(
          result.amount,
          equals('123456789012345678901234567890123456'),
        );
      });
    });

    group('ZERO TESTS', () {
      final server = ExactEvmSchemeServer();

      test('Money("0") → returns 0', () async {
        final result = await server.parsePrice(const Money('0'), network);
        expect(result.amount, equals('0'));
      });

      test('Money("0.0") → returns 0', () async {
        final result = await server.parsePrice(const Money('0.0'), network);
        expect(result.amount, equals('0'));
      });

      test('Money("0.000000") → returns 0', () async {
        final result =
            await server.parsePrice(const Money('0.000000'), network);
        expect(result.amount, equals('0'));
      });
    });

    group('LEADING ZERO TESTS', () {
      final server = ExactEvmSchemeServer();

      test('Money("0001") → correct conversion ignoring leading zeros',
          () async {
        final result = await server.parsePrice(const Money('0001'), network);
        expect(result.amount, equals('1000000'));
      });

      test('Money("0001.23") → correct conversion ignoring leading zeros',
          () async {
        final result = await server.parsePrice(const Money('0001.23'), network);
        expect(result.amount, equals('1230000'));
      });

      test('Money("0000.000001") → valid for 6 decimals', () async {
        final result =
            await server.parsePrice(const Money('0000.000001'), network);
        expect(result.amount, equals('1'));
      });

      test('Money("0000.000000") → returns 0', () async {
        final result =
            await server.parsePrice(const Money('0000.000000'), network);
        expect(result.amount, equals('0'));
      });
    });

    group('FLOATING POINT FAILURE CASE', () {
      final server = ExactEvmSchemeServer();

      test('Money("0.1") produces exactly 100000', () async {
        final result = await server.parsePrice(const Money('0.1'), network);
        expect(result.amount, equals('100000'));
      });

      test('Money("0.30000000000000004") is treated as literal string', () {
        expect(
          () => server.parsePrice(const Money('0.30000000000000004'), network),
          throwsArgumentError,
        );
      });

      test('Money("1.000001") valid boundary', () async {
        final result =
            await server.parsePrice(const Money('1.000001'), network);
        expect(result.amount, equals('1000001'));
      });

      test('Money("1.0000000") exceeds precision', () {
        expect(
          () => server.parsePrice(const Money('1.0000000'), network),
          throwsArgumentError,
        );
      });
    });

    group('INVALID INPUT TESTS', () {
      final server = ExactEvmSchemeServer();

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
      final server = ExactEvmSchemeServer();

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
      final server = ExactEvmSchemeServer();

      test('Unsupported network throws', () {
        expect(
          () =>
              server.parsePrice(const Money('1'), const EvmNetwork(chainId: 1)),
          throwsArgumentError,
        );
      });

      test('Supported networks produce correct default asset', () async {
        final base = await server.parsePrice(
            const Money('1'), Network.parse('eip155:8453'));
        expect(
            base.asset, equals('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'));

        final baseSepolia = await server.parsePrice(
            const Money('1'), Network.parse('eip155:84532'));
        expect(baseSepolia.asset,
            equals('0x036CbD53842c5426634e7929541eC2318f3dCF7e'));
      });
    });

    group('MONEY PARSER INJECTION TESTS', () {
      test('Single injected parser works', () async {
        final server = ExactEvmSchemeServer(
          moneyParsers: [
            (amount, net) async {
              if (amount == 'special') {
                return const AssetAmount(asset: '0xSpecial', amount: '777');
              }
              return null;
            }
          ],
        );

        final result = await server.parsePrice(const Money('special'), network);
        expect(result.asset, equals('0xSpecial'));
        expect(result.amount, equals('777'));
      });

      test('Parsers are tried in order and can short-circuit', () async {
        final server = ExactEvmSchemeServer(
          moneyParsers: [
            (amount, net) async =>
                const AssetAmount(asset: '0xFirst', amount: '1'),
            (amount, net) async =>
                throw UnimplementedError('Should not be called'),
          ],
        );

        final result = await server.parsePrice(const Money('any'), network);
        expect(result.asset, equals('0xFirst'));
      });

      test('Fallback to next parser when first returns null', () async {
        final server = ExactEvmSchemeServer(
          moneyParsers: [
            (amount, net) async => null,
            (amount, net) async =>
                const AssetAmount(asset: '0xSecond', amount: '2'),
          ],
        );

        final result = await server.parsePrice(const Money('any'), network);
        expect(result.asset, equals('0xSecond'));
      });

      test('Fallback to default conversion when all parsers return null',
          () async {
        final server = ExactEvmSchemeServer(
          moneyParsers: [
            (amount, net) async => null,
            (amount, net) async => null,
          ],
        );

        final result = await server.parsePrice(const Money('1'), network);
        expect(result.amount, equals('1000000'));
      });

      test('Parsers execute sequentially even if async', () async {
        final calls = <String>[];

        final server = ExactEvmSchemeServer(
          moneyParsers: [
            (amount, net) async {
              calls.add('first');
              await Future.delayed(const Duration(milliseconds: 10));
              return null;
            },
            (amount, net) async {
              calls.add('second');
              return const AssetAmount(asset: '0xSecond', amount: '2');
            },
          ],
        );

        await server.parsePrice(const Money('1'), network);

        expect(calls, equals(['first', 'second']));
      });
    });

    group('CONSTRUCTOR IMMUTABILITY TESTS', () {
      test('Mutating original parser list does not affect server', () async {
        final parsers = <MoneyParser>[
          (amount, net) async => null,
        ];

        final server = ExactEvmSchemeServer(moneyParsers: parsers);

        // Mutate original list after construction
        parsers.add(
          (amount, net) async =>
              const AssetAmount(asset: '0xInjected', amount: '999'),
        );

        // Should NOT use newly added parser
        final result = await server.parsePrice(const Money('1'), network);

        expect(result.amount, equals('1000000'));
      });
    });

    group('enhancePaymentRequirement', () {
      test('returns payment requirement unchanged', () async {
        final server = ExactEvmSchemeServer();
        final req = PaymentRequirement(
          scheme: 'exact',
          network: network,
          asset: '0xAsset',
          amount: '100',
          payTo: '0xReceiver',
          maxTimeoutSeconds: 60,
          extra: const {'foo': 'bar'},
        );

        final enhanced = await server.enhancePaymentRequirement(
          req,
          kind: SupportedKind(
            x402Version: 1,
            scheme: 'exact',
            network: network,
          ),
        );

        expect(enhanced, equals(req));
      });
    });
  });
}
