import 'package:x402_svm/src/network/solana_network.dart';

/// The prefix for the Solana mainnet-beta genesis hash.
const solanaMainnetGenesisPrefix = '5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp';

/// The prefix for the Solana devnet genesis hash.
const solanaDevnetGenesisPrefix = 'EtWTRABZaYq6iMfeYKouRu166VU2xqa1';

/// The prefix for the Solana testnet genesis hash.
const solanaTestnetGenesisPrefix = '4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z';

/// Predefined Solana cluster configurations.
///
/// Each cluster defines its genesis hash and a default public RPC URL.
enum SolanaCluster {
  /// The Solana mainnet-beta cluster.
  mainnet(solanaMainnetGenesisPrefix, 'Kuc147dw2N9d',
      'https://api.mainnet-beta.solana.com'),

  /// The Solana cluster network (for development and testing).
  devnet(solanaDevnetGenesisPrefix, 'wcaWoxPkrZBG',
      'https://api.devnet.solana.com'),

  /// The Solana cluster network.
  testnet(solanaTestnetGenesisPrefix, 'Qawwpjk2NsNY',
      'https://api.testnet.solana.com');

  /// The prefix of the cluster-specific genesis hash.
  final String genesisHashPrefix;

  /// The suffix of the cluster-specific genesis hash.
  final String genesisHashSuffix;

  /// The default public RPC URL for this cluster.
  final String rpcUrl;

  const SolanaCluster(
      this.genesisHashPrefix, this.genesisHashSuffix, this.rpcUrl);

  /// Returns the CAIP-2 network identifier for this cluster.
  ///
  /// Note: The genesis hash is truncated to 32 characters for compatibility
  /// with the x402 TypeScript reference implementation.
  SolanaNetwork get network => SolanaNetwork.fromCluster(this);

  /// Returns the genesis hash for this cluster.
  String get genesisHash => '$genesisHashPrefix$genesisHashSuffix';
}
