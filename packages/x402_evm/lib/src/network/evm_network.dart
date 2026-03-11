import 'package:x402_core/x402_core.dart';

class EvmNetwork extends Network {
  /// Creates an EVM CAIP-2 network identifier.
  ///
  /// Produces `eip155:<chainId>` by default.
  /// The [namespace] parameter may be overridden if required.
  const EvmNetwork({
    required int chainId,
    super.namespace = 'eip155',
  }) : super(reference: '$chainId');
}
