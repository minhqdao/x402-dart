import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/network/solana_cluster.dart';
import 'package:x402_svm/src/schemes/exact_svm_scheme_client.dart';

class _MockSolanaClient extends Mock implements SolanaClient {}

class _MockRpcClient extends Mock implements RpcClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(Commitment.confirmed);
    registerFallbackValue(Encoding.base64);
  });

  group('ExactSvmSchemeClient', () {
    late Ed25519HDKeyPair keyPair;
    late _MockSolanaClient mockSolanaClient;
    late _MockRpcClient mockRpcClient;
    late ExactSvmSchemeClient client;
    late PaymentRequirement requirements;
    late ResourceInfo resource;

    setUp(() async {
      keyPair = await Ed25519HDKeyPair.random();
      mockSolanaClient = _MockSolanaClient();
      mockRpcClient = _MockRpcClient();

      when(() => mockSolanaClient.rpcClient).thenReturn(mockRpcClient);

      client = ExactSvmSchemeClient(
        cluster: SolanaCluster.devnet,
        signer: keyPair,
        solanaClient: mockSolanaClient,
      );

      resource = const ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
      );

      requirements = PaymentRequirement(
        scheme: 'v2:solana:exact',
        network: const Network(
            namespace: 'solana', reference: 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1'),
        amount: '10000',
        payTo: 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv',
        maxTimeoutSeconds: 60,
        asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        extra: {'feePayer': '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC'},
      );

      // Mock blockhash
      when(() => mockRpcClient.getLatestBlockhash(
            commitment: any(named: 'commitment'),
            minContextSlot: any(named: 'minContextSlot'),
          )).thenAnswer(
        (_) async => LatestBlockhashResult(
          value: const LatestBlockhash(
            blockhash: '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
            lastValidBlockHeight: 100000,
          ),
          context: Context(slot: BigInt.from(1)),
        ),
      );

      // Mock account info (destination token account exists)
      when(() => mockRpcClient.getAccountInfo(
            any(),
            commitment: any(named: 'commitment'),
            encoding: any(named: 'encoding'),
            minContextSlot: any(named: 'minContextSlot'),
            dataSlice: any(named: 'dataSlice'),
          )).thenAnswer(
        (_) async => AccountResult(
          value: Account(
            lamports: 1000000,
            owner: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
            data: BinaryAccountData(List.filled(165, 0)),
            executable: false,
            rentEpoch: BigInt.zero,
          ),
          context: Context(slot: BigInt.from(1)),
        ),
      );
    });

    test('scheme getter should return correct value', () {
      expect(client.scheme, equals('v2:solana:exact'));
    });

    test('network getter should return correct network', () {
      expect(client.network.identifier,
          equals('solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1'));
    });

    test('should accept "exact" as a valid scheme', () async {
      final req = requirements.copyWith(scheme: 'exact');
      await expectLater(
        client.createPaymentPayload(req, resource),
        completes,
      );
    });

    test('address getter should return correct value', () {
      expect(client.address, equals(keyPair.publicKey.toBase58()));
    });

    test(
        'createPaymentPayload should throw UnsupportedSchemeException for invalid scheme',
        () {
      final badRequirements = PaymentRequirement(
        scheme: 'invalid-scheme',
        network: requirements.network,
        amount: requirements.amount,
        payTo: requirements.payTo,
        maxTimeoutSeconds: requirements.maxTimeoutSeconds,
        asset: requirements.asset,
        extra: requirements.extra,
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<UnsupportedSchemeException>()),
      );
    });

    test('rejects other solana schemes', () {
      final bad = PaymentRequirement(
        scheme: 'v2:solana:other',
        network: requirements.network,
        amount: requirements.amount,
        payTo: requirements.payTo,
        maxTimeoutSeconds: requirements.maxTimeoutSeconds,
        asset: requirements.asset,
        extra: requirements.extra,
      );

      expect(
        () => client.createPaymentPayload(bad, resource),
        throwsA(isA<UnsupportedSchemeException>()),
      );
    });

    test(
        'createPaymentPayload should throw InvalidPayloadException for invalid network',
        () {
      final badRequirements = PaymentRequirement(
        scheme: requirements.scheme,
        network: const Network(namespace: 'invalid', reference: 'network'),
        amount: requirements.amount,
        payTo: requirements.payTo,
        maxTimeoutSeconds: requirements.maxTimeoutSeconds,
        asset: requirements.asset,
        extra: requirements.extra,
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<InvalidPayloadException>()),
      );
    });

    test('should throw if network namespace is not solana', () {
      final bad = requirements.copyWith(
          network: const Network(namespace: 'eip155', reference: '1'));
      expect(
        () => client.createPaymentPayload(bad, resource),
        throwsA(isA<InvalidPayloadException>()),
      );
    });

    test(
        'createPaymentPayload should throw InvalidPayloadException if feePayer is missing',
        () {
      final badRequirements = PaymentRequirement(
        scheme: requirements.scheme,
        network: requirements.network,
        amount: requirements.amount,
        payTo: requirements.payTo,
        maxTimeoutSeconds: requirements.maxTimeoutSeconds,
        asset: requirements.asset,
        extra: {}, // Missing feePayer
      );

      expect(
        () => client.createPaymentPayload(badRequirements, resource),
        throwsA(isA<InvalidPayloadException>()),
      );
    });

    test(
        'createPaymentPayload should create valid payload when inputs are correct',
        () async {
      final payload = await client.createPaymentPayload(requirements, resource);

      expect(payload.x402Version, equals(kX402Version));
      expect(payload.resource, equals(resource));
      expect(payload.accepted, equals(requirements));
      expect(payload.payload, contains('transaction'));
      expect(payload.payload['transaction'], isA<String>());
      final tx = payload.payload['transaction'] as String;
      expect(tx, isNotEmpty);
      expect(() => base64.decode(tx), returnsNormally);
    });

    test('createPaymentPayload should include extensions if provided',
        () async {
      final extensions = {'key': 'value'};
      final payload = await client.createPaymentPayload(
        requirements,
        resource,
        extensions: extensions,
      );

      expect(payload.extensions, equals(extensions));
    });
  });
}
