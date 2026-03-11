import 'package:x402_svm/src/network/solana_network.dart';

/// Predefined Solana cluster configurations.
///
/// Each cluster defines its genesis hash and a default public RPC URL.
enum SolanaCluster {
  /// The Solana mainnet-beta cluster.
  mainnet('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
      'https://api.mainnet-beta.solana.com'),

  /// The Solana cluster network (for development and testing).
  devnet('EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG',
      'https://api.devnet.solana.com'),

  /// The Solana clustor network.
  testnet('4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY',
      'https://api.testnet.solana.com');

  /// The genesis hash of the cluster, used for CAIP-2 identification.
  final String genesisHash;

  /// The default public RPC URL for this cluster.
  final String rpcUrl;

  const SolanaCluster(this.genesisHash, this.rpcUrl);

  /// Returns the CAIP-2 network identifier for this cluster.
  ///
  /// Note: The genesis hash is truncated to 32 characters for compatibility
  /// with the x402 TypeScript reference implementation.
  SolanaNetwork get network => SolanaNetwork.fromCluster(this);
}
