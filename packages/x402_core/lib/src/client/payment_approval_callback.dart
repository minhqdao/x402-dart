import 'package:x402_core/src/client/x402_signer.dart';
import 'package:x402_core/src/models/payment_requirement.dart';
import 'package:x402_core/src/models/resource_info.dart';

/// Callback invoked when a 402 Payment Required response is received,
/// allowing the application to request user approval before a payment
/// is signed and sent.
///
/// Parameters:
/// - [requirement]: The matched payment requirement from the server.
/// - [resource]: Information about the resource being accessed.
/// - [signer]: The signer that will be used to sign the payment.
///
/// Returns `true` to approve and process the payment, or `false` to abort.
typedef PaymentApprovalCallback = Future<bool> Function(
  PaymentRequirement requirement,
  ResourceInfo resource,
  X402Signer signer,
);
