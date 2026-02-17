import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/schemes/exact_svm_scheme_client.dart';
import 'package:x402_svm/x402_svm.dart';

/// Mock class for SolanaClient to intercept network calls.
class _MockSolanaClient extends Mock implements SolanaClient {}

/// Mock class for RpcClient to intercept RPC method calls.
class _MockRpcClient extends Mock implements RpcClient {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail to handle custom types in any() matchers.
    registerFallbackValue(Commitment.confirmed);
    registerFallbackValue(Encoding.base64);
    registerFallbackValue(const DataSlice(offset: 0, length: 0));
  });

  group('SvmSigner', () {
    late Ed25519HDKeyPair keyPair;
    late _MockSolanaClient mockSolanaClient;
    late _MockRpcClient mockRpcClient;
    late SvmSigner signer;
    late PaymentRequirement requirements;
    late ResourceInfo resource;

    setUp(() async {
      // 1. Generate a random keypair for the signer.
      keyPair = await Ed25519HDKeyPair.random();

      // 2. Initialize mocks.
      mockSolanaClient = _MockSolanaClient();
      mockRpcClient = _MockRpcClient();

      when(() => mockSolanaClient.rpcClient).thenReturn(mockRpcClient);

      // 3. Create the signer instance using the mocked client.
      signer = SvmSigner.fromClient(
        cluster: SolanaCluster.devnet,
        client: ExactSvmSchemeClient(
          signer: keyPair,
          solanaClient: mockSolanaClient,
        ),
      );

      // 4. Setup test data.
      resource = const ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
      );

      requirements = PaymentRequirement(
        scheme: 'v2:solana:exact',
        network: Network.parse('solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1'),
        amount: '10000',
        payTo: 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv',
        maxTimeoutSeconds: 60,
        asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
        extra: const {
          'feePayer': '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC'
        },
      );

      // 5. Mock essential RPC responses.

      // Mock blockhash retrieval.
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

      // Mock account info retrieval (simulating that the token mint exists).
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
            data: const AccountData.empty(),
            executable: false,
            rentEpoch: BigInt.zero,
          ),
          context: Context(slot: BigInt.from(1)),
        ),
      );
    });

    test('should have correct network and scheme', () {
      expect(signer.network.identifier,
          equals('solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1'));
      expect(signer.scheme, equals('v2:solana:exact'));
    });

    test('should have correct address', () {
      expect(signer.address, equals(keyPair.publicKey.toBase58()));
    });

    test('should support both standard and exact schemes', () {
      final reqStandard = PaymentRequirement(
        scheme: 'v2:solana:exact',
        network: signer.network,
        amount: '1000',
        asset: 'asset',
        payTo: 'payTo',
        maxTimeoutSeconds: 60,
        extra: const {},
      );
      final reqExact = PaymentRequirement(
        scheme: 'exact',
        network: signer.network,
        amount: '1000',
        asset: 'asset',
        payTo: 'payTo',
        maxTimeoutSeconds: 60,
        extra: const {},
      );
      final reqBadNetwork = PaymentRequirement(
        scheme: 'exact',
        network: const Network(namespace: '', reference: 'wrong-network'),
        amount: '1000',
        asset: 'asset',
        payTo: 'payTo',
        maxTimeoutSeconds: 60,
        extra: const {},
      );
      final reqBadScheme = PaymentRequirement(
        scheme: 'bad-scheme',
        network: signer.network,
        amount: '1000',
        asset: 'asset',
        payTo: 'payTo',
        maxTimeoutSeconds: 60,
        extra: const {},
      );

      expect(signer.supports(reqStandard), isTrue);
      expect(signer.supports(reqExact), isTrue);
      expect(signer.supports(reqBadNetwork), isFalse);
      expect(signer.supports(reqBadScheme), isFalse);
    });

    test('should sign and return base64 encoded payload', () async {
      final signature = await signer.sign(requirements, resource);

      expect(signature, isA<SignedPayment>());
      final decodedJson = signature.decode();
      final payload = PaymentPayload.fromJson(decodedJson);

      expect(payload.x402Version, equals(kX402Version));
      expect(payload.accepted.network, equals(requirements.network));
      expect(payload.payload['transaction'], isNotNull);
      final tx = payload.payload['transaction'] as String;
      expect(tx, isNotEmpty);
      expect(() => base64.decode(tx), returnsNormally);
    });

    test('should include extensions if provided', () async {
      final extensions = {'test': 'extension'};
      final signature =
          await signer.sign(requirements, resource, extensions: extensions);

      final decodedJson = signature.decode();
      final payload = PaymentPayload.fromJson(decodedJson);

      expect(payload.extensions, equals(extensions));
    });

    group('constructors and networks', () {
      const customRpc = 'https://custom.rpc.com';
      const hexKey =
          '0000000000000000000000000000000000000000000000000000000000000001';
      final byteKey = List.filled(32, 0);
      const mnemonic =
          'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

      test('fromPrivateKeyHex with customRpcUrl', () async {
        final s = await SvmSigner.fromPrivateKeyHex(
          privateKeyHex: hexKey,
          cluster: SolanaCluster.devnet,
          customRpcUrl: customRpc,
        );
        expect(s.network.identifier, startsWith('solana:'));
      });

      test('fromPrivateKeyBytes with customRpcUrl', () async {
        final s = await SvmSigner.fromPrivateKeyBytes(
          privateKeyBytes: byteKey,
          cluster: SolanaCluster.devnet,
          customRpcUrl: customRpc,
        );
        expect(s.network.identifier, startsWith('solana:'));
      });

      test('fromMnemonic with customRpcUrl', () async {
        final s = await SvmSigner.fromMnemonic(
          mnemonic: mnemonic,
          cluster: SolanaCluster.devnet,
          customRpcUrl: customRpc,
        );
        expect(s.network.identifier, startsWith('solana:'));
      });

      test('mainnet support', () async {
        final s = await SvmSigner.createRandom(cluster: SolanaCluster.mainnet);
        expect(
            s.network.identifier,
            equals(
                'solana:${SolanaCluster.mainnet.genesisHash.substring(0, 32)}'));
      });

      test('testnet support', () async {
        final s = await SvmSigner.createRandom(cluster: SolanaCluster.testnet);
        expect(
            s.network.identifier,
            equals(
                'solana:${SolanaCluster.testnet.genesisHash.substring(0, 32)}'));
      });
    });

    group('validation', () {
      test('throws on zero amount', () {
        final req = requirements.copyWith(amount: '0');
        expect(() => signer.sign(req, resource), throwsArgumentError);
      });

      test('throws on negative amount', () {
        final req = requirements.copyWith(amount: '-100');
        expect(() => signer.sign(req, resource), throwsArgumentError);
      });

      test('throws on non-numeric amount', () {
        final req = requirements.copyWith(amount: 'abc');
        expect(() => signer.sign(req, resource), throwsArgumentError);
      });

      test('throws on negative timeout', () {
        final req = requirements.copyWith(maxTimeoutSeconds: -1);
        expect(() => signer.sign(req, resource), throwsArgumentError);
      });

      test('throws if network mismatches', () {
        final req = requirements.copyWith(
            network:
                const Network(namespace: 'solana', reference: 'wrong-hash'));
        expect(() => signer.sign(req, resource), throwsArgumentError);
      });
    });
  });
}
