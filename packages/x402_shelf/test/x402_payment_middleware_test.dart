import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_shelf/x402_shelf.dart';

class MockFacilitatorClient implements FacilitatorClient {
  SupportedResponse? supportedResponse;
  VerifyResponse? verifyResponse;

  @override
  Future<SupportedResponse> getSupported() async {
    return supportedResponse ??
        const SupportedResponse(
          kinds: [
            SupportedKind(
              x402Version: kX402Version,
              scheme: 'exact',
              network: Network(namespace: 'eip155', reference: '1'),
            )
          ],
          extensions: [],
          signers: {},
        );
  }

  @override
  Future<VerifyResponse> verify(
    PaymentPayload paymentPayload,
    PaymentRequirement paymentRequirement,
  ) async {
    if (paymentPayload.payload['signature'] == 'throw') {
      throw Exception('Verification error');
    }
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

  MockSchemeServer(this.scheme, this.network);

  @override
  Future<AssetAmount> parsePrice(Price price) async {
    if (price is AssetAmount) return price;
    return const AssetAmount(asset: 'USDC', amount: '1000000');
  }

  @override
  Future<PaymentRequirement> enhancePaymentRequirement(
    PaymentRequirement paymentRequirement, {
    required SupportedKind kind,
    List<String> facilitatorExtensions = const [],
  }) async {
    return paymentRequirement;
  }
}

void main() {
  const network = Network(namespace: 'eip155', reference: '1');
  late X402ResourceServer resourceServer;
  late MockFacilitatorClient facilitator;

  setUp(() async {
    facilitator = MockFacilitatorClient();
    resourceServer = await X402ResourceServer.create(
      facilitators: [facilitator],
      schemeServers: [MockSchemeServer('exact', network)],
    );
  });

  group('x402PaymentMiddleware', () {
    final routes = {
      const RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
        accepts: [
          const PaymentOption(
            scheme: 'exact',
            price: AssetAmount(asset: 'USDC', amount: '100'),
            network: network,
            payTo: '0xAddress',
          ),
        ],
      ),
    };

    Response innerHandler(Request request) => Response.ok('Success');

    PaymentRequiredResponse decodePaymentRequired(Response response) {
      final header = response.headers[kPaymentRequiredHeader];
      if (header == null) {
        throw Exception('Missing $kPaymentRequiredHeader header');
      }
      final decoded = utf8.decode(base64Decode(header));
      return PaymentRequiredResponse.fromJson(
          jsonDecode(decoded) as Map<String, dynamic>);
    }

    test('passes through when no routes are configured', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware({}, resourceServer))
          .addHandler(innerHandler);

      final request = Request('GET', Uri.parse('http://localhost/protected'));
      final response = await handler(request);

      expect(response.statusCode, 200);
    });

    test('allows unprotected routes to pass through', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final request = Request('GET', Uri.parse('http://localhost/unprotected'));
      final response = await handler(request);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'Success');
    });

    test('returns 402 Payment Required for protected routes without header',
        () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final request = Request('GET', Uri.parse('http://localhost/protected'));
      final response = await handler(request);

      expect(response.statusCode, 402);
      expect(response.headers[kPaymentRequiredHeader], isNotNull);

      final paymentRequired = decodePaymentRequired(response);
      expect(paymentRequired.error, 'Payment Required');
      expect(paymentRequired.resource.url, '/protected');
      expect(paymentRequired.accepts, isNotEmpty);

      // Body should be empty JSON
      expect(await response.readAsString(), '');
    });

    test('returns 402 for invalid payload header', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': 'not-json'},
      );
      final response = await handler(request);

      expect(response.statusCode, 402);
      expect(await response.readAsString(), '');
    });

    test('returns 402 when payload does not match requirements', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final requirement = await resourceServer.buildPaymentRequirement(
        const ResourceConfig(
          scheme: 'exact',
          network: network,
          price: AssetAmount(asset: 'USDC', amount: '100'),
          payTo: '0xAddress',
        ),
      );

      final payload = PaymentPayload(
        x402Version: kX402Version,
        resource: const ResourceInfo(
          url: '/protected',
          description: '',
          mimeType: '',
        ),
        accepted: requirement.copyWith(scheme: 'other'),
        payload: {'signature': 'proof'},
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': jsonEncode(payload.toJson())},
      );
      final response = await handler(request);

      expect(response.statusCode, 402);
      expect(await response.readAsString(), '');
    });

    test('returns 402 when verification fails', () async {
      facilitator.verifyResponse = const VerifyResponse(
        isValid: false,
        invalidReason: 'Invalid proof',
      );

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final requirement = await resourceServer.buildPaymentRequirement(
        const ResourceConfig(
          scheme: 'exact',
          network: network,
          price: AssetAmount(asset: 'USDC', amount: '100'),
          payTo: '0xAddress',
        ),
      );

      final payload = PaymentPayload(
        x402Version: kX402Version,
        resource: const ResourceInfo(
          url: '/protected',
          description: '',
          mimeType: '',
        ),
        accepted: requirement,
        payload: {'signature': 'invalid-proof'},
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': jsonEncode(payload.toJson())},
      );
      final response = await handler(request);

      expect(response.statusCode, 402);
      expect(await response.readAsString(), '');
    });

    test('allows access when payment is valid and verified', () async {
      facilitator.verifyResponse = const VerifyResponse(isValid: true);

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final requirement = await resourceServer.buildPaymentRequirement(
        const ResourceConfig(
          scheme: 'exact',
          network: network,
          price: AssetAmount(asset: 'USDC', amount: '100'),
          payTo: '0xAddress',
        ),
      );

      final payload = PaymentPayload(
        x402Version: kX402Version,
        resource: const ResourceInfo(
          url: '/protected',
          description: '',
          mimeType: '',
        ),
        accepted: requirement,
        payload: {'signature': 'valid-proof'},
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': jsonEncode(payload.toJson())},
      );
      final response = await handler(request);

      expect(response.statusCode, 200);
      expect(await response.readAsString(), 'Success');
    });

    test('supports different HTTP methods', () async {
      final postRoutes = {
        const RoutePattern(HttpMethod.post, '/submit'): RouteConfig(
          accepts: [
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'USDC', amount: '50'),
              network: network,
              payTo: '0xAddress',
            ),
          ],
        ),
      };

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(postRoutes, resourceServer))
          .addHandler(innerHandler);

      final request = Request('POST', Uri.parse('http://localhost/submit'));
      final response = await handler(request);

      expect(response.statusCode, 402);
      final paymentRequired = decodePaymentRequired(response);
      expect(paymentRequired.resource.url, '/submit');
    });

    test('method-specific route protection works correctly', () async {
      final postRoutes = {
        const RoutePattern(HttpMethod.post, '/submit'): RouteConfig(
          accepts: [
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'USDC', amount: '50'),
              network: network,
              payTo: '0xAddress',
            ),
          ],
        ),
      };

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(postRoutes, resourceServer))
          .addHandler(innerHandler);

      final getRequest = Request('GET', Uri.parse('http://localhost/submit'));
      final postRequest = Request('POST', Uri.parse('http://localhost/submit'));

      final getResponse = await handler(getRequest);
      final postResponse = await handler(postRequest);

      expect(getResponse.statusCode, 200);
      expect(postResponse.statusCode, 402);
    });

    test('is sensitive to trailing slashes by default', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      // Route is registered as '/protected'
      final request = Request('GET', Uri.parse('http://localhost/protected/'));
      final response = await handler(request);

      // Should pass through to innerHandler (200) because it doesn't match the protected route exactly
      expect(response.statusCode, 200);
    });

    test('matches routes without leading slash in registration', () async {
      final oddRoutes = {
        const RoutePattern(HttpMethod.get, 'no-slash'): RouteConfig(
          accepts: [
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'USDC', amount: '10'),
              network: network,
              payTo: '0xAddress',
            ),
          ],
        ),
      };

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(oddRoutes, resourceServer))
          .addHandler(innerHandler);

      final request = Request('GET', Uri.parse('http://localhost/no-slash'));
      final response = await handler(request);

      expect(response.statusCode, 402);
    });

    test('bubbles up exceptions from verification', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final requirement = await resourceServer.buildPaymentRequirement(
        const ResourceConfig(
          scheme: 'exact',
          network: network,
          price: AssetAmount(asset: 'USDC', amount: '100'),
          payTo: '0xAddress',
        ),
      );

      final payload = PaymentPayload(
        x402Version: kX402Version,
        resource: const ResourceInfo(
          url: '/protected',
          description: '',
          mimeType: '',
        ),
        accepted: requirement,
        payload: {'signature': 'throw'},
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': jsonEncode(payload.toJson())},
      );

      expect(() => handler(request), throwsA(isA<Exception>()));
    });

    test('returns 402 for invalid payload JSON', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {
          'x-payment-proof': jsonEncode({'invalid': 'payload'})
        },
      );
      final response = await handler(request);

      expect(response.statusCode, 402);
    });

    test('returns custom description in 402 response', () async {
      const description = 'Custom description for this resource';
      final descRoutes = {
        const RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
          accepts: [
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'USDC', amount: '100'),
              network: network,
              payTo: '0xAddress',
            ),
          ],
          description: description,
        ),
      };

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(descRoutes, resourceServer))
          .addHandler(innerHandler);

      final request = Request('GET', Uri.parse('http://localhost/protected'));
      final response = await handler(request);

      final paymentRequired = decodePaymentRequired(response);
      expect(paymentRequired.resource.description, description);
    });

    test('handles multiple payment options', () async {
      const network2 = Network(namespace: 'solana', reference: 'mainnet');

      final multiRoutes = {
        const RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
          accepts: [
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'USDC', amount: '100'),
              network: network,
              payTo: '0xAddress',
            ),
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'SOL', amount: '1'),
              network: network2,
              payTo: 'SolAddress',
            ),
          ],
        ),
      };

      final server = await X402ResourceServer.create(
        facilitators: [
          facilitator,
          MockFacilitatorClient()
            ..supportedResponse = const SupportedResponse(
              kinds: [
                SupportedKind(
                  x402Version: kX402Version,
                  scheme: 'exact',
                  network: network2,
                )
              ],
              extensions: [],
              signers: {},
            )
        ],
        schemeServers: [
          MockSchemeServer('exact', network),
          MockSchemeServer('exact', network2),
        ],
      );

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(multiRoutes, server))
          .addHandler(innerHandler);

      final request = Request('GET', Uri.parse('http://localhost/protected'));
      final response = await handler(request);

      expect(response.statusCode, 402);
      final paymentRequired = decodePaymentRequired(response);
      final accepts = paymentRequired.accepts;
      expect(accepts, hasLength(2));
      expect(accepts[0].network.identifier, 'eip155:1');
      expect(accepts[1].network.identifier, 'solana:mainnet');
    });

    test('returns 402 when header is empty string', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': ''},
      );

      final response = await handler(request);
      expect(response.statusCode, 402);
    });

    test('returns 402 when x402Version does not match', () async {
      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
          .addHandler(innerHandler);

      final requirement = await resourceServer.buildPaymentRequirement(
        const ResourceConfig(
          scheme: 'exact',
          network: network,
          price: AssetAmount(asset: 'USDC', amount: '100'),
          payTo: '0xAddress',
        ),
      );

      final payload = PaymentPayload(
        x402Version: 999, // wrong version
        resource: const ResourceInfo(
          url: '/protected',
          description: '',
          mimeType: '',
        ),
        accepted: requirement,
        payload: {'signature': 'valid-proof'},
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': jsonEncode(payload.toJson())},
      );

      final response = await handler(request);
      expect(response.statusCode, 402);
    });

    test('uses first matching requirement when multiple match', () async {
      const networkSame = Network(namespace: 'eip155', reference: '1');

      final orderedRoutes = {
        const RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
          accepts: [
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'USDC', amount: '100'),
              network: networkSame,
              payTo: '0xFirst',
            ),
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'USDC', amount: '100'),
              network: networkSame,
              payTo: '0xSecond',
            ),
          ],
        ),
      };

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(orderedRoutes, resourceServer))
          .addHandler(innerHandler);

      final firstRequirement = await resourceServer.buildPaymentRequirement(
        const ResourceConfig(
          scheme: 'exact',
          network: networkSame,
          price: AssetAmount(asset: 'USDC', amount: '100'),
          payTo: '0xFirst',
        ),
      );

      final payload = PaymentPayload(
        x402Version: kX402Version,
        resource: const ResourceInfo(
          url: '/protected',
          description: '',
          mimeType: '',
        ),
        accepted: firstRequirement,
        payload: {'signature': 'valid-proof'},
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': jsonEncode(payload.toJson())},
      );

      final response = await handler(request);
      expect(response.statusCode, 200);
    });

    test('uses second payment option if first does not match', () async {
      const network2 = Network(namespace: 'solana', reference: 'mainnet');

      final multiRoutes = {
        const RoutePattern(HttpMethod.get, '/protected'): RouteConfig(
          accepts: [
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'USDC', amount: '100'),
              network: network,
              payTo: '0xFirst',
            ),
            const PaymentOption(
              scheme: 'exact',
              price: AssetAmount(asset: 'SOL', amount: '1'),
              network: network2,
              payTo: 'SolAddress',
            ),
          ],
        ),
      };

      final server = await X402ResourceServer.create(
        facilitators: [
          facilitator,
          MockFacilitatorClient()
            ..supportedResponse = const SupportedResponse(
              kinds: [
                SupportedKind(
                  x402Version: kX402Version,
                  scheme: 'exact',
                  network: network2,
                )
              ],
              extensions: [],
              signers: {},
            )
        ],
        schemeServers: [
          MockSchemeServer('exact', network),
          MockSchemeServer('exact', network2),
        ],
      );

      final handler = const Pipeline()
          .addMiddleware(x402PaymentMiddleware(multiRoutes, server))
          .addHandler(innerHandler);

      final requirement = await server.buildPaymentRequirement(
        const ResourceConfig(
          scheme: 'exact',
          network: network2,
          price: AssetAmount(asset: 'SOL', amount: '1'),
          payTo: 'SolAddress',
        ),
      );

      final payload = PaymentPayload(
        x402Version: kX402Version,
        resource: const ResourceInfo(
          url: '/protected',
          description: '',
          mimeType: '',
        ),
        accepted: requirement,
        payload: {'signature': 'valid-proof'},
      );

      final request = Request(
        'GET',
        Uri.parse('http://localhost/protected'),
        headers: {'x-payment-proof': jsonEncode(payload.toJson())},
      );

      final response = await handler(request);
      expect(response.statusCode, 200);
    });

    group('V2 Protocol Compliance', () {
      test('strictly returns empty body and header-based requirement',
          () async {
        final handler = const Pipeline()
            .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
            .addHandler(innerHandler);

        final request = Request('GET', Uri.parse('http://localhost/protected'));
        final response = await handler(request);

        expect(response.statusCode, 402);

        // MUST NOT have legacy header
        expect(response.headers['x-accepts-payment'], isNull);

        // MUST have V2 header
        final header = response.headers[kPaymentRequiredHeader];
        expect(header, isNotNull);

        // MUST be valid Base64 encoded JSON
        final decoded = utf8.decode(base64Decode(header!));
        final json = jsonDecode(decoded) as Map<String, dynamic>;
        expect(json['x402Version'], 2);
        expect(json['error'], 'Payment Required');
        final resource = json['resource'] as Map<String, dynamic>;
        expect(resource['url'], '/protected');
        expect(json['accepts'], isNotEmpty);

        // MUST have empty body
        expect(await response.readAsString(), '');
      });

      test('normalizes resource URL in header', () async {
        final handler = const Pipeline()
            .addMiddleware(x402PaymentMiddleware(routes, resourceServer))
            .addHandler(innerHandler);

        // Request with path only, no leading slash in url object sometimes (shelf handles this)
        final request = Request('GET', Uri.parse('http://localhost/protected'));
        final response = await handler(request);

        final paymentRequired = decodePaymentRequired(response);
        expect(paymentRequired.resource.url, '/protected');
      });
    });
  });
}
