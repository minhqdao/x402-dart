import 'dart:convert';
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';

/// Utilities for building SVM transactions for x402
class SvmTransactionBuilder {
  const SvmTransactionBuilder._();

  /// Create a transfer transaction for SPL token
  static Future<String> createTransferTransaction({
    required Ed25519HDKeyPair signer,
    required String recipient,
    required BigInt amount,
    required String tokenMint,
    required SolanaClient solanaClient,
  }) async {
    final sourcePublicKey = await signer.extractPublicKey();
    final destinationPublicKey = Ed25519HDPublicKey.fromBase58(recipient);
    final mintPublicKey = Ed25519HDPublicKey.fromBase58(tokenMint);

    // Get associated token accounts
    final sourceTokenAccount = await getAssociatedTokenAddress(mint: mintPublicKey, owner: sourcePublicKey);

    final destinationTokenAccount = await getAssociatedTokenAddress(mint: mintPublicKey, owner: destinationPublicKey);

    // Get recent blockhash
    final blockhashResult = await solanaClient.rpcClient.getLatestBlockhash();
    final blockhash = blockhashResult.value.blockhash;

    // Build instructions
    final instructions = <Instruction>[];

    Instruction setComputeUnitLimit(int units) {
      return Instruction(
        programId: ComputeBudgetProgram.id,
        accounts: const [],
        data: ByteArray.merge([ComputeBudgetProgram.setComputeUnitLimitIndex, ByteArray.u32(units)]),
      );
    }

    Instruction setComputeUnitPrice(int microLamports) {
      return Instruction(
        programId: ComputeBudgetProgram.id,
        accounts: const [],
        data: ByteArray.merge([ComputeBudgetProgram.setComputeUnitPriceIndex, ByteArray.u64(microLamports)]),
      );
    }

    // Add compute budget instructions for priority
    instructions
      ..add(setComputeUnitLimit(200000))
      ..add(setComputeUnitPrice(1));

    // Check if destination token account exists, create if not
    try {
      await solanaClient.rpcClient.getAccountInfo(destinationTokenAccount.toBase58());
    } catch (e) {
      Instruction createAssociatedTokenAccount({
        required Ed25519HDPublicKey funder,
        required Ed25519HDPublicKey ata,
        required Ed25519HDPublicKey owner,
        required Ed25519HDPublicKey mint,
      }) {
        return Instruction(
          programId: AssociatedTokenAccountProgram.id,
          accounts: [
            AccountMeta.writeable(pubKey: funder, isSigner: true),
            AccountMeta.writeable(pubKey: ata, isSigner: false),
            AccountMeta.readonly(pubKey: owner, isSigner: false),
            AccountMeta.readonly(pubKey: mint, isSigner: false),
            AccountMeta.readonly(pubKey: SystemProgram.id, isSigner: false),
            AccountMeta.readonly(pubKey: TokenProgram.id, isSigner: false),
            AccountMeta.readonly(pubKey: Ed25519HDPublicKey.fromBase58(Sysvar.rent), isSigner: false),
          ],
          data: const ByteArray.empty(), // ATA program uses empty data
        );
      }

      // Destination account doesn't exist, add create instruction
      instructions.add(
        createAssociatedTokenAccount(
          funder: sourcePublicKey,
          ata: destinationTokenAccount,
          owner: destinationPublicKey,
          mint: mintPublicKey,
        ),
      );
    }

    // Default to 6 decimals if we can't determine
    const decimals = 6;

    Instruction transferChecked({
      required Ed25519HDPublicKey source,
      required Ed25519HDPublicKey destination,
      required Ed25519HDPublicKey owner,
      required Ed25519HDPublicKey mint,
      required int amount,
      required int decimals,
    }) {
      return Instruction(
        programId: TokenProgram.id,
        accounts: [
          AccountMeta.writeable(pubKey: source, isSigner: false),
          AccountMeta.readonly(pubKey: mint, isSigner: false),
          AccountMeta.writeable(pubKey: destination, isSigner: false),
          AccountMeta.readonly(pubKey: owner, isSigner: true),
        ],
        data: ByteArray.merge([
          TokenProgram.transferCheckedInstructionIndex,
          ByteArray.u64(amount),
          ByteArray.u8(decimals),
        ]),
      );
    }

    instructions.add(
      transferChecked(
        source: sourceTokenAccount,
        destination: destinationTokenAccount,
        owner: sourcePublicKey,
        mint: mintPublicKey,
        amount: amount.toInt(),
        decimals: decimals,
      ),
    );

    // Create transaction
    final message = Message(instructions: instructions);

    final compiledMessage = message.compile(recentBlockhash: blockhash, feePayer: sourcePublicKey);

    // Sign transaction
    final signature = await signer.sign(compiledMessage.toByteArray());

    final transaction = SignedTx(
      compiledMessage: compiledMessage,
      signatures: [Signature(publicKey: sourcePublicKey, signature.bytes)],
    );

    // Serialize and encode
    return transaction.encode();
  }

  /// Get associated token address
  static Future<Ed25519HDPublicKey> getAssociatedTokenAddress({
    required Ed25519HDPublicKey mint,
    required Ed25519HDPublicKey owner,
  }) {
    // Find program address
    final seeds = [owner.bytes, TokenProgram.id.bytes, mint.bytes];

    return Ed25519HDPublicKey.findProgramAddress(seeds: seeds, programId: AssociatedTokenAccountProgram.id);
  }

  /// Decode and verify a transaction
  static DecodedTransaction decodeTransaction(String encodedTx) {
    final txBytes = base64Decode(encodedTx);
    final tx = SignedTx.fromBytes(txBytes);

    final msg = tx.compiledMessage;

    return DecodedTransaction(
      instructions: msg.instructions,
      accountKeys: msg.accountKeys,
      feePayer: msg.accountKeys.first,
      blockhash: msg.recentBlockhash,
      signatures: tx.signatures,
    );
  }

  /// Verify transaction structure for exact scheme
  static Future<bool> verifyTransactionStructure({
    required DecodedTransaction decoded,
    required String expectedRecipient,
    required BigInt expectedAmount,
    required String tokenMint,
  }) async {
    if (decoded.instructions.isEmpty) return false;

    final ix = decoded.instructions.last;

    // 1. Program ID must be Token Program
    final programId = decoded.accountKeys[ix.programIdIndex];
    if (programId != TokenProgram.id) return false;

    // 2. Instruction data
    final data = ix.data;

    if (data.isEmpty || data.first != TokenProgram.transferCheckedInstructionIndex.first) {
      return false;
    }

    int readU64LE(List<int> bytes, int offset) {
      var value = 0;
      for (var i = 0; i < 8; i++) {
        value |= (bytes[offset + i] & 0xff) << (8 * i);
      }
      return value;
    }

    // 3. Amount (u64 LE)
    final amount = readU64LE(data.toList(), 1);
    if (amount != expectedAmount.toInt()) return false;

    // 4. Mint
    final mintKey = decoded.accountKeys[ix.accountKeyIndexes[1]].toBase58();
    if (mintKey != tokenMint) return false;

    // 5. Destination
    final destination = decoded.accountKeys[ix.accountKeyIndexes[2]].toBase58();

    // Derive expected ATA
    final recipientKey = Ed25519HDPublicKey.fromBase58(expectedRecipient);
    final mintPublicKey = Ed25519HDPublicKey.fromBase58(tokenMint);
    final expectedATA = await getAssociatedTokenAddress(mint: mintPublicKey, owner: recipientKey);

    if (destination != expectedATA.toBase58()) return false;

    return true;
  }
}

/// Decoded SVM transaction
class DecodedTransaction {
  final List<CompiledInstruction> instructions;
  final List<Ed25519HDPublicKey> accountKeys;
  final Ed25519HDPublicKey feePayer;
  final String blockhash;
  final List<Signature> signatures;

  const DecodedTransaction({
    required this.instructions,
    required this.accountKeys,
    required this.feePayer,
    required this.blockhash,
    required this.signatures,
  });
}
