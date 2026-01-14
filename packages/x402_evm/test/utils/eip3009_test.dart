import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_evm/src/utils/eip3009.dart';

void main() {
  group('EIP3009', () {
    late EthPrivateKey privateKey;
    late String tokenAddress;
    late int chainId;

    setUp(() {
      // Test private key
      privateKey = EthPrivateKey.fromHex(
          '0x1234567890123456789012345678901234567890123456789012345678901234');
      tokenAddress = '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
      chainId = 8453; // Base mainnet
    });

    test('should generate random nonce', () {
      final nonce1 = EIP3009.generateNonce();
      final nonce2 = EIP3009.generateNonce();

      expect(nonce1.length, equals(32));
      expect(nonce2.length, equals(32));
      expect(nonce1, isNot(equals(nonce2)));
    });

    test('should create and verify authorization signature', () {
      const to = '0x209693Bc6afc0C5328bA36FaF03C514EF312287C';
      final value = BigInt.from(10000);
      final validAfter = BigInt.from(1000);
      final validBefore = BigInt.from(2000);
      final nonce = EIP3009.generateNonce();

      final signature = EIP3009.createAuthorizationSignature(
        privateKey: privateKey,
        tokenAddress: tokenAddress,
        chainId: chainId,
        tokenName: 'USD Coin',
        tokenVersion: '2',
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
      );

      final isValid = EIP3009.verifyAuthorizationSignature(
        tokenAddress: tokenAddress,
        chainId: chainId,
        tokenName: 'USD Coin',
        tokenVersion: '2',
        from: privateKey.address.hex,
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
        signature: signature,
      );

      expect(isValid, isTrue);
    });

    test('should reject signature with wrong parameters', () {
      const to = '0x209693Bc6afc0C5328bA36FaF03C514EF312287C';
      final value = BigInt.from(10000);
      final validAfter = BigInt.from(1000);
      final validBefore = BigInt.from(2000);
      final nonce = EIP3009.generateNonce();

      final signature = EIP3009.createAuthorizationSignature(
        privateKey: privateKey,
        tokenAddress: tokenAddress,
        chainId: chainId,
        tokenName: 'USD Coin',
        tokenVersion: '2',
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
      );

      // Verify with wrong value
      final isValid = EIP3009.verifyAuthorizationSignature(
        tokenAddress: tokenAddress,
        chainId: chainId,
        tokenName: 'USD Coin',
        tokenVersion: '2',
        from: privateKey.address.hex,
        to: to,
        value: BigInt.from(20000), // Wrong value
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
        signature: signature,
      );

      expect(isValid, isFalse);
    });

    test('should encode and decode signature', () {
      const to = '0x209693Bc6afc0C5328bA36FaF03C514EF312287C';
      final value = BigInt.from(10000);
      final validAfter = BigInt.from(1000);
      final validBefore = BigInt.from(2000);
      final nonce = EIP3009.generateNonce();

      final signature = EIP3009.createAuthorizationSignature(
        privateKey: privateKey,
        tokenAddress: tokenAddress,
        chainId: chainId,
        tokenName: 'USD Coin',
        tokenVersion: '2',
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
      );

      final encoded = EIP3009.encodeSignature(signature);
      final decoded = EIP3009.decodeSignature(encoded);

      expect(decoded.r, equals(signature.r));
      expect(decoded.s, equals(signature.s));
      expect(decoded.v, equals(signature.v));
    });
  });
}
