import 'dart:convert';
import 'package:test/test.dart';
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

void main() {
  group('EvmSigner', () {
    late EthPrivateKey privateKey;
    late EvmSigner signer;
    late PaymentRequirement requirements;
    late ResourceInfo resource;

    setUp(() {
      privateKey = EthPrivateKey.fromHex('0xabcd567890123456789012345678901234567890123456789012345678901234');
      signer = EvmSigner(chainId: 8453, privateKey: privateKey);

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

      expect(signature, isA<String>());
      final decodedJson = jsonDecode(utf8.decode(base64Decode(signature))) as Map<String, dynamic>;
      final payload = PaymentPayload.fromJson(decodedJson);

      expect(payload.x402Version, equals(kX402Version));
      expect(payload.accepted.network, equals(requirements.network));
      expect(payload.payload['signature'], isNotNull);

      final auth = payload.payload['authorization'] as Map<String, dynamic>;
      expect(auth['from'], equals(privateKey.address.hex));
    });

    test('should include extensions if provided', () async {
      final extensions = {'test': 'extension'};
      final signature = await signer.sign(requirements, resource, extensions: extensions);

      final decodedJson = jsonDecode(utf8.decode(base64Decode(signature))) as Map<String, dynamic>;
      final payload = PaymentPayload.fromJson(decodedJson);

      expect(payload.extensions, equals(extensions));
    });

    test('fromHex factory should create valid signer', () {
      final hexSigner = EvmSigner.fromHex(
        privateKeyHex: 'abcd567890123456789012345678901234567890123456789012345678901234',
        chainId: 1,
      );
      expect(hexSigner.network, equals('eip155:1'));
      expect(hexSigner.address, equals(privateKey.address.hex));
    });

    test('same address with upper-case private key', () {
      final hexSigner = EvmSigner.fromHex(
        privateKeyHex: 'ABCD567890123456789012345678901234567890123456789012345678901234',
        chainId: 1,
      );
      expect(hexSigner.network, equals('eip155:1'));
      expect(hexSigner.address, equals(privateKey.address.hex));
    });
  });
}
