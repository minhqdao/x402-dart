import 'dart:convert';
import 'package:mocktail/mocktail.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/x402_svm.dart';

class _MockSolanaClient extends Mock implements SolanaClient {}

class _MockRpcClient extends Mock implements RpcClient {}

void main() {
  setUpAll(() {
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
      keyPair = await Ed25519HDKeyPair.random();
      mockSolanaClient = _MockSolanaClient();
      mockRpcClient = _MockRpcClient();

      when(() => mockSolanaClient.rpcClient).thenReturn(mockRpcClient);

      signer = SvmSigner(
        signer: keyPair,
        client: mockSolanaClient,
        genesisHash: 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
      );

      resource = const ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
      );

      requirements = const PaymentRequirement(
        scheme: 'v2:solana:exact',
        network: 'solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
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
            data: const AccountData.empty(),
            executable: false,
            rentEpoch: BigInt.zero,
          ),
          context: Context(slot: BigInt.from(1)),
        ),
      );
    });

    test('should have correct network and scheme', () {
      expect(signer.network, equals('solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1'));
      expect(signer.scheme, equals('v2:solana:exact'));
    });

    test('should have correct address', () async {
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
        extra: {},
      );
      final reqExact = PaymentRequirement(
        scheme: 'exact',
        network: signer.network,
        amount: '1000',
        asset: 'asset',
        payTo: 'payTo',
        maxTimeoutSeconds: 60,
        extra: {},
      );
      const reqBadNetwork = PaymentRequirement(
        scheme: 'exact',
        network: 'bad-network',
        amount: '1000',
        asset: 'asset',
        payTo: 'payTo',
        maxTimeoutSeconds: 60,
        extra: {},
      );
      final reqBadScheme = PaymentRequirement(
        scheme: 'bad-scheme',
        network: signer.network,
        amount: '1000',
        asset: 'asset',
        payTo: 'payTo',
        maxTimeoutSeconds: 60,
        extra: {},
      );

      expect(signer.supports(reqStandard), isTrue);
      expect(signer.supports(reqExact), isTrue);
      expect(signer.supports(reqBadNetwork), isFalse);
      expect(signer.supports(reqBadScheme), isFalse);
    });

    test('should sign and return base64 encoded payload', () async {
      final signature = await signer.sign(requirements, resource);

      expect(signature, isA<String>());
      final decodedJson = jsonDecode(utf8.decode(base64Decode(signature))) as Map<String, dynamic>;
      final payload = PaymentPayload.fromJson(decodedJson);

      expect(payload.x402Version, equals(kX402Version));
      expect(payload.accepted.network, equals(requirements.network));
      expect(payload.payload['transaction'], isNotNull);
    });

    test('should include extensions if provided', () async {
      final extensions = {'test': 'extension'};
      final signature = await signer.sign(requirements, resource, extensions: extensions);

      final decodedJson = jsonDecode(utf8.decode(base64Decode(signature))) as Map<String, dynamic>;
      final payload = PaymentPayload.fromJson(decodedJson);

      expect(payload.extensions, equals(extensions));
    });
  });
}
