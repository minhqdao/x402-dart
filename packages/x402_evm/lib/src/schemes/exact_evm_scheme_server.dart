import 'dart:async';

import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

/// EVM implementation of the "exact" payment scheme.
///
/// Converts user-friendly monetary values (e.g. "$0.10")
/// into ERC-20 token amounts on supported EVM networks.
///
/// By default, prices are converted to the network’s
/// configured stablecoin (e.g. USDC).
///
/// Custom conversion logic can be registered through [moneyParsers].
class ExactEvmSchemeServer implements SchemeServer {
  @override
  String get scheme => 'exact';

  @override
  final EvmNetwork network;

  final List<MoneyParser> _moneyParsers;

  /// Creates an Exact EVM scheme server.
  ///
  /// [moneyParsers] are executed in order. Default conversion logic is applied
  /// if all return `null` or if no parsers are provided.
  ExactEvmSchemeServer({
    List<MoneyParser> moneyParsers = const [],
    String networkNamespace = 'eip155',
    required int chainId,
  })  : _moneyParsers = List.unmodifiable(moneyParsers),
        network = EvmNetwork(namespace: networkNamespace, chainId: chainId);

  @override
  Future<AssetAmount> parsePrice(Price price) async {
    // If already an AssetAmount, return as-is.
    switch (price) {
      case AssetAmount(:final asset, :final amount, :final extra):
        if (asset.isEmpty) {
          throw ArgumentError(
            'Asset address must be specified for AssetAmount on network $network',
          );
        }

        return AssetAmount(
          amount: amount,
          asset: asset,
          extra: extra ?? const {},
        );

      case Money(:final amount):
        for (final parser in _moneyParsers) {
          final result = await parser(amount, network);
          if (result != null) return result;
        }

        return _defaultMoneyConversion(amount, network);
    }
  }

  @override
  Future<PaymentRequirement> enhancePaymentRequirement(
    PaymentRequirement paymentRequirement, {
    required SupportedKind kind,
    List<String> facilitatorExtensions = const [],
  }) async {
    // Currently unused, but intentionally part of the API.
    // Allows future scheme-specific enhancement logic.

    return paymentRequirement;
  }

  // -------------------------
  // Internal helpers
  // -------------------------

  AssetAmount _defaultMoneyConversion(
    String amount,
    Network network,
  ) {
    final assetInfo = _getDefaultAsset(network);

    final tokenAmount = TokenAmountNormalizer.normalize(
      amount,
      decimals: assetInfo.decimals,
    );

    return AssetAmount(
      amount: tokenAmount,
      asset: assetInfo.address,
      extra: {
        'name': assetInfo.name,
        'version': assetInfo.version,
      },
    );
  }

  _StablecoinInfo _getDefaultAsset(Network network) {
    const stablecoins = <String, _StablecoinInfo>{
      'eip155:8453': _StablecoinInfo(
        address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
        name: 'USD Coin',
        version: '2',
        decimals: 6,
      ),
      'eip155:84532': _StablecoinInfo(
        address: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        name: 'USDC',
        version: '2',
        decimals: 6,
      ),
    };

    final asset = stablecoins[network.identifier];
    if (asset == null) {
      throw ArgumentError(
        'No default asset configured for network $network',
      );
    }

    return asset;
  }
}

final class _StablecoinInfo {
  final String address;
  final String name;
  final String version;
  final int decimals;

  const _StablecoinInfo({
    required this.address,
    required this.name,
    required this.version,
    required this.decimals,
  });
}
