import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_evm/src/utils/eip3009.dart';

void main() {
  group('EIP3009', () {
    late EthPrivateKey privateKey;
    late String tokenAddress;
    late int chainId;
    const toAddress = '0x209693Bc6afc0C5328bA36FaF03C514EF312287C';
    final value = BigInt.from(10000);
    final validAfter = BigInt.from(1000);
    final validBefore = BigInt.from(2000);
    const tokenName = 'USD Coin';
    const tokenVersion = '2';

    setUp(() {
      // Test private key
      privateKey = EthPrivateKey.fromHex(
          '0x1234567890123456789012345678901234567890123456789012345678901234');
      tokenAddress = '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
      chainId = 8453; // Base mainnet
    });

    group('generateNonce', () {
      test('should generate 32-byte nonce', () {
        final nonce = EIP3009.generateNonce();
        expect(nonce.length, equals(32));
      });

      test('should generate unique nonces', () {
        final nonce1 = EIP3009.generateNonce();
        final nonce2 = EIP3009.generateNonce();
        expect(nonce1, isNot(equals(nonce2)));
      });
    });

    group('createAuthorizationSignature & verifyAuthorizationSignature', () {
      test('should create and verify valid signature', () {
        final nonce = EIP3009.generateNonce();

        final signature = EIP3009.createAuthorizationSignature(
          privateKey: privateKey,
          tokenAddress: tokenAddress,
          chainId: chainId,
          tokenName: tokenName,
          tokenVersion: tokenVersion,
          to: toAddress,
          value: value,
          validAfter: validAfter,
          validBefore: validBefore,
          nonce: nonce,
        );

        final isValid = EIP3009.verifyAuthorizationSignature(
          tokenAddress: tokenAddress,
          chainId: chainId,
          tokenName: tokenName,
          tokenVersion: tokenVersion,
          from: privateKey.address.hex,
          to: toAddress,
          value: value,
          validAfter: validAfter,
          validBefore: validBefore,
          nonce: nonce,
          signature: signature,
        );

        expect(isValid, isTrue);
      });

      test('should reject signature with mismatched parameters (wrong value)',
          () {
        final nonce = EIP3009.generateNonce();

        final signature = EIP3009.createAuthorizationSignature(
          privateKey: privateKey,
          tokenAddress: tokenAddress,
          chainId: chainId,
          tokenName: tokenName,
          tokenVersion: tokenVersion,
          to: toAddress,
          value: value,
          validAfter: validAfter,
          validBefore: validBefore,
          nonce: nonce,
        );

        final isValid = EIP3009.verifyAuthorizationSignature(
          tokenAddress: tokenAddress,
          chainId: chainId,
          tokenName: tokenName,
          tokenVersion: tokenVersion,
          from: privateKey.address.hex,
          to: toAddress,
          value: BigInt.from(99999), // Wrong value
          validAfter: validAfter,
          validBefore: validBefore,
          nonce: nonce,
          signature: signature,
        );

        expect(isValid, isFalse);
      });

      test('should reject signature with mismatched parameters (wrong sender)',
          () {
        final nonce = EIP3009.generateNonce();

        final signature = EIP3009.createAuthorizationSignature(
          privateKey: privateKey,
          tokenAddress: tokenAddress,
          chainId: chainId,
          tokenName: tokenName,
          tokenVersion: tokenVersion,
          to: toAddress,
          value: value,
          validAfter: validAfter,
          validBefore: validBefore,
          nonce: nonce,
        );

        final isValid = EIP3009.verifyAuthorizationSignature(
          tokenAddress: tokenAddress,
          chainId: chainId,
          tokenName: tokenName,
          tokenVersion: tokenVersion,
          from: '0x0000000000000000000000000000000000000000', // Wrong sender
          to: toAddress,
          value: value,
          validAfter: validAfter,
          validBefore: validBefore,
          nonce: nonce,
          signature: signature,
        );

        expect(isValid, isFalse);
      });
    });

    group('encodeSignature & decodeSignature', () {
      test('should round-trip encode and decode', () {
        final nonce = EIP3009.generateNonce();

        final signature = EIP3009.createAuthorizationSignature(
          privateKey: privateKey,
          tokenAddress: tokenAddress,
          chainId: chainId,
          tokenName: tokenName,
          tokenVersion: tokenVersion,
          to: toAddress,
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
  });
}
