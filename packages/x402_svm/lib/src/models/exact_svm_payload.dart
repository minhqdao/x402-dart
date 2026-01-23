/// x402 Exact-scheme payload for SVM (Solana).
///
/// Contains a **fully signed Solana transaction** encoded as base64.
/// The transaction bytes are the single source of truth for all fields
/// (instructions, blockhash, fee payer, signatures).
class ExactSvmPayload {
  /// Base64-encoded serialized Solana transaction.
  final String transaction;

  const ExactSvmPayload(this.transaction);
}
