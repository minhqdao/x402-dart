import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_evm/src/utils/eip712.dart';

void main() {
  group('EIP712Domain', () {
    test('should creation and serialization work', () {
      const domain = EIP712Domain(
        name: 'USDC',
        version: '2',
        chainId: 1,
        verifyingContract: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      );

      expect(domain.name, 'USDC');
      expect(domain.version, '2');
      expect(domain.chainId, 1);
      expect(domain.verifyingContract,
          '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48');

      final json = domain.toJson();
      expect(json, {
        'name': 'USDC',
        'version': '2',
        'chainId': 1,
        'verifyingContract': '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      });
    });
  });

  group('EIP712Utils', () {
    const domain = EIP712Domain(
      name: 'USDC',
      version: '2',
      chainId: 1,
      verifyingContract: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    );

    const from = '0x1234567890123456789012345678901234567890';
    const to = '0x0987654321098765432109876543210987654321';
    final value = BigInt.from(1000);
    final validAfter = BigInt.zero;
    final validBefore = BigInt.from(3600);
    final nonce = Uint8List(32); // Zero nonce

    // A valid private key for testing signing/recovery
    final privateKey = EthPrivateKey.fromHex(
        '0x4efa000000000000000000000000000000000000000000000000000000000001');

    test('computeDomainSeparator should be consistent', () {
      final separator = EIP712Utils.computeDomainSeparator(domain);
      expect(separator, isA<Uint8List>());
      expect(separator.length, 32);
      // Ensure determinism
      final separator2 = EIP712Utils.computeDomainSeparator(domain);
      expect(bytesToHex(separator), bytesToHex(separator2));
    });

    test('computeDomainSeparator returns correct bytes', () {
      final separator = EIP712Utils.computeDomainSeparator(domain);
      expect(separator, const [
        230,
        152,
        78,
        152,
        38,
        133,
        201,
        209,
        68,
        120,
        66,
        116,
        99,
        163,
        67,
        153,
        216,
        43,
        178,
        139,
        150,
        59,
        231,
        11,
        125,
        165,
        157,
        45,
        102,
        105,
        99,
        245
      ]);
    });

    test('hashTransferWithAuthorization should return correct hash', () {
      final hash = EIP712Utils.hashTransferWithAuthorization(
        from: from,
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
      );

      expect(hash, isA<Uint8List>());
      expect(hash, const [
        106,
        100,
        201,
        237,
        238,
        75,
        174,
        81,
        16,
        51,
        231,
        116,
        41,
        13,
        182,
        158,
        30,
        251,
        47,
        178,
        202,
        173,
        173,
        0,
        133,
        225,
        241,
        170,
        208,
        182,
        100,
        173
      ]);
    });

    test('createMessageHash should combine separator and struct hash', () {
      final separator = EIP712Utils.computeDomainSeparator(domain);
      final structHash = EIP712Utils.hashTransferWithAuthorization(
        from: from,
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
      );

      final hash = EIP712Utils.createMessageHash(
        domainSeparator: separator,
        structHash: structHash,
      );

      expect(hash, isA<Uint8List>());
      expect(hash.length, 32);
      expect(hash, const [
        196,
        200,
        183,
        131,
        114,
        68,
        63,
        178,
        8,
        71,
        117,
        234,
        212,
        208,
        153,
        45,
        251,
        197,
        61,
        42,
        216,
        4,
        49,
        242,
        149,
        171,
        142,
        185,
        253,
        205,
        240,
        140
      ]);
    });

    test('signTypedData matches ethers + recoverSigner works', () {
      final structHash = EIP712Utils.hashTransferWithAuthorization(
        from: privateKey.address.hex,
        to: to,
        value: value,
        validAfter: validAfter,
        validBefore: validBefore,
        nonce: nonce,
      );

      final sig = EIP712Utils.signTypedData(
        privateKey: privateKey,
        domain: domain,
        structHash: structHash,
      );

      final recovered = EIP712Utils.recoverSigner(
        domain: domain,
        structHash: structHash,
        signature: sig,
      );

      expect(recovered.hex.toLowerCase(), privateKey.address.hex.toLowerCase());
      expect(EIP712Utils.uint256Bytes(sig.r), const [
        5,
        26,
        164,
        218,
        163,
        150,
        239,
        0,
        80,
        88,
        15,
        248,
        169,
        3,
        176,
        188,
        54,
        33,
        225,
        106,
        224,
        116,
        76,
        122,
        253,
        30,
        134,
        236,
        149,
        208,
        219,
        155
      ]);
      expect(EIP712Utils.uint256Bytes(sig.s), const [
        0,
        136,
        255,
        179,
        110,
        86,
        81,
        157,
        48,
        215,
        162,
        23,
        102,
        49,
        62,
        164,
        28,
        168,
        234,
        207,
        130,
        5,
        125,
        208,
        92,
        46,
        80,
        210,
        133,
        233,
        33,
        214
      ]);
      expect(sig.v, 27);
    });

    group('uint256Bytes', () {
      test('should pad small numbers to 32 bytes', () {
        final result = EIP712Utils.uint256Bytes(BigInt.one);
        expect(result.length, 32);
        expect(result.last, 1);
        expect(result.sublist(0, 31).every((b) => b == 0), isTrue);
      });

      test('should handle zero', () {
        final result = EIP712Utils.uint256Bytes(BigInt.zero);
        expect(result.length, 32);
        expect(result.every((b) => b == 0), isTrue);
      });

      test('should handle max uint256', () {
        final maxUint256 = BigInt.parse('F' * 64, radix: 16);
        final result = EIP712Utils.uint256Bytes(maxUint256);
        expect(result.length, 32);
        expect(result.every((b) => b == 255), isTrue);
      });
    });

    group('hexToBytes', () {
      test('should handle 0x prefix', () {
        final bytes = EIP712Utils.hexToBytes('0x1234');
        expect(bytes.length, 2);
        expect(bytes[0], 0x12);
        expect(bytes[1], 0x34);
      });

      test('should handle no prefix', () {
        final bytes = EIP712Utils.hexToBytes('1234');
        expect(bytes.length, 2);
        expect(bytes[0], 0x12);
        expect(bytes[1], 0x34);
      });

      test('should handle mixed case', () {
        final bytes = EIP712Utils.hexToBytes('0xAbCd');
        expect(bytes.length, 2);
        expect(bytes[0], 0xab);
        expect(bytes[1], 0xcd);
      });

      test('should throw on odd length strings', () {
        expect(() => EIP712Utils.hexToBytes('abc'), throwsArgumentError);
      });
      test('should throw on empty string', () {
        expect(() => EIP712Utils.hexToBytes(''), throwsArgumentError);
        expect(() => EIP712Utils.hexToBytes('0x'), throwsArgumentError);
      });

      test('should throw on non-hex characters', () {
        expect(() => EIP712Utils.hexToBytes('0xg'), throwsArgumentError);
        expect(() => EIP712Utils.hexToBytes('zz'), throwsArgumentError);
      });
    });

    group('encodePacked', () {
      test('should verify simple concatenation', () {
        final a = Uint8List.fromList([1, 2]);
        final b = Uint8List.fromList([3, 4]);
        final packed = EIP712Utils.encodePacked([a, b]);
        expect(packed, Uint8List.fromList([1, 2, 3, 4]));
      });

      test('should handle empty lists in input', () {
        final a = Uint8List.fromList([1, 2]);
        final empty = Uint8List(0);
        final b = Uint8List.fromList([3, 4]);
        final packed = EIP712Utils.encodePacked([a, empty, b]);
        expect(packed, Uint8List.fromList([1, 2, 3, 4]));
      });

      test('should handle empty input list', () {
        final packed = EIP712Utils.encodePacked([]);
        expect(packed, isEmpty);
      });
    });
  });
}
