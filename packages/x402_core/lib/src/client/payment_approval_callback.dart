import 'package:x402_core/src/client/x402_client.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// Callback to let the user approve a payment before it's signed and sent.
///
/// Returns `true` to approve the payment, `false` to deny.
typedef PaymentApprovalCallback = Future<bool> Function(
  PaymentRequirement requirement,
  ResourceInfo resource,
  X402Signer signer,
);
