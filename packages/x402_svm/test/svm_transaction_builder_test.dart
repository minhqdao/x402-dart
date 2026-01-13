import 'package:mocktail/mocktail.dart';
import 'package:solana/dto.dart';
import 'package:solana/solana.dart';
import 'package:test/test.dart';
import 'package:x402_svm/src/utils/transaction_builder.dart';

class _MockSolanaClient extends Mock implements SolanaClient {}

class _MockRpcClient extends Mock implements RpcClient {}

void main() {
  setUpAll(() => registerFallbackValue(Encoding.base64));

  group('SvmTransactionBuilder', () {
    late _MockSolanaClient mockClient;
    late _MockRpcClient mockRpcClient;
    late Ed25519HDKeyPair testSigner;

    setUp(() async {
      mockClient = _MockSolanaClient();
      mockRpcClient = _MockRpcClient();

      // Set up mock relationship
      when(() => mockClient.rpcClient).thenReturn(mockRpcClient);

      // Create a test signer
      testSigner = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: List.filled(32, 1), // Test private key
      );
    });

    group('Instruction Order Tests', () {
      test('instructions should be in correct order: Limit, Price, Transfer', () async {
        // Arrange
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        const testFeePayer = '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC';
        final amount = BigInt.from(1000000);

        // Mock mint account info
        final mockMintData = List<int>.filled(82, 0);
        mockMintData[44] = 9; // decimals at byte 44

        when(() => mockRpcClient.getAccountInfo(
              testMintAddress,
              encoding: any(named: 'encoding'),
            )).thenAnswer((_) async => AccountResult(
              context: Context(slot: BigInt.from(1)),
              value: Account(
                lamports: 1000000,
                owner: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
                data: BinaryAccountData(mockMintData),
                executable: false,
                rentEpoch: BigInt.zero,
              ),
            ));

        // Mock latest blockhash
        when(() => mockRpcClient.getLatestBlockhash()).thenAnswer(
          (_) async => LatestBlockhashResult(
            context: Context(slot: BigInt.from(1)),
            value: const LatestBlockhash(
              blockhash: '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
              lastValidBlockHeight: 100000,
            ),
          ),
        );

        // Act
        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        // Decode the transaction
        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);

        // Assert
        expect(decoded.instructions.length, equals(3), reason: 'Should have exactly 3 instructions');

        // Check instruction order by program IDs and discriminators
        final ix0 = decoded.instructions[0];
        final ix1 = decoded.instructions[1];
        final ix2 = decoded.instructions[2];

        // Instruction 0: SetComputeUnitLimit
        expect(
          decoded.accountKeys[ix0.programIdIndex],
          equals(ComputeBudgetProgram.id),
          reason: 'First instruction should be ComputeBudget program',
        );
        expect(
          ix0.data.toList().first,
          equals(2),
          reason: 'First instruction should be SetComputeUnitLimit (discriminator 2)',
        );

        // Instruction 1: SetComputeUnitPrice
        expect(
          decoded.accountKeys[ix1.programIdIndex],
          equals(ComputeBudgetProgram.id),
          reason: 'Second instruction should be ComputeBudget program',
        );
        expect(
          ix1.data.toList().first,
          equals(3),
          reason: 'Second instruction should be SetComputeUnitPrice (discriminator 3)',
        );

        // Instruction 2: TransferChecked
        expect(
          decoded.accountKeys[ix2.programIdIndex],
          equals(TokenProgram.id),
          reason: 'Third instruction should be Token program',
        );
        expect(
          ix2.data.toList().first,
          equals(12),
          reason: 'Third instruction should be TransferChecked (discriminator 12)',
        );
      });

      test('compute unit limit should be 200000', () async {
        // Arrange - same setup as above
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        const testFeePayer = '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC';
        final amount = BigInt.from(1000000);

        // Setup mocks (abbreviated for brevity)
        _setupMocks(mockRpcClient, testMintAddress);

        // Act
        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);
        final limitIx = decoded.instructions[0];

        // Assert - Extract u32 value from bytes 1-4 (little-endian)
        final limitBytes = limitIx.data.toList().sublist(1, 5);
        final limit = _readU32LE(limitBytes);

        expect(limit, equals(200000), reason: 'Compute unit limit should be exactly 200000');
      });

      test('compute unit price should be 1 microlamport', () async {
        // Arrange
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        const testFeePayer = '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC';
        final amount = BigInt.from(1000000);

        _setupMocks(mockRpcClient, testMintAddress);

        // Act
        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);
        final priceIx = decoded.instructions[1];

        // Assert - Extract u64 value from bytes 1-8 (little-endian)
        final priceBytes = priceIx.data.toList().sublist(1, 9);
        final price = _readU64LE(priceBytes.toList(), 0);

        expect(price, equals(1), reason: 'Compute unit price should be exactly 1 microlamport');
      });
    });

    group('TransferChecked Instruction Tests', () {
      test('should have correct account structure', () async {
        // Arrange
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        const testFeePayer = '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC';
        final amount = BigInt.from(1000000);

        _setupMocks(mockRpcClient, testMintAddress);

        // Act
        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);
        final transferIx = decoded.instructions[2];

        // Assert
        expect(transferIx.accountKeyIndexes.length, equals(4), reason: 'TransferChecked should have 4 accounts');

        // Account 0: source (writable, not signer)
        // Account 1: mint (readable, not signer)
        // Account 2: destination (writable, not signer)
        // Account 3: authority (readable, signer)
      });

      test('should encode amount and decimals correctly', () async {
        // Arrange
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        const testFeePayer = '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC';
        final amount = BigInt.from(1500000); // 1.5 tokens with 6 decimals

        _setupMocks(mockRpcClient, testMintAddress, decimals: 6);

        // Act
        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);
        final transferIx = decoded.instructions[2];

        // Assert
        // Data format: [discriminator:1][amount:8][decimals:1]
        expect(transferIx.data.length, equals(10), reason: 'TransferChecked data should be 10 bytes');

        final actualAmount = _readU64LE(transferIx.data.toList(), 1);
        expect(actualAmount, equals(1500000), reason: 'Amount should match the input');

        final actualDecimals = transferIx.data.toList()[9];
        expect(actualDecimals, equals(6), reason: 'Decimals should be 6');
      });
    });

    group('Partial Signing Tests', () {
      test('should include placeholder signature for different feePayer', () async {
        // Arrange
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        const testFeePayer = '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC'; // Different from signer
        final amount = BigInt.from(1000000);

        _setupMocks(mockRpcClient, testMintAddress);

        // Act
        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);

        // Assert
        expect(decoded.signatures.length, equals(2),
            reason: 'Should have 2 signatures when feePayer differs from signer');

        // First signature should be all zeros (placeholder)
        final firstSigBytes = decoded.signatures[0].bytes;
        expect(firstSigBytes.every((byte) => byte == 0), isTrue,
            reason: 'First signature should be placeholder (all zeros)');

        // Second signature should be non-zero (actual signature)
        final secondSigBytes = decoded.signatures[1].bytes;
        expect(secondSigBytes.any((byte) => byte != 0), isTrue,
            reason: 'Second signature should be actual signature (non-zero)');
      });

      test('should have only one signature when feePayer is signer', () async {
        // Arrange
        final signerPubkey = await testSigner.extractPublicKey();
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        final testFeePayer = signerPubkey.toBase58(); // Same as signer
        final amount = BigInt.from(1000000);

        _setupMocks(mockRpcClient, testMintAddress);

        // Act
        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);

        // Assert
        expect(decoded.signatures.length, equals(1), reason: 'Should have 1 signature when feePayer is same as signer');
      });
    });

    group('Verification Tests', () {
      test('verifyTransactionStructure should pass for valid transaction', () async {
        // Arrange
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        const testFeePayer = '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC';
        final amount = BigInt.from(1000000);

        _setupMocks(mockRpcClient, testMintAddress);

        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);

        // Act
        final isValid = await SvmTransactionBuilder.verifyTransactionStructure(
          decoded: decoded,
          expectedRecipient: testRecipient,
          expectedAmount: amount,
          tokenMint: testMintAddress,
        );

        // Assert
        expect(isValid, isTrue, reason: 'Valid transaction should pass verification');
      });

      test('verifyTransactionStructure should fail for wrong amount', () async {
        // Arrange
        const testMintAddress = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
        const testRecipient = 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv';
        const testFeePayer = '7vN9772SUn3mbev6pCxyY6SAsbC4TAt796vXvUAm67fC';
        final amount = BigInt.from(1000000);

        _setupMocks(mockRpcClient, testMintAddress);

        final encodedTx = await SvmTransactionBuilder.createTransferTransaction(
          signer: testSigner,
          recipient: testRecipient,
          amount: amount,
          tokenMint: testMintAddress,
          feePayer: testFeePayer,
          solanaClient: mockClient,
        );

        final decoded = SvmTransactionBuilder.decodeTransaction(encodedTx);

        // Act - verify with wrong amount
        final isValid = await SvmTransactionBuilder.verifyTransactionStructure(
          decoded: decoded,
          expectedRecipient: testRecipient,
          expectedAmount: BigInt.from(2000000), // Wrong amount
          tokenMint: testMintAddress,
        );

        // Assert
        expect(isValid, isFalse, reason: 'Transaction with wrong amount should fail verification');
      });
    });
  });
}

// Helper functions
void _setupMocks(_MockRpcClient mockRpcClient, String mintAddress, {int decimals = 9}) {
  final mockMintData = List<int>.filled(82, 0);
  mockMintData[44] = decimals;

  when(() => mockRpcClient.getAccountInfo(
        mintAddress,
        encoding: any(named: 'encoding'),
      )).thenAnswer((_) async => AccountResult(
        context: Context(slot: BigInt.from(1)),
        value: Account(
          lamports: 1000000,
          owner: 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
          data: BinaryAccountData(mockMintData),
          executable: false,
          rentEpoch: BigInt.zero,
        ),
      ));

  when(() => mockRpcClient.getLatestBlockhash()).thenAnswer(
    (_) async => LatestBlockhashResult(
      context: Context(slot: BigInt.from(1)),
      value: const LatestBlockhash(
        blockhash: '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
        lastValidBlockHeight: 100000,
      ),
    ),
  );
}

int _readU32LE(List<int> bytes) {
  var value = 0;
  for (var i = 0; i < 4; i++) {
    value |= (bytes[i] & 0xff) << (8 * i);
  }
  return value;
}

int _readU64LE(List<int> bytes, int offset) {
  var value = 0;
  for (var i = 0; i < 8; i++) {
    value |= (bytes[offset + i] & 0xff) << (8 * i);
  }
  return value;
}
