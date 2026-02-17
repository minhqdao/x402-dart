import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/x402_svm.dart';

void main() {
  group('SolanaCluster', () {
    test('has correct genesis hashes', () {
      expect(SolanaCluster.mainnet.genesisHash,
          equals('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d'));
      expect(SolanaCluster.devnet.genesisHash,
          equals('EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG'));
      expect(SolanaCluster.testnet.genesisHash,
          equals('4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY'));
    });

    test('has correct RPC URLs', () {
      expect(SolanaCluster.mainnet.rpcUrl,
          equals('https://api.mainnet-beta.solana.com'));
      expect(
          SolanaCluster.devnet.rpcUrl, equals('https://api.devnet.solana.com'));
      expect(SolanaCluster.testnet.rpcUrl,
          equals('https://api.testnet.solana.com'));
    });

    test('toNetwork produces correct CAIP-2 identifiers with truncated hash',
        () {
      final mainnet = SolanaCluster.mainnet.toNetwork();
      expect(mainnet.namespace, equals('solana'));
      expect(mainnet.reference, equals('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'));
      expect(mainnet.identifier,
          equals('solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'));

      final devnet = SolanaCluster.devnet.toNetwork();
      expect(devnet.reference, equals('EtWTRABZaYq6iMfeYKouRu166VU2xqa1'));
      expect(
          devnet.identifier, equals('solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1'));

      final testnet = SolanaCluster.testnet.toNetwork();
      expect(testnet.reference, equals('4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z'));
      expect(testnet.identifier,
          equals('solana:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z'));
    });

    test('toNetwork returns a Network instance', () {
      final network = SolanaCluster.mainnet.toNetwork();
      expect(network, isA<Network>());
    });

    test('all clusters produce distinct networks', () {
      final networks = SolanaCluster.values.map((c) => c.toNetwork()).toSet();
      expect(networks.length, equals(3)); // All unique after truncation
    });

    test('truncates genesis hash to 32 characters', () {
      for (final cluster in SolanaCluster.values) {
        final network = cluster.toNetwork();
        expect(network.reference.length, equals(32));
        expect(network.reference, equals(cluster.genesisHash.substring(0, 32)));
      }
    });
  });
}
