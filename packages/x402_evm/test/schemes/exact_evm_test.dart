import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

void main() {
  group('ExactEvmSchemeClient', () {
    late EthPrivateKey privateKey;
    late ExactEvmSchemeClient client;
    late X402Requirement requirements;

    setUp(() {
      privateKey = EthPrivateKey.fromHex('0x1234567890123456789012345678901234567890123456789012345678901234');
      client = ExactEvmSchemeClient(privateKey: privateKey);

      requirements = const X402Requirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        resource: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        data: {'name': 'USD Coin', 'version': '2'},
      );
    });

    test('should create valid payment payload', () async {
      final payload = await client.createPaymentPayload(requirements);

      expect(payload.x402Version, equals(kX402Version));
      expect(payload.scheme, equals('exact'));
      expect(payload.network, equals('eip155:8453'));
      expect(payload.payload['signature'], isNotNull);
      expect(payload.payload['authorization'], isNotNull);

      final auth = payload.payload['authorization'] as Map<String, dynamic>;
      expect(auth['from'], equals(privateKey.address.hex));
      expect(auth['to'], equals(requirements.payTo));
      expect(auth['value'], equals('10000'));
    });

    test('should throw on unsupported scheme', () {
      const badRequirements = X402Requirement(
        scheme: 'deferred',
        network: 'eip155:8453',
        amount: '10000',
        resource: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      );

      expect(() => client.createPaymentPayload(badRequirements), throwsA(isA<UnsupportedSchemeException>()));
    });

    test('should throw on invalid network format', () {
      const badRequirements = X402Requirement(
        scheme: 'exact',
        network: 'invalid:network',
        amount: '10000',
        resource: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        data: {'name': 'USDC', 'version': '2'},
      );

      expect(() => client.createPaymentPayload(badRequirements), throwsA(isA<InvalidPayloadException>()));
    });

    test('should throw on missing token metadata', () {
      const badRequirements = X402Requirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        resource: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        // Missing data field
      );

      expect(() => client.createPaymentPayload(badRequirements), throwsA(isA<InvalidPayloadException>()));
    });
  });

  group('ExactEvmSchemeServer', () {
    late EthPrivateKey privateKey;
    late ExactEvmSchemeClient client;
    late ExactEvmSchemeServer server;
    late X402Requirement requirements;

    setUp(() {
      privateKey = EthPrivateKey.fromHex('0x1234567890123456789012345678901234567890123456789012345678901234');
      client = ExactEvmSchemeClient(privateKey: privateKey);
      server = ExactEvmSchemeServer();

      requirements = const X402Requirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        resource: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 3600, // 1 hour to ensure test doesn't expire
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        data: {'name': 'USD Coin', 'version': '2'},
      );
    });

    test('should verify valid payment payload', () async {
      final payload = await client.createPaymentPayload(requirements);
      final isValid = await server.verifyPayload(payload, requirements);

      expect(isValid, isTrue);
    });

    test('should reject payload with wrong scheme', () async {
      final payload = await client.createPaymentPayload(requirements);
      final modifiedPayload = PaymentPayload(
        x402Version: payload.x402Version,
        scheme: 'deferred',
        network: payload.network,
        payload: payload.payload,
      );

      final isValid = await server.verifyPayload(modifiedPayload, requirements);

      expect(isValid, isFalse);
    });

    test('should reject payload with wrong network', () async {
      final payload = await client.createPaymentPayload(requirements);
      final modifiedPayload = PaymentPayload(
        x402Version: payload.x402Version,
        scheme: payload.scheme,
        network: 'eip155:1', // Wrong network
        payload: payload.payload,
      );

      final isValid = await server.verifyPayload(modifiedPayload, requirements);

      expect(isValid, isFalse);
    });

    test('should reject payload with wrong amount', () async {
      final payload = await client.createPaymentPayload(requirements);

      final wrongRequirements = X402Requirement(
        scheme: requirements.scheme,
        network: requirements.network,
        amount: '20000', // Different amount
        resource: requirements.resource,
        description: requirements.description,
        mimeType: requirements.mimeType,
        payTo: requirements.payTo,
        maxTimeoutSeconds: requirements.maxTimeoutSeconds,
        asset: requirements.asset,
        data: requirements.data,
      );

      final isValid = await server.verifyPayload(payload, wrongRequirements);

      expect(isValid, isFalse);
    });

    test('should reject payload with wrong recipient', () async {
      final payload = await client.createPaymentPayload(requirements);

      final wrongRequirements = X402Requirement(
        scheme: requirements.scheme,
        network: requirements.network,
        amount: requirements.amount,
        resource: requirements.resource,
        description: requirements.description,
        mimeType: requirements.mimeType,
        payTo: '0x1111111111111111111111111111111111111111', // Wrong address
        maxTimeoutSeconds: requirements.maxTimeoutSeconds,
        asset: requirements.asset,
        data: requirements.data,
      );

      final isValid = await server.verifyPayload(payload, wrongRequirements);

      expect(isValid, isFalse);
    });
  });

  group('ExactPayloadData', () {
    test('should parse from payment payload', () {
      const payload = PaymentPayload(
        x402Version: 2,
        scheme: 'exact',
        network: 'eip155:8453',
        payload: {
          'signature': '0x123...',
          'authorization': {
            'from': '0xabc...',
            'to': '0xdef...',
            'value': '10000',
            'validAfter': '1000',
            'validBefore': '2000',
            'nonce': '0x456...',
          },
        },
      );

      final exactPayload = ExactPayloadData.fromPaymentPayload(payload);

      expect(exactPayload.signature, equals('0x123...'));
      expect(exactPayload.authorization.from, equals('0xabc...'));
      expect(exactPayload.authorization.to, equals('0xdef...'));
      expect(exactPayload.authorization.value, equals('10000'));
    });
  });
}
