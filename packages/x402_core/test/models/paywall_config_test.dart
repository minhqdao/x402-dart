import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';

void main() {
  group('PaywallConfig', () {
    test('constructor sets fields correctly', () {
      const config = PaywallConfig(
        appName: 'Test App',
        appLogo: 'https://logo.com',
        sessionTokenEndpoint: '/token',
        currentUrl: '/current',
        testnet: true,
      );
      expect(config.appName, 'Test App');
      expect(config.appLogo, 'https://logo.com');
      expect(config.sessionTokenEndpoint, '/token');
      expect(config.currentUrl, '/current');
      expect(config.testnet, true);
    });
  });
}
