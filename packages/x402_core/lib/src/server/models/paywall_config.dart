/// Paywall configuration for HTML responses.
///
/// Configures the appearance and behavior of the default paywall UI
/// shown to users when payment is required.
class PaywallConfig {
  /// Application name displayed in the paywall
  final String? appName;

  /// URL to application logo displayed in the paywall
  final String? appLogo;

  /// Endpoint for session token management
  final String? sessionTokenEndpoint;

  /// Current URL being accessed (for redirects after payment)
  final String? currentUrl;

  /// Whether to use testnet networks for payment
  final bool? testnet;

  const PaywallConfig({
    this.appName,
    this.appLogo,
    this.sessionTokenEndpoint,
    this.currentUrl,
    this.testnet,
  });
}
