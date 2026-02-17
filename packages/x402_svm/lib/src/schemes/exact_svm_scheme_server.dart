import 'dart:async';

import 'package:x402_core/x402_core.dart';

/// SVM (Solana) implementation of the `exact` payment scheme.
///
/// Converts abstract [Money] values into concrete SPL token
/// [AssetAmount]s on supported SVM networks.
///
/// By default, prices are converted to the network’s configured
/// USDC mint. Custom conversion logic may be registered through
/// [moneyParsers].
///
/// All conversions are deterministic and string-based.
/// Floating-point types are never used.
class ExactSvmSchemeServer implements SchemeServer {
  @override
  String get scheme => 'exact';

  final List<MoneyParser> _moneyParsers;

  /// Creates an Exact SVM scheme server.
  ///
  /// [moneyParsers] are executed in order. Default conversion logic is applied
  /// if all return `null` or if no parsers are provided.
  ExactSvmSchemeServer({
    List<MoneyParser> moneyParsers = const [],
  }) : _moneyParsers = List.unmodifiable(moneyParsers);

  @override
  Future<AssetAmount> parsePrice(
    Price price,
    Network network,
  ) async {
    switch (price) {
      case AssetAmount(:final asset, :final amount, :final extra):
        if (asset.isEmpty) {
          throw ArgumentError(
            'Asset mint must be specified for AssetAmount on network $network',
          );
        }

        return AssetAmount(
          asset: asset,
          amount: amount,
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

  /// Enhances the payment requirement for SVM networks.
  ///
  /// If the facilitator provides a `feePayer` in
  /// [SupportedKind.extra], it is propagated into
  /// the returned [PaymentRequirement.extra] map.
  @override
  Future<PaymentRequirement> enhancePaymentRequirement(
    PaymentRequirement paymentRequirement, {
    required SupportedKind kind,
    List<String> facilitatorExtensions = const [],
  }) async {
    final feePayer = kind.extra?['feePayer'];
    if (feePayer == null) return paymentRequirement;

    return paymentRequirement.copyWith(
      extra: {
        ...paymentRequirement.extra,
        'feePayer': feePayer,
      },
    );
  }

  // ----------------------------------------------------------
  // Internal helpers
  // ----------------------------------------------------------

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
      asset: assetInfo.mint,
      amount: tokenAmount,
      extra: {
        'name': assetInfo.name,
        'decimals': assetInfo.decimals,
      },
    );
  }

  _SplTokenInfo _getDefaultAsset(Network network) {
    const tokens = <String, _SplTokenInfo>{
      'solana:mainnet': _SplTokenInfo(
        mint: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        name: 'USD Coin',
        decimals: 6,
      ),
      'solana:devnet': _SplTokenInfo(
        mint: '4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU',
        name: 'USD Coin',
        decimals: 6,
      ),
    };

    final asset = tokens[network.identifier];
    if (asset == null) {
      throw ArgumentError(
        'No default SPL token configured for network $network',
      );
    }

    return asset;
  }
}

final class _SplTokenInfo {
  final String mint;
  final String name;
  final int decimals;

  const _SplTokenInfo({
    required this.mint,
    required this.name,
    required this.decimals,
  });
}
