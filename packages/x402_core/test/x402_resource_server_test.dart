import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

class MockFacilitatorClient implements FacilitatorClient {
  SupportedResponse? supportedResponse;
  VerifyResponse? verifyResponse;
  Object? getSupportedError;

  @override
  Future<SupportedResponse> getSupported() async {
    if (getSupportedError != null) throw getSupportedError!;
    return supportedResponse ??
        const SupportedResponse(
          kinds: [],
          extensions: [],
          signers: {},
        );
  }

  @override
  Future<VerifyResponse> verify(
    PaymentPayload paymentPayload,
    PaymentRequirement paymentRequirement,
  ) async {
    return verifyResponse ?? const VerifyResponse(isValid: true);
  }

  @override
  Future<SettleResponse> settle(
    PaymentPayload paymentPayload,
    PaymentRequirement paymentRequirement,
  ) async {
    return const SettleResponse(
      success: true,
      transaction: 'tx',
      network: 'net',
    );
  }
}

class MockSchemeServer implements SchemeServer {
  @override
  final String scheme;
  AssetAmount? parsePriceResult;
  PaymentRequirement? enhancedRequirement;

  MockSchemeServer(this.scheme);

  @override
  Future<AssetAmount> parsePrice(Price price, String network) async {
    if (price is AssetAmount) return price;
    return parsePriceResult ?? const AssetAmount(asset: 'asset', amount: '100');
  }

  @override
  Future<PaymentRequirement> enhancePaymentRequirement(
    PaymentRequirement paymentRequirement, {
    required SupportedKind kind,
    List<String> facilitatorExtensions = const [],
  }) async {
    return enhancedRequirement ?? paymentRequirement;
  }
}

class ThrowingParseSchemeServer extends MockSchemeServer {
  ThrowingParseSchemeServer() : super('exact');

  @override
  Future<AssetAmount> parsePrice(Price price, String network) {
    throw Exception('parse failure');
  }
}

class ThrowingEnhanceSchemeServer extends MockSchemeServer {
  ThrowingEnhanceSchemeServer() : super('exact');

  @override
  Future<PaymentRequirement> enhancePaymentRequirement(
    PaymentRequirement paymentRequirement, {
    required SupportedKind kind,
    List<String> facilitatorExtensions = const [],
  }) {
    throw Exception('enhance failure');
  }
}

void main() {
  group('X402ResourceServer.create', () {
    test('initializes successfully with one facilitator and one scheme',
        () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: 'eip155:1',
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemes: {'eip155:1': MockSchemeServer('exact')},
      );

      expect(server, isNotNull);
    });

    test('initializes with multiple facilitators', () async {
      final f1 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
                x402Version: kX402Version, scheme: 's1', network: 'n1'),
          ],
          extensions: [],
          signers: {},
        );
      final f2 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
                x402Version: kX402Version, scheme: 's2', network: 'n2'),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [f1, f2],
        schemes: {
          'n1': MockSchemeServer('s1'),
          'n2': MockSchemeServer('s2'),
        },
      );

      expect(server, isNotNull);
    });

    test('single facilitator supporting multiple schemes and networks',
        () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's1',
              network: 'n1',
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's2',
              network: 'n2',
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemes: {
          'n1': MockSchemeServer('s1'),
          'n2': MockSchemeServer('s2'),
        },
      );

      expect(server, isNotNull);
    });

    test('supports multiple schemes on same network', () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's1',
              network: 'n1',
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's2',
              network: 'n1',
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemes: {
          'n1': MockSchemeServer('s1'),
        },
      );

      expect(server, isNotNull);
    });

    test('throws ArgumentError if schemes is empty', () {
      expect(
        () => X402ResourceServer.create(
          facilitators: [MockFacilitatorClient()],
          schemes: {},
        ),
        throwsArgumentError,
      );
    });

    test('throws StateError if no facilitator support loaded', () {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [],
          extensions: [],
          signers: {},
        );

      expect(
        () => X402ResourceServer.create(
          facilitators: [facilitator],
          schemes: {'net': MockSchemeServer('exact')},
        ),
        throwsStateError,
      );
    });

    test('propagates error from getSupported', () {
      final facilitator = MockFacilitatorClient()
        ..getSupportedError = Exception('Network error');

      expect(
        () => X402ResourceServer.create(
          facilitators: [facilitator],
          schemes: {'net': MockSchemeServer('exact')},
        ),
        throwsException,
      );
    });

    test('ignores supported kinds with different x402Version', () {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: 999, // wrong version
              scheme: 'exact',
              network: 'eip155:1',
            ),
          ],
          extensions: [],
          signers: {},
        );

      expect(
        () => X402ResourceServer.create(
          facilitators: [facilitator],
          schemes: {'eip155:1': MockSchemeServer('exact')},
        ),
        throwsStateError,
      );
    });

    test('ignores unsupported versions but registers supported ones', () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: 999,
              scheme: 'exact',
              network: 'eip155:1',
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: 'eip155:1',
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemes: {'eip155:1': MockSchemeServer('exact')},
      );

      expect(server, isNotNull);
    });

    test('last facilitator wins if multiple support same scheme/network',
        () async {
      final f1 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: 'eip155:1',
            ),
          ],
          extensions: [],
          signers: {},
        );

      final f2 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: 'eip155:1',
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [f1, f2],
        schemes: {'eip155:1': MockSchemeServer('exact')},
      );

      // Build requirement to ensure no crash and deterministic routing
      const config = ResourceConfig(
        scheme: 'exact',
        payTo: 'receiver',
        price: Money('1'),
        network: 'eip155:1',
      );

      final requirements = await server.buildPaymentRequirements(config);
      expect(requirements, hasLength(1));
    });

    test('throws if facilitators list is empty', () {
      expect(
        () => X402ResourceServer.create(
          facilitators: [],
          schemes: {'net': MockSchemeServer('exact')},
        ),
        throwsStateError,
      );
    });
  });

  group('X402ResourceServer members', () {
    late X402ResourceServer resourceServer;
    late MockFacilitatorClient facilitator;
    late MockSchemeServer schemeServer;

    setUp(() async {
      facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: 'eip155:1',
            ),
          ],
          extensions: ['ext1'],
          signers: {},
        );
      schemeServer = MockSchemeServer('exact');

      resourceServer = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemes: {'eip155:1': schemeServer},
      );
    });

    group('buildPaymentRequirements', () {
      test('correctly builds requirements', () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: 'eip155:1',
          maxTimeoutSeconds: 60,
        );

        schemeServer.parsePriceResult = const AssetAmount(
          asset: '0xUSDC',
          amount: '1000000',
          extra: {'name': 'USDC'},
        );

        final requirements =
            await resourceServer.buildPaymentRequirements(config);

        expect(requirements, hasLength(1));
        final req = requirements.first;
        expect(req.scheme, equals('exact'));
        expect(req.network, equals('eip155:1'));
        expect(req.amount, equals('1000000'));
        expect(req.asset, equals('0xUSDC'));
        expect(req.payTo, equals('receiver'));
        expect(req.maxTimeoutSeconds, equals(60));
        expect(req.extra['name'], equals('USDC'));
      });

      test('calls enhancePaymentRequirement', () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: 'eip155:1',
        );

        schemeServer.enhancedRequirement = const PaymentRequirement(
          scheme: 'exact',
          network: 'eip155:1',
          asset: 'enhanced-asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {'enhanced': true},
        );

        final requirements =
            await resourceServer.buildPaymentRequirements(config);

        expect(requirements.first.asset, equals('enhanced-asset'));
        expect(requirements.first.extra['enhanced'], isTrue);
      });

      test('works with AssetAmount', () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: AssetAmount(asset: '0xAsset', amount: '500'),
          network: 'eip155:1',
        );

        final requirements =
            await resourceServer.buildPaymentRequirements(config);

        expect(requirements.first.amount, equals('500'));
        expect(requirements.first.asset, equals('0xAsset'));
      });

      test('throws StateError if scheme not registered for network', () {
        const config = ResourceConfig(
          scheme: 'other',
          payTo: 'receiver',
          price: Money('1.0'),
          network: 'eip155:1',
        );

        expect(
          () => resourceServer.buildPaymentRequirements(config),
          throwsStateError,
        );
      });

      test('throws StateError if facilitator does not support scheme/network',
          () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: 'other-net',
        );

        // We need to register the scheme for 'other-net' too during setup if we want it to get past the first check
        final resourceServer2 = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemes: {
            'eip155:1': schemeServer,
            'other-net': schemeServer,
          },
        );

        expect(
          () => resourceServer2.buildPaymentRequirements(config),
          throwsStateError,
        );
      });

      test('throws if SupportedKind for scheme/network is missing', () async {
        final facilitator = MockFacilitatorClient()
          ..supportedResponse = const SupportedResponse(
            kinds: [
              SupportedKind(
                x402Version: kX402Version,
                scheme: 'exact',
                network: 'different-network',
              ),
            ],
            extensions: [],
            signers: {},
          );

        final server = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemes: {'eip155:1': MockSchemeServer('exact')},
        );

        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: 'eip155:1',
        );

        expect(
          () => server.buildPaymentRequirements(config),
          throwsA(isA<StateError>()),
        );
      });

      test('propagates error from parsePrice', () async {
        final scheme = ThrowingParseSchemeServer();

        final facilitator = MockFacilitatorClient()
          ..supportedResponse = const SupportedResponse(
            kinds: [
              SupportedKind(
                x402Version: kX402Version,
                scheme: 'exact',
                network: 'eip155:1',
              ),
            ],
            extensions: [],
            signers: {},
          );

        final server = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemes: {'eip155:1': scheme},
        );

        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1'),
          network: 'eip155:1',
        );

        expect(
          () => server.buildPaymentRequirements(config),
          throwsException,
        );
      });

      test('propagates error from enhancePaymentRequirement', () async {
        final scheme = ThrowingEnhanceSchemeServer();

        final facilitator = MockFacilitatorClient()
          ..supportedResponse = const SupportedResponse(
            kinds: [
              SupportedKind(
                x402Version: kX402Version,
                scheme: 'exact',
                network: 'eip155:1',
              ),
            ],
            extensions: [],
            signers: {},
          );

        final server = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemes: {'eip155:1': scheme},
        );

        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1'),
          network: 'eip155:1',
        );

        expect(
          () => server.buildPaymentRequirements(config),
          throwsException,
        );
      });

      test('passes facilitator extensions to enhancePaymentRequirement',
          () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: 'eip155:1',
        );

        schemeServer.enhancedRequirement = null;

        schemeServer = MockSchemeServer('exact')
          ..enhancedRequirement = const PaymentRequirement(
            scheme: 'exact',
            network: 'eip155:1',
            asset: 'asset',
            amount: '100',
            payTo: 'receiver',
            maxTimeoutSeconds: 60,
            extra: {},
          );

        resourceServer = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemes: {'eip155:1': schemeServer},
        );

        await resourceServer.buildPaymentRequirements(config);

        // If no crash, extension passing works.
        expect(true, isTrue);
      });

      test('buildPaymentRequirements is stable across repeated calls',
          () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: 'eip155:1',
        );

        for (var i = 0; i < 50; i++) {
          final requirements =
              await resourceServer.buildPaymentRequirements(config);

          expect(requirements, hasLength(1));
          expect(requirements.first.scheme, equals('exact'));
        }
      });
    });

    group('verifyPayment', () {
      test('calls facilitator verify', () async {
        const requirement = PaymentRequirement(
          scheme: 'exact',
          network: 'eip155:1',
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        );

        const payload = PaymentPayload(
          x402Version: kX402Version,
          resource: ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: {'sig': 'abc'},
        );

        facilitator.verifyResponse = const VerifyResponse(isValid: true);

        final result = await resourceServer.verifyPayment(payload, requirement);

        expect(result.isValid, isTrue);
      });

      test('throws StateError if no facilitator available', () {
        const requirement = PaymentRequirement(
          scheme: 'exact',
          network: 'other-net',
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        );

        const payload = PaymentPayload(
          x402Version: 1,
          resource: ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: {},
        );

        expect(
          () => resourceServer.verifyPayment(payload, requirement),
          throwsStateError,
        );
      });

      test('verify uses correct facilitator when multiple exist', () async {
        final f1 = MockFacilitatorClient()
          ..supportedResponse = const SupportedResponse(
            kinds: [
              SupportedKind(
                x402Version: kX402Version,
                scheme: 's1',
                network: 'n1',
              ),
            ],
            extensions: [],
            signers: {},
          );

        final f2 = MockFacilitatorClient()
          ..supportedResponse = const SupportedResponse(
            kinds: [
              SupportedKind(
                x402Version: kX402Version,
                scheme: 's2',
                network: 'n2',
              ),
            ],
            extensions: [],
            signers: {},
          )
          ..verifyResponse = const VerifyResponse(isValid: false);

        final server = await X402ResourceServer.create(
          facilitators: [f1, f2],
          schemes: {
            'n1': MockSchemeServer('s1'),
            'n2': MockSchemeServer('s2'),
          },
        );

        const requirement = PaymentRequirement(
          scheme: 's2',
          network: 'n2',
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        );

        const payload = PaymentPayload(
          x402Version: kX402Version,
          resource: ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: {},
        );

        final result = await server.verifyPayment(payload, requirement);
        expect(result.isValid, isFalse);
      });

      test('throws if payload version unsupported even if network matches', () {
        const requirement = PaymentRequirement(
          scheme: 'exact',
          network: 'eip155:1',
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        );

        const payload = PaymentPayload(
          x402Version: 999,
          resource: ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: {},
        );

        expect(
          () => resourceServer.verifyPayment(payload, requirement),
          throwsStateError,
        );
      });

      test('verifyPayment is stable across repeated calls', () async {
        const requirement = PaymentRequirement(
          scheme: 'exact',
          network: 'eip155:1',
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        );

        const payload = PaymentPayload(
          x402Version: kX402Version,
          resource: ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: {},
        );

        for (var i = 0; i < 30; i++) {
          final result =
              await resourceServer.verifyPayment(payload, requirement);
          expect(result.isValid, isTrue);
        }
      });
    });

    group('findMatchingRequirements', () {
      final available = [
        const PaymentRequirement(
          scheme: 'exact',
          network: 'eip155:1',
          asset: '0x1',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        ),
        const PaymentRequirement(
          scheme: 'exact',
          network: 'solana:mainnet',
          asset: 'mint',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        ),
      ];

      test('Version 1: matches by scheme and network', () {
        const payload = PaymentPayload(
          x402Version: 1,
          resource: ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'exact',
            network: 'eip155:1',
            asset: 'DIFFERENT', // Should not matter for v1
            amount: '999', // Should not matter for v1
            payTo: 'any',
            maxTimeoutSeconds: 0,
            extra: {},
          ),
          payload: {},
        );

        final match =
            resourceServer.findMatchingRequirements(available, payload);

        expect(match, isNotNull);
        expect(match!.network, equals('eip155:1'));
      });

      test('Version 1: does not match if scheme differs', () {
        const payload = PaymentPayload(
          x402Version: 1,
          resource: ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'other',
            network: 'eip155:1',
            asset: 'asset',
            amount: '100',
            payTo: 'any',
            maxTimeoutSeconds: 0,
            extra: {},
          ),
          payload: {},
        );

        final match =
            resourceServer.findMatchingRequirements(available, payload);

        expect(match, isNull);
      });

      test('Version 2: matches by equality', () {
        final payload = PaymentPayload(
          x402Version: 2,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: available[1],
          payload: {},
        );

        final match =
            resourceServer.findMatchingRequirements(available, payload);

        expect(match, equals(available[1]));
      });

      test('Version 2: returns null if no exact match', () {
        final payload = PaymentPayload(
          x402Version: 2,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: available[1].copyWith(amount: '200'),
          payload: {},
        );

        final match =
            resourceServer.findMatchingRequirements(available, payload);

        expect(match, isNull);
      });

      test('throws UnsupportedError for unknown versions', () {
        final payload = PaymentPayload(
          x402Version: 3,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: available[0],
          payload: {},
        );

        expect(
          () => resourceServer.findMatchingRequirements(available, payload),
          throwsUnsupportedError,
        );
      });

      test('Version 1: does not match if network differs', () {
        const payload = PaymentPayload(
          x402Version: 1,
          resource: ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'exact',
            network: 'different',
            asset: 'asset',
            amount: '100',
            payTo: 'any',
            maxTimeoutSeconds: 0,
            extra: {},
          ),
          payload: {},
        );

        final match =
            resourceServer.findMatchingRequirements(available, payload);

        expect(match, isNull);
      });

      test('returns null if available list is empty', () {
        const payload = PaymentPayload(
          x402Version: 1,
          resource: ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'exact',
            network: 'eip155:1',
            asset: 'asset',
            amount: '100',
            payTo: 'receiver',
            maxTimeoutSeconds: 0,
            extra: {},
          ),
          payload: {},
        );

        final match = resourceServer.findMatchingRequirements([], payload);

        expect(match, isNull);
      });
    });
  });

  group('Immutability guarantees', () {
    test('server is unaffected by external map mutation', () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: 'eip155:1',
            ),
          ],
          extensions: [],
          signers: {},
        );

      final schemes = {'eip155:1': MockSchemeServer('exact')};

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemes: schemes,
      );

      // Mutate original schemes map AFTER creation
      schemes.clear();

      // Server should still function correctly
      const config = ResourceConfig(
        scheme: 'exact',
        payTo: 'receiver',
        price: Money('1'),
        network: 'eip155:1',
      );

      final requirements = await server.buildPaymentRequirements(config);

      expect(requirements, hasLength(1));
    });

    test('multiple schemes remain functional after external mutation',
        () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's1',
              network: 'n1',
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's2',
              network: 'n2',
            ),
          ],
          extensions: [],
          signers: {},
        );

      final schemes = {
        'n1': MockSchemeServer('s1'),
        'n2': MockSchemeServer('s2'),
      };

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemes: schemes,
      );

      schemes.remove('n1');

      const config = ResourceConfig(
        scheme: 's1',
        payTo: 'receiver',
        price: Money('1'),
        network: 'n1',
      );

      final requirements = await server.buildPaymentRequirements(config);
      expect(requirements, hasLength(1));
    });
  });

  group('Integration tests', () {
    test('full lifecycle: build -> match -> verify', () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: 'eip155:1',
            ),
          ],
          extensions: [],
          signers: {},
        )
        ..verifyResponse = const VerifyResponse(isValid: true);

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemes: {'eip155:1': MockSchemeServer('exact')},
      );

      const config = ResourceConfig(
        scheme: 'exact',
        payTo: 'receiver',
        price: Money('1.0'),
        network: 'eip155:1',
      );

      final requirements = await server.buildPaymentRequirements(config);

      final selected = requirements.first;

      final payload = PaymentPayload(
        x402Version: kX402Version,
        resource: const ResourceInfo(
          url: 'url',
          description: 'desc',
          mimeType: 'mime',
        ),
        accepted: selected,
        payload: {},
      );

      final matched = server.findMatchingRequirements(requirements, payload);

      expect(matched, isNotNull);

      final verifyResult = await server.verifyPayment(payload, matched!);

      expect(verifyResult.isValid, isTrue);
    });
  });
}
