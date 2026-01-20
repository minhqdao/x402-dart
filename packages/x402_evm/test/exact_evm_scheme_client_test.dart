import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/schemes/exact_evm_scheme_client.dart';

void main() {
  group('ExactEvmSchemeClient', () {
    late EthPrivateKey privateKey;
    late ExactEvmSchemeClient client;
    late PaymentRequirement requirements;
    late ResourceInfo resource;

    setUp(() {
      privateKey = EthPrivateKey.fromHex(
          '0x4efa000000000000000000000000000000000000000000000000000000000001');
      client = ExactEvmSchemeClient(
          privateKey: privateKey,
          nowProvider: () => 1940,
          nonceProvider: () => Uint8List(32));

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
      expect(auth['from'], equals(privateKey.address.hex.toLowerCase()));
      expect(auth['to'], equals(requirements.payTo.toLowerCase()));
      expect(auth['value'], equals('10000'));
    });

    test('should include extensions in payload', () async {
      final extensions = {'promoCode': 'TEST2024'};
      final payload = await client.createPaymentPayload(
        requirements,
        resource,
        extensions: extensions,
      );

      expect(payload.extensions, equals(extensions));
    });

    test('should produce verifiable EIP-3009 signature', () async {
      final payload = await client.createPaymentPayload(requirements, resource);
      final signatureHex = payload.payload['signature'] as String;

      expect(signatureHex,
          '0x3a84f211f0166003b965e357edea4ff753907551f47267170544a0b2fcb51a4f130bed8a590839dd874cb42d805eb622b0cf2f46c840bc5d222f7a73009eb0a01c');
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

    test('should throw on invalid network format (missing colon)', () {
      const badRequirements = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155', // Missing colon and chainId
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

    test('should throw on invalid network format (too many parts)', () {
      const badRequirements = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453:extra', // Too many parts
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

    test('should throw on missing token metadata (missing name)', () {
      const badRequirements = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {'version': '2'}, // Missing name
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<InvalidPayloadException>()),
      );
    });

    test('should throw on missing token metadata (missing version)', () {
      const badRequirements = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {'name': 'USDC'}, // Missing version
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<InvalidPayloadException>()),
      );
    });
  });
}
