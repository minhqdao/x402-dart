import 'package:x402_core/src/client/x402_client.dart';
import 'package:x402_core/src/models/network.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// The interface every blockchain-specific package must implement to support
/// signing x402 payment requirements.
abstract class X402Signer {
  /// The CAIP-2 [Network] this signer supports.
  ///
  /// Examples:
  /// - `eip155:8453`
  /// - `solana:<genesisHash>`
  Network get network;

  /// The scheme this signer supports (e.g., 'exact').
  String get scheme;

  /// The public address or identifier this signer uses.
  String get address;

  /// Checks if this signer supports the given [requirement] based on its
  /// [network] and [scheme].
  bool supports(PaymentRequirement requirement) =>
      requirement.network == network && requirement.scheme == scheme;

  /// Signs the [requirement] and returns a [SignedPayment] containing a
  /// Base64-encoded JSON string that represents the [PaymentPayload].
  ///
  /// [resource] provides context about what is being paid for.
  /// [extensions] allow for arbitrary extra data to be included in the signature.
  Future<SignedPayment> sign(
      PaymentRequirement requirement, ResourceInfo resource,
      {Map<String, dynamic>? extensions});
}
