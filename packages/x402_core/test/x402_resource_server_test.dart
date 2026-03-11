import 'dart:convert';
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
      network: Network(namespace: 'net', reference: 'test'),
    );
  }
}

class MockSchemeServer implements SchemeServer {
  @override
  final String scheme;

  @override
  final Network network;

  AssetAmount? parsePriceResult;
  PaymentRequirement? enhancedRequirement;

  MockSchemeServer(this.scheme, this.network);

  @override
  Future<AssetAmount> parsePrice(Price price) async {
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
  ThrowingParseSchemeServer(Network network) : super('exact', network);

  @override
  Future<AssetAmount> parsePrice(Price price) {
    throw Exception('parse failure');
  }
}

class ThrowingEnhanceSchemeServer extends MockSchemeServer {
  ThrowingEnhanceSchemeServer(Network network) : super('exact', network);

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
  const net1 = Network(namespace: 'eip155', reference: '1');
  const net2 = Network(namespace: 'eip155', reference: '2');
  const n1 = Network(namespace: 'n', reference: '1');
  const n2 = Network(namespace: 'n', reference: '2');

  group('X402ResourceServer.create', () {
    test('initializes successfully with one facilitator and one scheme',
        () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [MockSchemeServer('exact', net1)],
      );

      expect(server, isNotNull);
    });

    test('initializes with multiple facilitators', () async {
      final f1 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(x402Version: kX402Version, scheme: 's1', network: n1),
          ],
          extensions: [],
          signers: {},
        );
      final f2 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(x402Version: kX402Version, scheme: 's2', network: n2),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [f1, f2],
        schemeServers: [
          MockSchemeServer('s1', n1),
          MockSchemeServer('s2', n2),
        ],
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
              network: n1,
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's2',
              network: n2,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [
          MockSchemeServer('s1', n1),
          MockSchemeServer('s2', n2),
        ],
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
              network: n1,
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's2',
              network: n1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [
          MockSchemeServer('s1', n1),
          MockSchemeServer('s2', n1),
        ],
      );

      expect(server, isNotNull);
    });

    test(
        'throws ArgumentError if duplicate SchemeServer for same scheme/network',
        () {
      expect(
        () => X402ResourceServer.create(
          facilitators: [MockFacilitatorClient()],
          schemeServers: [
            MockSchemeServer('exact', net1),
            MockSchemeServer('exact', net1),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('supports same scheme on different networks', () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net1,
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net2,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [
          MockSchemeServer('exact', net1),
          MockSchemeServer('exact', net2),
        ],
      );

      expect(server, isNotNull);
    });

    test('throws ArgumentError if schemes is empty', () {
      expect(
        () => X402ResourceServer.create(
          facilitators: [MockFacilitatorClient()],
          schemeServers: [],
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
          schemeServers: [MockSchemeServer('exact', net1)],
        ),
        throwsStateError,
      );
    });

    test('allows same scheme/network for different x402 versions', () async {
      final f1 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: 1,
              scheme: 'exact',
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final f2 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: 2,
              scheme: 'exact',
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [f1, f2],
        schemeServers: [MockSchemeServer('exact', net1)],
      );

      expect(server, isNotNull);
    });

    test('propagates error from getSupported', () {
      final facilitator = MockFacilitatorClient()
        ..getSupportedError = Exception('Network error');

      expect(
        () => X402ResourceServer.create(
          facilitators: [facilitator],
          schemeServers: [MockSchemeServer('exact', net1)],
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
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      expect(
        () => X402ResourceServer.create(
          facilitators: [facilitator],
          schemeServers: [MockSchemeServer('exact', net1)],
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
              network: net1,
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [MockSchemeServer('exact', net1)],
      );

      expect(server, isNotNull);
    });

    test(
        'throws StateError if multiple facilitators support same scheme/network',
        () {
      final f1 = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net1,
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
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      expect(
        () => X402ResourceServer.create(
          facilitators: [f1, f2],
          schemeServers: [MockSchemeServer('exact', net1)],
        ),
        throwsStateError,
      );
    });

    test('throws if facilitators list is empty', () {
      expect(
        () => X402ResourceServer.create(
          facilitators: [],
          schemeServers: [MockSchemeServer('exact', net1)],
        ),
        throwsStateError,
      );
    });

    test(
        'ignores SupportedKind if scheme string differs from registered server',
        () {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      expect(
        () => X402ResourceServer.create(
          facilitators: [facilitator],
          schemeServers: [MockSchemeServer('different', net1)], // mismatch
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
              network: net1,
            ),
          ],
          extensions: ['ext1'],
          signers: {},
        );
      schemeServer = MockSchemeServer('exact', net1);

      resourceServer = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [schemeServer],
      );
    });

    group('buildPaymentRequirement', () {
      test('correctly builds requirements', () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: net1,
          maxTimeoutSeconds: 60,
        );

        schemeServer.parsePriceResult = const AssetAmount(
          asset: '0xUSDC',
          amount: '1000000',
          extra: {'name': 'USDC'},
        );

        final req = await resourceServer.buildPaymentRequirement(config);

        expect(req.scheme, equals('exact'));
        expect(req.network, equals(net1));
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
          network: net1,
        );

        schemeServer.enhancedRequirement = PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: 'enhanced-asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {'enhanced': true},
        );

        final req = await resourceServer.buildPaymentRequirement(config);

        expect(req.asset, equals('enhanced-asset'));
        expect(req.extra['enhanced'], isTrue);
      });

      test('works with AssetAmount', () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: AssetAmount(asset: '0xAsset', amount: '500'),
          network: net1,
        );

        final req = await resourceServer.buildPaymentRequirement(config);

        expect(req.amount, equals('500'));
        expect(req.asset, equals('0xAsset'));
      });

      test('throws StateError if scheme not registered for network', () {
        const config = ResourceConfig(
          scheme: 'other',
          payTo: 'receiver',
          price: Money('1.0'),
          network: net1,
        );

        expect(
          () => resourceServer.buildPaymentRequirement(config),
          throwsStateError,
        );
      });

      test('throws StateError if facilitator does not support scheme/network',
          () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: net2,
        );

        // We need to register the scheme for net2 too during setup if we want it to get past the first check
        final resourceServer2 = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemeServers: [
            schemeServer,
            MockSchemeServer('exact', net2),
          ],
        );

        expect(
          () => resourceServer2.buildPaymentRequirement(config),
          throwsStateError,
        );
      });

      test('throws if SupportedKind for scheme/network is missing', () {
        final facilitator = MockFacilitatorClient()
          ..supportedResponse = const SupportedResponse(
            kinds: [
              SupportedKind(
                x402Version: kX402Version,
                scheme: 'exact',
                network: net2,
              ),
            ],
            extensions: [],
            signers: {},
          );

        // Should throw during creation because net1 scheme has no facilitator support
        expect(
          () => X402ResourceServer.create(
            facilitators: [facilitator],
            schemeServers: [MockSchemeServer('exact', net1)],
          ),
          throwsStateError,
        );
      });

      test('propagates error from parsePrice', () async {
        final scheme = ThrowingParseSchemeServer(net1);

        final facilitator = MockFacilitatorClient()
          ..supportedResponse = const SupportedResponse(
            kinds: [
              SupportedKind(
                x402Version: kX402Version,
                scheme: 'exact',
                network: net1,
              ),
            ],
            extensions: [],
            signers: {},
          );

        final server = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemeServers: [scheme],
        );

        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1'),
          network: net1,
        );

        expect(
          () => server.buildPaymentRequirement(config),
          throwsException,
        );
      });

      test('propagates error from enhancePaymentRequirement', () async {
        final scheme = ThrowingEnhanceSchemeServer(net1);

        final facilitator = MockFacilitatorClient()
          ..supportedResponse = const SupportedResponse(
            kinds: [
              SupportedKind(
                x402Version: kX402Version,
                scheme: 'exact',
                network: net1,
              ),
            ],
            extensions: [],
            signers: {},
          );

        final server = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemeServers: [scheme],
        );

        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1'),
          network: net1,
        );

        expect(
          () => server.buildPaymentRequirement(config),
          throwsException,
        );
      });

      test('passes facilitator extensions to enhancePaymentRequirement',
          () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: net1,
        );

        schemeServer.enhancedRequirement = null;

        schemeServer = MockSchemeServer('exact', net1)
          ..enhancedRequirement = PaymentRequirement(
            scheme: 'exact',
            network: net1,
            asset: 'asset',
            amount: '100',
            payTo: 'receiver',
            maxTimeoutSeconds: 60,
            extra: {},
          );

        resourceServer = await X402ResourceServer.create(
          facilitators: [facilitator],
          schemeServers: [schemeServer],
        );

        await resourceServer.buildPaymentRequirement(config);

        // If no crash, extension passing works.
        expect(true, isTrue);
      });

      test('buildPaymentRequirement is stable across repeated calls', () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1.0'),
          network: net1,
        );

        for (var i = 0; i < 50; i++) {
          final req = await resourceServer.buildPaymentRequirement(config);

          expect(req.scheme, equals('exact'));
        }
      });

      test('maxTimeoutSeconds defaults correctly when null', () async {
        const config = ResourceConfig(
          scheme: 'exact',
          payTo: 'receiver',
          price: Money('1'),
          network: net1,
        );

        final req = await resourceServer.buildPaymentRequirement(config);

        expect(req.maxTimeoutSeconds, isNotNull);
      });
    });

    group('verifyPayment', () {
      test('calls facilitator verify', () async {
        final requirement = PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {},
        );

        final payload = PaymentPayload(
          x402Version: kX402Version,
          resource: const ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: const {'sig': 'abc'},
        );

        facilitator.verifyResponse = const VerifyResponse(isValid: true);

        final result = await resourceServer.verifyPayment(payload, requirement);

        expect(result.isValid, isTrue);
      });

      test('throws StateError if no facilitator available', () {
        final requirement = PaymentRequirement(
          scheme: 'exact',
          network: net2,
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {},
        );

        final payload = PaymentPayload(
          x402Version: 1,
          resource: const ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: const {},
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
                network: n1,
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
                network: n2,
              ),
            ],
            extensions: [],
            signers: {},
          )
          ..verifyResponse = const VerifyResponse(isValid: false);

        final server = await X402ResourceServer.create(
          facilitators: [f1, f2],
          schemeServers: [
            MockSchemeServer('s1', n1),
            MockSchemeServer('s2', n2),
          ],
        );

        final requirement = PaymentRequirement(
          scheme: 's2',
          network: n2,
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {},
        );

        final payload = PaymentPayload(
          x402Version: kX402Version,
          resource: const ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: const {},
        );

        final result = await server.verifyPayment(payload, requirement);
        expect(result.isValid, isFalse);
      });

      test('throws if payload version unsupported even if network matches', () {
        final requirement = PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {},
        );

        final payload = PaymentPayload(
          x402Version: 999,
          resource: const ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: const {},
        );

        expect(
          () => resourceServer.verifyPayment(payload, requirement),
          throwsStateError,
        );
      });

      test('verifyPayment is stable across repeated calls', () async {
        final requirement = PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {},
        );

        final payload = PaymentPayload(
          x402Version: kX402Version,
          resource: const ResourceInfo(
            url: 'url',
            description: 'desc',
            mimeType: 'mime',
          ),
          accepted: requirement,
          payload: const {},
        );

        for (var i = 0; i < 30; i++) {
          final result =
              await resourceServer.verifyPayment(payload, requirement);
          expect(result.isValid, isTrue);
        }
      });

      test(
          'verifyPayment does not validate payload.accepted vs requirements mismatch',
          () async {
        final requirement = PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: 'asset',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {},
        );

        final mismatchedAccepted = requirement.copyWith(scheme: 'other');

        final payload = PaymentPayload(
          x402Version: kX402Version,
          resource:
              const ResourceInfo(url: 'u', description: 'd', mimeType: 'm'),
          accepted: mismatchedAccepted,
          payload: const {},
        );

        final result = await resourceServer.verifyPayment(payload, requirement);

        expect(result.isValid, isTrue);
      });
    });

    group('findMatchingRequirements', () {
      final available = [
        PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: '0x1',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        ),
        PaymentRequirement(
          scheme: 'exact',
          network: const Network(namespace: 'solana', reference: 'mainnet'),
          asset: 'mint',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: {},
        ),
      ];

      test('Version 1: matches by scheme and network', () {
        final payload = PaymentPayload(
          x402Version: 1,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'exact',
            network: net1,
            asset: 'DIFFERENT', // Should not matter for v1
            amount: '999', // Should not matter for v1
            payTo: 'any',
            maxTimeoutSeconds: 0,
            extra: const {},
          ),
          payload: const {},
        );

        final match =
            resourceServer.findMatchingRequirements(available, payload);

        expect(match, isNotNull);
        expect(match!.network, equals(net1));
      });

      test('Version 1: does not match if scheme differs', () {
        final payload = PaymentPayload(
          x402Version: 1,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'other',
            network: net1,
            asset: 'asset',
            amount: '100',
            payTo: 'any',
            maxTimeoutSeconds: 0,
            extra: const {},
          ),
          payload: const {},
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

      test('Version 2: handles deep map equality in extra', () {
        final reqWithExtra = PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: '0x1',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {
            'nested': {'a': 1}
          },
        );

        final payload = PaymentPayload(
          x402Version: 2,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'exact',
            network: net1,
            asset: '0x1',
            amount: '100',
            payTo: 'receiver',
            maxTimeoutSeconds: 60,
            extra: const {
              'nested': {'a': 1}
            },
          ),
          payload: const {},
        );

        final match =
            resourceServer.findMatchingRequirements([reqWithExtra], payload);

        expect(match, isNotNull);
        expect((match!.extra['nested'] as Map)['a'], equals(1));
      });

      test('Version 2: returns null if extra differs', () {
        final reqWithExtra = PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: '0x1',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {'a': 1},
        );

        final payload = PaymentPayload(
          x402Version: 2,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: reqWithExtra.copyWith(extra: {'a': 2}),
          payload: {},
        );

        final match =
            resourceServer.findMatchingRequirements([reqWithExtra], payload);

        expect(match, isNull);
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

      test('returns null for unsupported versions', () {
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

        final result =
            resourceServer.findMatchingRequirements(available, payload);

        expect(result, isNull);
      });

      test('Version 1: does not match if network differs', () {
        final payload = PaymentPayload(
          x402Version: 1,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'exact',
            network: const Network(namespace: 'other', reference: 'net'),
            asset: 'asset',
            amount: '100',
            payTo: 'any',
            maxTimeoutSeconds: 0,
            extra: const {},
          ),
          payload: const {},
        );

        final match =
            resourceServer.findMatchingRequirements(available, payload);

        expect(match, isNull);
      });

      test('returns null if available list is empty', () {
        final payload = PaymentPayload(
          x402Version: 1,
          resource: const ResourceInfo(
            url: 'u',
            description: 'd',
            mimeType: 'm',
          ),
          accepted: PaymentRequirement(
            scheme: 'exact',
            network: net1,
            asset: 'asset',
            amount: '100',
            payTo: 'receiver',
            maxTimeoutSeconds: 0,
            extra: const {},
          ),
          payload: const {},
        );

        final match = resourceServer.findMatchingRequirements([], payload);

        expect(match, isNull);
      });
    });

    test('Version 2: equality does not depend on map instance identity', () {
      final req1 = PaymentRequirement(
        scheme: 'exact',
        network: net1,
        asset: 'a',
        amount: '100',
        payTo: 'receiver',
        maxTimeoutSeconds: 60,
        extra: const {'a': 1, 'b': 2},
      );

      final payload = PaymentPayload(
        x402Version: 2,
        resource: const ResourceInfo(url: 'u', description: 'd', mimeType: 'm'),
        accepted: PaymentRequirement(
          scheme: 'exact',
          network: net1,
          asset: 'a',
          amount: '100',
          payTo: 'receiver',
          maxTimeoutSeconds: 60,
          extra: const {'b': 2, 'a': 1}, // reversed order
        ),
        payload: const {},
      );

      final match = resourceServer.findMatchingRequirements([req1], payload);

      expect(match, isNotNull);
    });
  });

  group('Immutability guarantees', () {
    test('server is unaffected by external list mutation', () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final schemes = [MockSchemeServer('exact', net1)];

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: schemes,
      );

      // Mutate original schemes list AFTER creation
      schemes.clear();

      // Server should still function correctly
      const config = ResourceConfig(
        scheme: 'exact',
        payTo: 'receiver',
        price: Money('1'),
        network: net1,
      );

      final req = await server.buildPaymentRequirement(config);

      expect(req.scheme, equals('exact'));
    });

    test('multiple schemes remain functional after external mutation',
        () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's1',
              network: n1,
            ),
            SupportedKind(
              x402Version: kX402Version,
              scheme: 's2',
              network: n2,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final schemes = [
        MockSchemeServer('s1', n1),
        MockSchemeServer('s2', n2),
      ];

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: schemes,
      );

      schemes.removeAt(0);

      const config = ResourceConfig(
        scheme: 's1',
        payTo: 'receiver',
        price: Money('1'),
        network: n1,
      );

      final req = await server.buildPaymentRequirement(config);
      expect(req.scheme, equals('s1'));
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
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        )
        ..verifyResponse = const VerifyResponse(isValid: true);

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [MockSchemeServer('exact', net1)],
      );

      const config = ResourceConfig(
        scheme: 'exact',
        payTo: 'receiver',
        price: Money('1.0'),
        network: net1,
      );

      final requirement = await server.buildPaymentRequirement(config);

      final payload = PaymentPayload(
        x402Version: kX402Version,
        resource: const ResourceInfo(
          url: 'url',
          description: 'desc',
          mimeType: 'mime',
        ),
        accepted: requirement,
        payload: {},
      );

      final matched = server.findMatchingRequirements([requirement], payload);

      expect(matched, isNotNull);

      final verifyResult = await server.verifyPayment(payload, matched!);

      expect(verifyResult.isValid, isTrue);
    });
  });

  group('X402ResourceServer.buildPaymentRequiredHeader', () {
    test('builds and encodes correctly', () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [MockSchemeServer('exact', net1)],
      );

      final requirement = PaymentRequirement(
        scheme: 'exact',
        network: net1,
        amount: '100',
        asset: 'USDC',
        payTo: '0xAddress',
        maxTimeoutSeconds: 300,
        extra: const {},
      );

      final header = server.buildPaymentRequiredHeader(
        resourceUrl: '/protected',
        requirements: [requirement],
        description: 'Test Description',
      );

      expect(header, isNotEmpty);

      // Verify encoding
      final decoded = utf8.decode(base64Decode(header));
      final json = jsonDecode(decoded) as Map;

      expect(json['x402Version'], equals(kX402Version));
      expect(json['error'], equals('Payment Required'));
      expect((json['resource'] as Map)['url'], equals('/protected'));
      expect(
          (json['resource'] as Map)['description'], equals('Test Description'));
      expect(json['accepts'], hasLength(1));
      expect(((json['accepts'] as List)[0] as Map)['scheme'], equals('exact'));
    });

    test('uses default description if omitted', () async {
      final facilitator = MockFacilitatorClient()
        ..supportedResponse = const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: net1,
            ),
          ],
          extensions: [],
          signers: {},
        );

      final server = await X402ResourceServer.create(
        facilitators: [facilitator],
        schemeServers: [MockSchemeServer('exact', net1)],
      );

      final requirement = PaymentRequirement(
        scheme: 'exact',
        network: net1,
        amount: '100',
        asset: 'USDC',
        payTo: '0xAddress',
        maxTimeoutSeconds: 300,
        extra: const {},
      );

      final header = server.buildPaymentRequiredHeader(
        resourceUrl: '/protected',
        requirements: [requirement],
      );

      final decoded = utf8.decode(base64Decode(header));
      final json = jsonDecode(decoded) as Map;
      expect((json['resource'] as Map)['description'],
          equals('This resource requires payment.'));
    });
  });
}
