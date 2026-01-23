import 'dart:convert';

import 'package:solana/dto.dart' show BinaryAccountData, Encoding;
import 'package:solana/encoder.dart';
import 'package:solana/solana.dart';
import 'package:x402_svm/src/models/exact_svm_payload.dart';

/// Utilities for building SVM (Solana) transactions specifically for the x402 protocol.
///
/// This builder provides methods to construct and sign transactions that perform
/// SPL Token transfers in a way that matches the protocol requirements.
class SvmTransactionBuilder {
  const SvmTransactionBuilder._();

  /// Creates a signed Solana transaction for an SPL Token transfer.
  ///
  /// This method constructs a transaction containing:
  /// 1. A compute unit limit instruction (fixed at 200,000).
  /// 2. A compute unit price instruction (fixed at 1 microlamport).
  /// 3. A `transferChecked` instruction for the SPL Token transfer.
  ///
  /// The transaction is partially signed by the [signer] (the authority).
  /// If the [feePayer] is different from the [signer], a placeholder signature
  /// is added for the fee payer.
  ///
  /// Parameters:
  /// - [signer]: The account authorizing the token transfer.
  /// - [recipient]: The public address (Base58) of the recipient.
  /// - [amount]: The amount to transfer in the smallest unit of the token.
  /// - [tokenMint]: The public address (Base58) of the SPL Token mint.
  /// - [feePayer]: The public address (Base58) of the account paying for transaction fees.
  /// - [solanaClient]: The Solana client used to fetch account info and blockhashes.
  ///
  /// Returns an [ExactSvmPayload] containing the base64-encoded wire transaction.
  ///
  /// Throws an [Exception] if the token mint account is not found.
  static Future<ExactSvmPayload> createTransferTransaction({
    required Ed25519HDKeyPair signer,
    required String recipient,
    required BigInt amount,
    required String tokenMint,
    required String feePayer,
    required SolanaClient solanaClient,
  }) async {
    // Parse public keys
    final signerPublicKey = await signer.extractPublicKey();
    final mintPublicKey = Ed25519HDPublicKey.fromBase58(tokenMint);
    final recipientPublicKey = Ed25519HDPublicKey.fromBase58(recipient);
    final feePayerPublicKey = Ed25519HDPublicKey.fromBase58(feePayer);

    // Get token mint info to determine decimals and validate program
    final mintInfo = await solanaClient.rpcClient
        .getAccountInfo(tokenMint, encoding: Encoding.base64);
    if (mintInfo.value == null) throw Exception('Token mint account not found');

    // BinaryAccountData has a 'data' property that contains the bytes
    final mintData = mintInfo.value!.data;
    int decimals = 6; // default fallback

    if (mintData is BinaryAccountData) {
      // Access the underlying bytes from BinaryAccountData
      final bytes = mintData.data;
      if (bytes.length > 44) decimals = bytes[44];
    }

    // Find associated token accounts
    final sourceATA = await getAssociatedTokenAddress(
        mint: mintPublicKey, owner: signerPublicKey);
    final destinationATA = await getAssociatedTokenAddress(
        mint: mintPublicKey, owner: recipientPublicKey);

    // Get recent blockhash
    final blockhashResult = await solanaClient.rpcClient.getLatestBlockhash();
    final blockhash = blockhashResult.value.blockhash;

    // Build instructions (matching TS order exactly)
    final instructions = <Instruction>[];

    // 1. Set compute unit limit
    instructions.add(_setComputeUnitLimit(200000));

    // 2. Set compute unit price
    instructions.add(_setComputeUnitPrice(1));

    // 3. Transfer checked instruction
    instructions.add(_transferChecked(
      source: sourceATA,
      destination: destinationATA,
      owner: signerPublicKey,
      mint: mintPublicKey,
      amount: amount.toInt(),
      decimals: decimals,
    ));

    // Create message with feePayer
    final message = Message(instructions: instructions);
    final compiledMessage = message.compile(
        recentBlockhash: blockhash, feePayer: feePayerPublicKey);

    // Partially sign with only the signer (authority)
    final signature = await signer.sign(compiledMessage.toByteArray());

    final signatures = <Signature>[];

    if (feePayerPublicKey.toBase58() != signerPublicKey.toBase58()) {
      signatures
          .add(Signature(List.filled(64, 0), publicKey: feePayerPublicKey));
    }

    signatures.add(Signature(signature.bytes, publicKey: signerPublicKey));
    final transaction =
        SignedTx(compiledMessage: compiledMessage, signatures: signatures);

    final base64EncodedWireTransaction = transaction.encode();
    return ExactSvmPayload(base64EncodedWireTransaction);
  }

  /// Creates an instruction to set the compute unit limit.
  static Instruction _setComputeUnitLimit(int units) {
    return Instruction(
      programId: ComputeBudgetProgram.id,
      accounts: const [],
      data: ByteArray.merge([
        ComputeBudgetProgram.setComputeUnitLimitIndex,
        ByteArray.u32(units),
      ]),
    );
  }

  /// Creates an instruction to set the compute unit price (prioritization fee).
  static Instruction _setComputeUnitPrice(int microLamports) {
    return Instruction(
      programId: ComputeBudgetProgram.id,
      accounts: const [],
      data: ByteArray.merge([
        ComputeBudgetProgram.setComputeUnitPriceIndex,
        ByteArray.u64(microLamports),
      ]),
    );
  }

  /// Creates a `transferChecked` instruction for SPL Token transfers.
  static Instruction _transferChecked({
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

  /// Derives the Associated Token Account (ATA) address for a given [mint] and [owner].
  static Future<Ed25519HDPublicKey> getAssociatedTokenAddress({
    required Ed25519HDPublicKey mint,
    required Ed25519HDPublicKey owner,
  }) {
    final seeds = [owner.bytes, TokenProgram.id.bytes, mint.bytes];
    return Ed25519HDPublicKey.findProgramAddress(
      seeds: seeds,
      programId: AssociatedTokenAccountProgram.id,
    );
  }

  /// Decodes a base64-encoded wire transaction into its constituent parts.
  static _DecodedTransaction decodeTransaction(String encodedTx) {
    final txBytes = base64Decode(encodedTx);
    final tx = SignedTx.fromBytes(txBytes);
    final msg = tx.compiledMessage;

    return _DecodedTransaction(
      instructions: msg.instructions,
      accountKeys: msg.accountKeys,
      feePayer: msg.accountKeys.first,
      blockhash: msg.recentBlockhash,
      signatures: tx.signatures,
    );
  }

  /// Verifies that a decoded transaction matches the expected structure for the "exact" scheme.
  ///
  /// Validation checks:
  /// 1. Transaction must have exactly 3 instructions.
  /// 2. The last instruction must be a Token Program transfer.
  /// 3. The transfer amount must match [expectedAmount].
  /// 4. The token mint must match [tokenMint].
  /// 5. The destination ATA must be derived correctly from [expectedRecipient] and [tokenMint].
  static Future<bool> verifyTransactionStructure({
    required _DecodedTransaction decoded,
    required String expectedRecipient,
    required BigInt expectedAmount,
    required String tokenMint,
  }) async {
    // Exactly 3 instructions: ComputePrice + ComputeLimit + TransferChecked
    if (decoded.instructions.length != 3) return false;

    final ix = decoded.instructions.last;

    // 1. Program ID must be Token Program
    final programId = decoded.accountKeys[ix.programIdIndex];
    if (programId != TokenProgram.id) return false;

    // 2. Instruction data
    final data = ix.data;
    if (data.isEmpty ||
        data.first != TokenProgram.transferCheckedInstructionIndex.first) {
      return false;
    }

    // 3. Amount (u64 LE)
    final amount = _readU64LE(data.toList(), 1);
    if (amount != expectedAmount.toInt()) return false;

    // 4. Mint
    final mintKey = decoded.accountKeys[ix.accountKeyIndexes[1]].toBase58();
    if (mintKey != tokenMint) return false;

    // 5. Destination
    final destination = decoded.accountKeys[ix.accountKeyIndexes[2]].toBase58();

    // Derive expected ATA
    final recipientKey = Ed25519HDPublicKey.fromBase58(expectedRecipient);
    final mintPublicKey = Ed25519HDPublicKey.fromBase58(tokenMint);
    final expectedATA = await getAssociatedTokenAddress(
      mint: mintPublicKey,
      owner: recipientKey,
    );

    if (destination != expectedATA.toBase58()) return false;

    return true;
  }

  /// Reads a 64-bit unsigned integer from [bytes] at [offset] in Little-Endian format.
  static int _readU64LE(List<int> bytes, int offset) {
    var value = 0;
    for (var i = 0; i < 8; i++) {
      value |= (bytes[offset + i] & 0xff) << (8 * i);
    }
    return value;
  }
}

/// A decoded representation of a Solana transaction for internal verification.
class _DecodedTransaction {
  /// The list of compiled instructions in the transaction.
  final List<CompiledInstruction> instructions;

  /// All account public keys referenced by the transaction.
  final List<Ed25519HDPublicKey> accountKeys;

  /// The account designated as the fee payer.
  final Ed25519HDPublicKey feePayer;

  /// The recent blockhash used in the transaction.
  final String blockhash;

  /// The list of signatures attached to the transaction.
  final List<Signature> signatures;

  const _DecodedTransaction({
    required this.instructions,
    required this.accountKeys,
    required this.feePayer,
    required this.blockhash,
    required this.signatures,
  });
}
