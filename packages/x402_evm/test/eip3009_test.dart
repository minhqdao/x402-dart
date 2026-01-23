import 'dart:typed_data';

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
    final nonce = Uint8List(32);

    setUp(() {
      // Test private key
      privateKey = EthPrivateKey.fromHex(
          '0x4efa000000000000000000000000000000000000000000000000000000000001');
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

        final expectedR = BigInt.parse(
          '53f48743fe162bb91bfacb155dbfac499e37fb912af76a2d5f473d73e11245a8',
          radix: 16,
        );
        final expectedS = BigInt.parse(
          '4465c6bad84891d4e1d663bf1abe89b04e7f25473eaefe4e434568235dfb613c',
          radix: 16,
        );

        expect(signature.r, expectedR);
        expect(signature.s, expectedS);
        expect(signature.v, equals(28));
        expect(isValid, isTrue);
      });

      test('should reject signature with mismatched parameters (wrong value)',
          () {
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

    group('toFixedLengthBytes', () {
      test('pads small values to 32 bytes', () {
        final bytes = EIP3009.toFixedLengthBytes(BigInt.from(1));
        expect(bytes.length, 32);
        expect(bytes.last, 1);
        expect(bytes.take(31).every((b) => b == 0), isTrue);
      });

      test('value 0 becomes 32 zero bytes', () {
        final bytes = EIP3009.toFixedLengthBytes(BigInt.zero);
        expect(bytes.length, 32);
        expect(bytes.every((b) => b == 0), isTrue);
      });

      test('exact 32 byte value is unchanged', () {
        final value = BigInt.parse(
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            radix: 16);
        final bytes = EIP3009.toFixedLengthBytes(value);
        expect(bytes.length, 32);
        expect(bytes.every((b) => b == 0xff), isTrue);
      });

      test('overflow is truncated from the left', () {
        final value = BigInt.parse(
            '11ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            radix: 16);

        final bytes = EIP3009.toFixedLengthBytes(value);
        expect(bytes.length, 32);

        // first byte should be ff (0x11 removed)
        expect(bytes.first, 0xff);
      });

      test('keeps least significant bytes when truncating', () {
        final value = BigInt.parse(
            '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2021',
            radix: 16);

        final bytes = EIP3009.toFixedLengthBytes(value);
        expect(bytes.length, 32);

        // should end with 0x21
        expect(bytes.last, 0x21);
      });

      test('pads to 8 bytes correctly', () {
        final bytes =
            EIP3009.toFixedLengthBytes(BigInt.from(0x1234), length: 8);

        expect(bytes.length, 8);
        expect(bytes, [0, 0, 0, 0, 0, 0, 0x12, 0x34]);
      });

      test('pads to 4 bytes correctly', () {
        final bytes =
            EIP3009.toFixedLengthBytes(BigInt.from(0xabcd), length: 4);

        expect(bytes.length, 4);
        expect(bytes, [0, 0, 0xab, 0xcd]);
      });

      test('pads single byte length', () {
        final bytes = EIP3009.toFixedLengthBytes(BigInt.from(0xff), length: 1);

        expect(bytes.length, 1);
        expect(bytes[0], 0xff);
      });

      test('truncates when exceeding custom length', () {
        final bytes = EIP3009.toFixedLengthBytes(
          BigInt.parse('1234567890', radix: 16),
          length: 4,
        );

        expect(bytes.length, 4);
        expect(bytes, [0x34, 0x56, 0x78, 0x90]);
      });

      test('large number truncated to 16 bytes', () {
        final value = BigInt.parse(
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            radix: 16);

        final bytes = EIP3009.toFixedLengthBytes(value, length: 16);

        expect(bytes.length, 16);
        expect(bytes.every((b) => b == 0xff), isTrue);
      });

      test('length bigger than needed still pads left', () {
        final bytes = EIP3009.toFixedLengthBytes(BigInt.from(1), length: 64);

        expect(bytes.length, 64);
        expect(bytes.last, 1);
        expect(bytes.take(63).every((b) => b == 0), isTrue);
      });
    });

    group('encodeSignature & decodeSignature', () {
      test('encodeSignature should match ethers output', () {
        final sig = EIP3009.createAuthorizationSignature(
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

        final encoded = EIP3009.encodeSignature(sig);

        expect(encoded,
            '0x53f48743fe162bb91bfacb155dbfac499e37fb912af76a2d5f473d73e11245a84465c6bad84891d4e1d663bf1abe89b04e7f25473eaefe4e434568235dfb613c1c');
      });

      test('decodeSignature should parse ethers signature correctly', () {
        const encoded =
            '0x53f48743fe162bb91bfacb155dbfac499e37fb912af76a2d5f473d73e11245a84465c6bad84891d4e1d663bf1abe89b04e7f25473eaefe4e434568235dfb613c1c';

        final decoded = EIP3009.decodeSignature(encoded);

        expect(
            decoded.r,
            BigInt.parse(
                '37974010685048722055772975357342971235981096899448676344209141836601313346984'));
        expect(
            decoded.s,
            BigInt.parse(
                '30937096840308784273062507715881929567146857402107617852483264071378902147388'));
        expect(decoded.v, 28);
      });

      test('should round-trip encode and decode', () {
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

      test('should round-trip decode and encode', () {
        const jsSig =
            '0x53f48743fe162bb91bfacb155dbfac499e37fb912af76a2d5f473d73e11245a84465c6bad84891d4e1d663bf1abe89b04e7f25473eaefe4e434568235dfb613c1c';

        final decoded = EIP3009.decodeSignature(jsSig);
        final reEncoded = EIP3009.encodeSignature(decoded);

        expect(reEncoded.toLowerCase(), jsSig.toLowerCase());
      });
    });
  });
}
