import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/x402_svm.dart';

void main() {
  group('SolanaNetwork', () {
    test('mainnet factory produces correct CAIP-2 identifier', () {
      final network = SolanaNetwork.mainnet();
      expect(network.namespace, equals('solana'));
      expect(network.reference, equals('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'));
      expect(network.identifier,
          equals('solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'));
    });

    test('devnet factory produces correct CAIP-2 identifier', () {
      final network = SolanaNetwork.devnet();
      expect(network.namespace, equals('solana'));
      expect(network.reference, equals('EtWTRABZaYq6iMfeYKouRu166VU2xqa1'));
      expect(network.identifier,
          equals('solana:EtWTRABZaYq6iMfeYKouRu166VU2xqa1'));
    });

    test('testnet factory produces correct CAIP-2 identifier', () {
      final network = SolanaNetwork.testnet();
      expect(network.namespace, equals('solana'));
      expect(network.reference, equals('4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z'));
      expect(network.identifier,
          equals('solana:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z'));
    });

    test('fromCluster factory produces correct CAIP-2 identifier', () {
      final network = SolanaNetwork.fromCluster(SolanaCluster.mainnet);
      expect(network.namespace, equals('solana'));
      expect(network.reference, equals('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'));
    });

    test('is a Network instance', () {
      final network = SolanaNetwork.mainnet();
      expect(network, isA<Network>());
    });

    test('equality works correctly', () {
      final network1 = SolanaNetwork.mainnet();
      final network2 = SolanaNetwork.mainnet();
      final network3 = SolanaNetwork.devnet();

      expect(network1, equals(network2));
      expect(network1, isNot(equals(network3)));
    });

    test('hashCode is consistent', () {
      final network1 = SolanaNetwork.mainnet();
      final network2 = SolanaNetwork.mainnet();

      expect(network1.hashCode, equals(network2.hashCode));
    });

    test('toString returns identifier', () {
      final network = SolanaNetwork.mainnet();
      expect(network.toString(),
          equals('solana:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp'));
    });
  });
}
