import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/network/solana_cluster.dart';

/// CAIP-2 Solana network identifier (`solana:<reference>`).
///
/// The reference is derived from the first 32 characters of the
/// cluster genesis hash, per the Solana CAIP-2 specification.
class SolanaNetwork extends Network {
  const SolanaNetwork._(String reference)
      : super(namespace: 'solana', reference: reference);

  /// Creates a Solana network from a [SolanaCluster].
  factory SolanaNetwork.fromCluster(SolanaCluster cluster) =>
      SolanaNetwork._(cluster.genesisHash.substring(0, 32));

  /// Solana mainnet-beta.
  factory SolanaNetwork.mainnet() =>
      SolanaNetwork.fromCluster(SolanaCluster.mainnet);

  /// Solana devnet.
  factory SolanaNetwork.devnet() =>
      SolanaNetwork.fromCluster(SolanaCluster.devnet);

  /// Solana testnet.
  factory SolanaNetwork.testnet() =>
      SolanaNetwork.fromCluster(SolanaCluster.testnet);
}
