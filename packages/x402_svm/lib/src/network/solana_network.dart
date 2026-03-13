import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/network/solana_cluster.dart';

/// CAIP-2 Solana network identifier (`solana:<reference>`).
///
/// The reference is derived from the first 32 characters of the
/// cluster genesis hash, per the Solana CAIP-2 specification.
class SolanaNetwork extends Network {
  const SolanaNetwork._(String reference)
      : super(namespace: 'solana', reference: reference);

  /// Solana mainnet-beta.
  const SolanaNetwork.mainnet() : this._(solanaMainnetGenesisPrefix);

  /// Solana devnet.
  const SolanaNetwork.devnet() : this._(solanaDevnetGenesisPrefix);

  /// Solana testnet.
  const SolanaNetwork.testnet() : this._(solanaTestnetGenesisPrefix);

  /// Creates a Solana network from a [SolanaCluster].
  factory SolanaNetwork.fromCluster(SolanaCluster cluster) =>
      SolanaNetwork._(cluster.genesisHashPrefix);
}
