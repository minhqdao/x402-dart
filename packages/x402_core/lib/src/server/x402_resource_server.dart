import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/models/payment_payload.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_config.dart';
import 'package:x402_core/src/models/supported_response.dart';
import 'package:x402_core/src/models/verify_response.dart';
import 'package:x402_core/src/server/facilitator_client.dart';
import 'package:x402_core/src/server/http_facilitator_client.dart';
import 'package:x402_core/src/server/scheme_server.dart';

/// Main entry point for protecting resources with x402 payments.
///
/// `X402ResourceServer` helps you require and verify payments
/// before granting access to a protected resource.
///
/// It does not depend on a specific web framework or transport.
/// You can use it with HTTP servers, RPC handlers, or custom
/// backends.
///
/// With this class, you can:
/// - Define which payment schemes and networks you support
/// - Generate payment requirements for a resource
/// - Verify incoming payments
/// - Handle the full settlement lifecycle
///
/// In short, this is the component that connects your protected
/// resource to the x402 payment flow.
class X402ResourceServer {
  final Map<String, Map<String, SchemeServer>> _registeredSchemes;
  final Map<int, Map<String, Map<String, SupportedResponse>>> _supportedMap;
  final Map<int, Map<String, Map<String, FacilitatorClient>>> _clientMap;

  X402ResourceServer._({
    required Map<String, SchemeServer> schemes,
    required Map<int, Map<String, Map<String, SupportedResponse>>> supported,
    required Map<int, Map<String, Map<String, FacilitatorClient>>> clients,
  })  : _registeredSchemes = _registerSchemes(schemes),
        _supportedMap = _buildImmutableSupportedMap(supported),
        _clientMap = _buildImmutableClientMap(clients);

  static Map<String, Map<String, SchemeServer>> _registerSchemes(
    Map<String, SchemeServer> schemes,
  ) {
    final registered = <String, Map<String, SchemeServer>>{};

    for (final entry in schemes.entries) {
      final network = entry.key;
      final server = entry.value;

      registered.putIfAbsent(network, () => {});
      registered[network]![server.scheme] = server;
    }

    return Map<String, Map<String, SchemeServer>>.unmodifiable(
      registered.map<String, Map<String, SchemeServer>>(
        (network, schemeMap) => MapEntry(
            network, Map<String, SchemeServer>.unmodifiable(schemeMap)),
      ),
    );
  }

  static Map<int, Map<String, Map<String, SupportedResponse>>>
      _buildImmutableSupportedMap(
    Map<int, Map<String, Map<String, SupportedResponse>>> input,
  ) {
    return Map<int, Map<String, Map<String, SupportedResponse>>>.unmodifiable(
      input.map<int, Map<String, Map<String, SupportedResponse>>>(
        (version, networkMap) => MapEntry(
          version,
          Map<String, Map<String, SupportedResponse>>.unmodifiable(
            networkMap.map<String, Map<String, SupportedResponse>>(
              (network, schemeMap) => MapEntry(
                network,
                Map<String, SupportedResponse>.unmodifiable(schemeMap),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Map<int, Map<String, Map<String, FacilitatorClient>>>
      _buildImmutableClientMap(
    Map<int, Map<String, Map<String, FacilitatorClient>>> input,
  ) {
    return Map<int, Map<String, Map<String, FacilitatorClient>>>.unmodifiable(
      input.map<int, Map<String, Map<String, FacilitatorClient>>>(
        (version, networkMap) => MapEntry(
          version,
          Map<String, Map<String, FacilitatorClient>>.unmodifiable(
            networkMap.map<String, Map<String, FacilitatorClient>>(
              (network, schemeMap) => MapEntry(
                network,
                Map<String, FacilitatorClient>.unmodifiable(schemeMap),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Creates and fully initializes an [X402ResourceServer].
  ///
  /// During construction, this method:
  /// - Fetches supported kinds from all facilitators
  /// - Builds internal routing maps by version, network, and scheme
  /// - Validates that at least one supported scheme is available
  ///
  /// The returned instance is fully initialized and ready for use.
  ///
  /// Throws:
  /// - [ArgumentError] if no schemes are provided
  /// - [StateError] if no facilitator support could be loaded
  /// - Any error thrown by [FacilitatorClient.getSupported]
  static Future<X402ResourceServer> create({
    List<FacilitatorClient>? facilitators,
    required Map<String, SchemeServer> schemes,
  }) async {
    if (schemes.isEmpty) {
      throw ArgumentError('At least one scheme must be registered.');
    }

    final resolvedFacilitators = facilitators ?? [HttpFacilitatorClient()];
    final supportedMap = <int, Map<String, Map<String, SupportedResponse>>>{};
    final clientMap = <int, Map<String, Map<String, FacilitatorClient>>>{};

    bool loadedAtLeastOne = false;

    for (final facilitator in resolvedFacilitators) {
      final supported = await facilitator.getSupported();

      for (final kind in supported.kinds) {
        // Only register support for the current protocol version
        if (kind.x402Version != kX402Version) continue;

        loadedAtLeastOne = true;

        supportedMap.putIfAbsent(kX402Version, () => {});
        clientMap.putIfAbsent(kX402Version, () => {});

        supportedMap[kX402Version]!.putIfAbsent(kind.network, () => {});
        clientMap[kX402Version]!.putIfAbsent(kind.network, () => {});

        supportedMap[kX402Version]![kind.network]!
            .putIfAbsent(kind.scheme, () => supported);

        clientMap[kX402Version]![kind.network]!
            .putIfAbsent(kind.scheme, () => facilitator);
      }
    }

    if (!loadedAtLeastOne) {
      throw StateError(
        'No facilitator support loaded. Resource server cannot start.',
      );
    }

    return X402ResourceServer._(
      schemes: schemes,
      supported: supportedMap,
      clients: clientMap,
    );
  }

  /// Builds payment requirements for a protected resource.
  Future<List<PaymentRequirement>> buildPaymentRequirements(
    ResourceConfig config,
  ) async {
    final server = _registeredSchemes[config.network]?[config.scheme];

    if (server == null) {
      throw StateError(
        'No server registered for ${config.scheme} on ${config.network}',
      );
    }

    final supported =
        _supportedMap[kX402Version]?[config.network]?[server.scheme];

    if (supported == null) {
      throw StateError(
        'Facilitator does not support ${server.scheme} on ${config.network}',
      );
    }

    final kind = supported.kinds.firstWhere(
      (k) =>
          k.x402Version == kX402Version &&
          k.network == config.network &&
          k.scheme == server.scheme,
    );

    final parsed = await server.parsePrice(config.price, config.network);

    final base = PaymentRequirement(
      scheme: server.scheme,
      network: config.network,
      amount: parsed.amount,
      asset: parsed.asset,
      payTo: config.payTo,
      maxTimeoutSeconds: config.maxTimeoutSeconds,
      extra: parsed.extra ?? const {},
    );

    final enhanced = await server.enhancePaymentRequirement(
      base,
      kind: kind,
      facilitatorExtensions: supported.extensions,
    );

    return [enhanced];
  }

  /// Verifies a payment against requirements.
  Future<VerifyResponse> verifyPayment(
    PaymentPayload payload,
    PaymentRequirement requirements,
  ) async {
    final facilitatorClient = _clientMap[payload.x402Version]
        ?[requirements.network]?[requirements.scheme];

    if (facilitatorClient == null) {
      throw StateError(
        'No facilitator available for version ${payload.x402Version}, '
        '${requirements.scheme} on ${requirements.network}',
      );
    }

    return await facilitatorClient.verify(payload, requirements);
  }

  /// Finds matching payment requirements for a payload.
  ///
  /// Returns the first matching requirement, or `null` if none match.
  ///
  /// Matching rules depend on the x402 version:
  /// - Version 2: full equality match.
  /// - Version 1: match by scheme and network only.
  /// - Other versions: throws [UnsupportedError].
  PaymentRequirement? findMatchingRequirements(
    List<PaymentRequirement> available,
    PaymentPayload payload,
  ) {
    switch (payload.x402Version) {
      case 2:
        for (final requirement in available) {
          if (requirement == payload.accepted) {
            return requirement;
          }
        }
        return null;

      case 1:
        for (final requirement in available) {
          if (requirement.scheme == payload.accepted.scheme &&
              requirement.network == payload.accepted.network) {
            return requirement;
          }
        }
        return null;

      default:
        throw UnsupportedError(
          'Unsupported x402 version: ${payload.x402Version}',
        );
    }
  }
}
