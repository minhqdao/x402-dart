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
      expect(auth['to'], equals(requirements.payTo));
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
        // Missing extra field
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<InvalidPayloadException>()),
      );
    });
  });

  group('ExactEvmSchemeServer', () {
    late EthPrivateKey privateKey;
    late ExactEvmSchemeClient client;
    late ExactEvmSchemeServer server;
    late PaymentRequirement requirements;
    late ResourceInfo resource;

    setUp(() {
      privateKey = EthPrivateKey.fromHex('0x1234567890123456789012345678901234567890123456789012345678901234');
      client = ExactEvmSchemeClient(privateKey: privateKey);
      server = ExactEvmSchemeServer();

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
        maxTimeoutSeconds: 3600, // 1 hour to ensure test doesn't expire
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {'name': 'USD Coin', 'version': '2'},
      );
    });

    test('should verify valid payment payload', () async {
      final payload = await client.createPaymentPayload(requirements, resource);
      final isValid = await server.verifyPayload(payload, requirements);

      expect(isValid, isTrue);
    });

    test('should reject payload with wrong scheme', () async {
      final payload = await client.createPaymentPayload(requirements, resource);
      final modifiedPayload = PaymentPayload(
        x402Version: payload.x402Version,
        resource: payload.resource,
        accepted: PaymentRequirement(
          scheme: 'deferred', // Wrong scheme
          network: requirements.network,
          amount: requirements.amount,
          payTo: requirements.payTo,
          maxTimeoutSeconds: requirements.maxTimeoutSeconds,
          asset: requirements.asset,
          extra: requirements.extra,
        ),
        payload: payload.payload,
      );

      final isValid = await server.verifyPayload(modifiedPayload, requirements);

      expect(isValid, isFalse);
    });

    test('should reject payload with wrong network', () async {
      final payload = await client.createPaymentPayload(requirements, resource);
      final modifiedPayload = PaymentPayload(
        x402Version: payload.x402Version,
        resource: payload.resource,
        accepted: PaymentRequirement(
          scheme: requirements.scheme,
          network: 'eip155:1', // Wrong network
          amount: requirements.amount,
          payTo: requirements.payTo,
          maxTimeoutSeconds: requirements.maxTimeoutSeconds,
          asset: requirements.asset,
          extra: requirements.extra,
        ),
        payload: payload.payload,
      );

      final isValid = await server.verifyPayload(modifiedPayload, requirements);

      expect(isValid, isFalse);
    });

    test('should reject payload with wrong amount', () async {
      final payload = await client.createPaymentPayload(requirements, resource);

      final wrongRequirements = PaymentRequirement(
        scheme: requirements.scheme,
        network: requirements.network,
        amount: '20000', // Different amount
        payTo: requirements.payTo,
        maxTimeoutSeconds: requirements.maxTimeoutSeconds,
        asset: requirements.asset,
        extra: requirements.extra,
      );

      final isValid = await server.verifyPayload(payload, wrongRequirements);

      expect(isValid, isFalse);
    });

    test('should reject payload with wrong recipient', () async {
      final payload = await client.createPaymentPayload(requirements, resource);

      final wrongRequirements = PaymentRequirement(
        scheme: requirements.scheme,
        network: requirements.network,
        amount: requirements.amount,
        payTo: '0x1111111111111111111111111111111111111111', // Wrong address
        maxTimeoutSeconds: requirements.maxTimeoutSeconds,
        asset: requirements.asset,
        extra: requirements.extra,
      );

      final isValid = await server.verifyPayload(payload, wrongRequirements);

      expect(isValid, isFalse);
    });
  });

  group('ExactPayloadData', () {
    test('should parse from payment payload', () {
      const resource = ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Access to premium data',
        mimeType: 'application/json',
      );
      const requirement = PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      );
      const payload = PaymentPayload(
        x402Version: 2,
        resource: resource,
        accepted: requirement,
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
