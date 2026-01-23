import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/src/schemes/exact_evm_scheme_client.dart';
import 'package:x402_evm/src/utils/eip3009.dart';
import 'package:x402_evm/src/utils/eip712.dart';
import 'package:x402_evm/x402_evm.dart';

void main() {
  group('EvmSigner', () {
    late EthPrivateKey privateKey;
    late EvmSigner signer;
    late PaymentRequirement requirements;
    late ResourceInfo resource;

    setUp(() {
      privateKey = EthPrivateKey.fromHex(
          '0x4efa000000000000000000000000000000000000000000000000000000000001');
      signer = EvmSigner.fromClient(
        chainId: 8453,
        client: ExactEvmSchemeClient(
          privateKey: privateKey,
          nowProvider: () => 1940,
          nonceProvider: () => Uint8List(32),
        ),
      );

      resource = const ResourceInfo(
        url: 'https://api.example.com/data',
        description: 'Premium data access',
        mimeType: 'application/json',
      );

      requirements = const PaymentRequirement(
        scheme: 'exact',
        network: 'eip155:8453',
        amount: '10000',
        payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
        maxTimeoutSeconds: 60,
        asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
        extra: {'name': 'USD Coin', 'version': '2'},
      );
    });

    test('should have correct network and scheme', () {
      expect(signer.network, equals('eip155:8453'));
      expect(signer.scheme, equals('exact'));
    });

    test('should have correct address', () {
      expect(signer.address, equals(privateKey.address.hex));
    });

    test('should sign and return base64 encoded payload', () async {
      final signature = await signer.sign(requirements, resource);

      expect(signature, isA<SignedPayment>());
      expect(
          signature.encoded,
          equals(
              'eyJ4NDAyVmVyc2lvbiI6MiwicmVzb3VyY2UiOnsidXJsIjoiaHR0cHM6Ly9hcGkuZXhhbXBsZS5jb20vZGF0YSIsImRlc2NyaXB0aW9uIjoiUHJlbWl1bSBkYXRhIGFjY2VzcyIsIm1pbWVUeXBlIjoiYXBwbGljYXRpb24vanNvbiJ9LCJhY2NlcHRlZCI6eyJzY2hlbWUiOiJleGFjdCIsIm5ldHdvcmsiOiJlaXAxNTU6ODQ1MyIsImFzc2V0IjoiMHgwMzZDYkQ1Mzg0MmM1NDI2NjM0ZTc5Mjk1NDFlQzIzMThmM2RDRjdlIiwiYW1vdW50IjoiMTAwMDAiLCJwYXlUbyI6IjB4MjA5NjkzQmM2YWZjMEM1MzI4YkEzNkZhRjAzQzUxNEVGMzEyMjg3QyIsIm1heFRpbWVvdXRTZWNvbmRzIjo2MCwiZXh0cmEiOnsibmFtZSI6IlVTRCBDb2luIiwidmVyc2lvbiI6IjIifX0sInBheWxvYWQiOnsic2lnbmF0dXJlIjoiMHgzYTg0ZjIxMWYwMTY2MDAzYjk2NWUzNTdlZGVhNGZmNzUzOTA3NTUxZjQ3MjY3MTcwNTQ0YTBiMmZjYjUxYTRmMTMwYmVkOGE1OTA4MzlkZDg3NGNiNDJkODA1ZWI2MjJiMGNmMmY0NmM4NDBiYzVkMjIyZjdhNzMwMDllYjBhMDFjIiwiYXV0aG9yaXphdGlvbiI6eyJmcm9tIjoiMHgzNGQ1ZmJkMDI2M2Y3ODUwMDYxMGE0N2FhMDZmNjlmMGFlZDVhNjQwIiwidG8iOiIweDIwOTY5M2JjNmFmYzBjNTMyOGJhMzZmYWYwM2M1MTRlZjMxMjI4N2MiLCJ2YWx1ZSI6IjEwMDAwIiwidmFsaWRBZnRlciI6IjAiLCJ2YWxpZEJlZm9yZSI6IjIwMDAiLCJub25jZSI6IjB4MDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMCJ9fX0='));
      final decodedJson = signature.decode();
      final payload = PaymentPayload.fromJson(decodedJson);

      expect(payload.x402Version, equals(kX402Version));
      expect(payload.accepted.network, equals(requirements.network));
      expect(
          payload.payload['signature'],
          equals(
              '0x3a84f211f0166003b965e357edea4ff753907551f47267170544a0b2fcb51a4f130bed8a590839dd874cb42d805eb622b0cf2f46c840bc5d222f7a73009eb0a01c'));

      final sigHex = payload.payload['signature'] as String;
      final sig = EIP3009.decodeSignature(sigHex);

      expect(sig.r, isNot(BigInt.zero));
      expect(sig.s, isNot(BigInt.zero));
      expect(sig.v, anyOf(27, 28));

      final auth = payload.payload['authorization'] as Map<String, dynamic>;
      expect(auth['from'], equals(privateKey.address.hex));
    });

    test('authorization payload should contain required fields', () async {
      final encoded = await signer.sign(requirements, resource);
      final decodedJson = encoded.decode();

      final payload = PaymentPayload.fromJson(decodedJson);
      final auth = payload.payload['authorization'] as Map<String, dynamic>;

      expect(auth['from'], startsWith('0x'));
      expect(auth['to'], startsWith('0x'));
      final nonce = auth['nonce'];
      expect(nonce, isA<String>());
      expect(nonce, startsWith('0x'));
      expect(hexToBytes(nonce as String).length, equals(32));

      final value = auth['value'];
      expect(value, isA<String>());
      expect(BigInt.parse(value as String), greaterThan(BigInt.zero));

      final validBefore = auth['validBefore'];
      final validAfter = auth['validAfter'];

      expect(validAfter, isA<String>());
      expect(validBefore, isA<String>());
      expect(BigInt.parse(validBefore as String),
          greaterThan(BigInt.parse(validAfter as String)));
      expect(BigInt.parse(validBefore), equals(BigInt.from(1940 + 60)));
    });

    test('signature should recover the correct signer address', () async {
      final encoded = await signer.sign(requirements, resource);
      final decoded = encoded.decode();

      final payload = PaymentPayload.fromJson(decoded);
      final auth = payload.payload['authorization'] as Map<String, dynamic>;
      final sigHex = payload.payload['signature'] as String;

      final signature = EIP3009.decodeSignature(sigHex);

      final domain = EIP712Domain(
        name: requirements.extra['name'] as String,
        version: requirements.extra['version'] as String,
        chainId: 8453,
        verifyingContract: requirements.asset,
      );

      final structHash = EIP712Utils.hashTransferWithAuthorization(
        from: auth['from'] as String,
        to: auth['to'] as String,
        value: BigInt.parse(auth['value'] as String),
        validAfter: BigInt.parse(auth['validAfter'] as String),
        validBefore: BigInt.parse(auth['validBefore'] as String),
        nonce: hexToBytes(auth['nonce'] as String),
      );

      final recovered = EIP712Utils.recoverSigner(
        domain: domain,
        structHash: structHash,
        signature: signature,
      );

      expect(recovered.hex.toLowerCase(),
          equals(privateKey.address.hex.toLowerCase()));
    });

    test('should include extensions if provided', () async {
      final extensions = {'test': 'extension'};
      final signature =
          await signer.sign(requirements, resource, extensions: extensions);

      final decodedJson = signature.decode();
      final payload = PaymentPayload.fromJson(decodedJson);

      expect(payload.extensions, equals(extensions));
    });

    test('fromPrivateKeyHex factory should create valid signer', () {
      final hexSigner = EvmSigner.fromPrivateKeyHex(
        privateKeyHex:
            '4efa000000000000000000000000000000000000000000000000000000000001',
        chainId: 1,
      );
      expect(hexSigner.network, equals('eip155:1'));
      expect(hexSigner.address, equals(privateKey.address.hex));
    });

    test('same address with upper-case private key', () {
      final hexSigner = EvmSigner.fromPrivateKeyHex(
        privateKeyHex:
            '4EFA000000000000000000000000000000000000000000000000000000000001',
        chainId: 1,
      );
      expect(hexSigner.network, equals('eip155:1'));
      expect(hexSigner.address, equals(privateKey.address.hex));
    });

    test('throws on unsupported scheme', () {
      final badReq = requirements.copyWith(scheme: 'stream');

      expect(
        () => signer.sign(badReq, resource),
        throwsA(
          predicate(
            (e) =>
                e is UnsupportedSchemeException &&
                e.toString().contains('Expected scheme'),
          ),
        ),
      );
    });

    test('throws if amount is zero', () {
      final badReq = requirements.copyWith(amount: '0');

      expect(
        () => signer.sign(badReq, resource),
        throwsArgumentError,
      );
    });

    test('throws on zero amount', () {
      final req = requirements.copyWith(amount: '0');
      expect(() => signer.sign(req, resource), throwsArgumentError);
    });

    test('throws on negative amount', () {
      final req = requirements.copyWith(amount: '-1');
      expect(() => signer.sign(req, resource), throwsArgumentError);
    });

    test('throws on non-numeric amount', () {
      final req = requirements.copyWith(amount: 'abc');
      expect(() => signer.sign(req, resource), throwsArgumentError);
    });

    test('throws on neagative timeout', () {
      final req = requirements.copyWith(maxTimeoutSeconds: -1);
      expect(() => signer.sign(req, resource), throwsArgumentError);
    });

    test('throws if chainId mismatches', () {
      final bad = requirements.copyWith(network: 'eip155:1');

      expect(
        () => signer.sign(bad, resource),
        throwsArgumentError,
      );
    });

    test('throws on missing chainId', () {
      final badReq = requirements.copyWith(network: 'eip155');

      expect(
        () => signer.sign(badReq, resource),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws on wrong namespace', () {
      final badReq = requirements.copyWith(network: 'ip155:8453');

      expect(
        () => signer.sign(badReq, resource),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
