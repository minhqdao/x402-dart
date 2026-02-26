import 'package:x402_core/src/constants.dart';
import 'package:x402_core/src/models/network.dart';
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
  final Map<Network, Map<String, SchemeServer>> _schemeServers;
  final Map<_RouteKey, _RouteEntry> _routes;

  X402ResourceServer._({
    required Map<Network, Map<String, SchemeServer>> schemeServers,
    required Map<_RouteKey, _RouteEntry> routes,
  })  : _schemeServers = schemeServers,
        _routes = routes;

  static Map<Network, Map<String, SchemeServer>> _registerSchemeServers(
    List<SchemeServer> schemeServers,
  ) {
    final registered = <Network, Map<String, SchemeServer>>{};

    for (final schemeServer in schemeServers) {
      final network = schemeServer.network;

      registered.putIfAbsent(network, () => {});

      if (registered[network]!.containsKey(schemeServer.scheme)) {
        throw ArgumentError(
          'Duplicate SchemeServer for ${schemeServer.scheme} on $network',
        );
      }

      registered[network]![schemeServer.scheme] = schemeServer;
    }

    return Map.unmodifiable(
      registered.map(
        (network, schemeServerMap) => MapEntry(
          network,
          Map<String, SchemeServer>.unmodifiable(schemeServerMap),
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
    required List<SchemeServer> schemeServers,
  }) async {
    if (schemeServers.isEmpty) {
      throw ArgumentError('At least one scheme server must be registered.');
    }

    final registeredSchemes = _registerSchemeServers(schemeServers);

    final resolvedFacilitators = facilitators ?? [HttpFacilitatorClient()];
    final routes = <_RouteKey, _RouteEntry>{};

    for (final facilitator in resolvedFacilitators) {
      final supported = await facilitator.getSupported();

      for (final kind in supported.kinds) {
        if (kind.x402Version != kX402Version) continue;

        // Skip kinds we do not have a registered SchemeServer for.
        if (registeredSchemes[kind.network]?[kind.scheme] == null) continue;

        final key = _RouteKey(kind.x402Version, kind.network, kind.scheme);

        if (routes.containsKey(key)) {
          throw StateError(
            'Multiple facilitators provide support for '
            '${kind.scheme} on ${kind.network} (v${kind.x402Version}).',
          );
        }

        routes[key] = _RouteEntry(supported: supported, client: facilitator);
      }
    }

    if (routes.isEmpty) {
      throw StateError(
        'No compatible facilitator support for registered schemes.',
      );
    }

    return X402ResourceServer._(
      schemeServers: registeredSchemes,
      routes: Map<_RouteKey, _RouteEntry>.unmodifiable(routes),
    );
  }

  /// Builds payment requirement for a protected resource.
  Future<PaymentRequirement> buildPaymentRequirement(
    ResourceConfig config,
  ) async {
    final server = _schemeServers[config.network]?[config.scheme];

    if (server == null) {
      throw StateError(
        'No server registered for ${config.scheme} on ${config.network}',
      );
    }

    final key = _RouteKey(kX402Version, config.network, server.scheme);
    final route = _routes[key];

    if (route == null) {
      throw StateError(
        'Facilitator does not support ${server.scheme} on ${config.network}',
      );
    }

    final kind = route.supported.kinds.firstWhere(
      (k) =>
          k.x402Version == kX402Version &&
          k.network == config.network &&
          k.scheme == server.scheme,
      orElse: () => throw StateError(
        'Facilitator support inconsistency for '
        '${server.scheme} on ${config.network}',
      ),
    );

    final parsed = await server.parsePrice(config.price);

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
      facilitatorExtensions: route.supported.extensions,
    );

    return enhanced;
  }

  /// Verifies a payment against requirements.
  Future<VerifyResponse> verifyPayment(
    PaymentPayload payload,
    PaymentRequirement requirements,
  ) {
    final key = _RouteKey(
      payload.x402Version,
      requirements.network,
      requirements.scheme,
    );
    final facilitatorClient = _routes[key]?.client;

    if (facilitatorClient == null) {
      throw StateError(
        'No facilitator available for version ${payload.x402Version}, '
        '${requirements.scheme} on ${requirements.network}',
      );
    }

    return facilitatorClient.verify(payload, requirements);
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
          if (requirement == payload.accepted) return requirement;
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
        return null;
    }
  }
}

final class _RouteEntry {
  final SupportedResponse supported;
  final FacilitatorClient client;

  const _RouteEntry({
    required this.supported,
    required this.client,
  });
}

final class _RouteKey {
  final int version;
  final Network network;
  final String scheme;

  const _RouteKey(this.version, this.network, this.scheme);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RouteKey &&
          version == other.version &&
          network == other.network &&
          scheme == other.scheme;

  @override
  int get hashCode => Object.hash(version, network, scheme);
}
