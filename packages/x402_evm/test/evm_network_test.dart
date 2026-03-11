import 'package:test/test.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

void main() {
  group('EvmNetwork', () {
    test('default constructor produces eip155 reference', () {
      const network = EvmNetwork(chainId: 1);
      expect(network.namespace, equals('eip155'));
      expect(network.reference, equals('1'));
      expect(network.identifier, equals('eip155:1'));
    });

    test('can override namespace', () {
      const network = EvmNetwork(chainId: 137, namespace: 'polygon');
      expect(network.namespace, equals('polygon'));
      expect(network.reference, equals('137'));
      expect(network.identifier, equals('polygon:137'));
    });

    test('is a Network instance', () {
      const network = EvmNetwork(chainId: 8453);
      expect(network, isA<Network>());
    });

    test('handles large chain IDs correctly', () {
      const network = EvmNetwork(chainId: 999999999);
      expect(network.reference, equals('999999999'));
      expect(network.identifier, equals('eip155:999999999'));
    });

    test('equality works correctly', () {
      const network1 = EvmNetwork(chainId: 1);
      const network2 = EvmNetwork(chainId: 1);
      const network3 = EvmNetwork(chainId: 2);

      expect(network1, equals(network2));
      expect(network1, isNot(equals(network3)));
    });

    test('hashCode is consistent', () {
      const network1 = EvmNetwork(chainId: 1);
      const network2 = EvmNetwork(chainId: 1);

      expect(network1.hashCode, equals(network2.hashCode));
    });

    test('toString returns identifier', () {
      const network = EvmNetwork(chainId: 8453);
      expect(network.toString(), equals('eip155:8453'));
    });

    test('common chain IDs work correctly', () {
      const mainnet = EvmNetwork(chainId: 1);
      const base = EvmNetwork(chainId: 8453);
      const arbitrum = EvmNetwork(chainId: 42161);
      const optimism = EvmNetwork(chainId: 10);

      expect(mainnet.identifier, equals('eip155:1'));
      expect(base.identifier, equals('eip155:8453'));
      expect(arbitrum.identifier, equals('eip155:42161'));
      expect(optimism.identifier, equals('eip155:10'));
    });
  });
}
