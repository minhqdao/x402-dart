import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

void main() {
  group('ExactEvmSchemeClient', () {
    late EthPrivateKey privateKey;
    late ExactEvmSchemeClient client;
    late PaymentRequirement requirements;
    late ResourceInfo resource;

    setUp(() {
      privateKey = EthPrivateKey.fromHex('0x1234567890123456789012345678901234567890123456789012345678901234');
      client = ExactEvmSchemeClient(privateKey: privateKey);

      resource = const ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
      );

      requirements = const PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {'name': 'USD Coin', 'version': '2'},
      );
    });

    test('should create valid payment payload', () async {
      final payload = await client.createPaymentPayload(requirements, resource);

      expect(payload.x402Version, equals(kX402Version));
      expect(payload.accepted.scheme, equals('exact'));
      expect(payload.accepted.network, equals('eip155:8453'));
      expect(payload.payload['signature'], isNotNull);
      expect(payload.payload['authorization'], isNotNull);

      final auth = payload.payload['authorization'] as Map<String, dynamic>;
      expect(auth['from'], equals(privateKey.address.hex));
      expect(auth['to'], equals(requirements.payTo.toLowerCase()));
      expect(auth['value'], equals('10000'));
    });

    test('should throw on unsupported scheme', () {
      const badRequirements = PaymentRequirement(
        scheme: 'deferred',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {},
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<UnsupportedSchemeException>()),
      );
    });

    test('should throw on invalid network format', () {
      const badRequirements = PaymentRequirement(
        scheme: 'exact',
        network: 'invalid:network',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {'name': 'USDC', 'version': '2'},
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<InvalidPayloadException>()),
      );
    });

    test('should throw on missing token metadata', () {
      const badRequirements = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {},
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<InvalidPayloadException>()),
      );
    });
  });
}
