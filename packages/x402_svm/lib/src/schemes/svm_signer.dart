import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/schemes/exact_svm_client.dart';

enum SolanaNetwork {
  mainnet('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d', 'https://api.mainnet-beta.solana.com'),
  devnet('EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG', 'https://api.devnet.solana.com'),
  testnet('4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY', 'https://api.testnet.solana.com');

  final String genesisHash;
  final String rpcUrl;
  const SolanaNetwork(this.genesisHash, this.rpcUrl);
}

class SvmSigner extends X402Signer {
  final Ed25519HDKeyPair _signer;
  final SolanaClient _client;
  final String _genesisHash;

  SvmSigner({
    required Ed25519HDKeyPair signer,
    required SolanaClient client,
    required String genesisHash,
  })  : _signer = signer,
        _client = client,
        _genesisHash = genesisHash;

  /// 🚀 The "Production" way: Load an existing key
  static Future<SvmSigner> fromHex({
    required String privateKeyHex,
    required SolanaNetwork network,
    String? customRpcUrl, // Optional override for Helius/QuickNode
  }) async {
    final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: hex.decode(privateKeyHex));
    final rpcUrl = customRpcUrl ?? network.rpcUrl;

    return SvmSigner(
      signer: keypair,
      client: SolanaClient(rpcUrl: Uri.parse(rpcUrl), websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss'))),
      genesisHash: network.genesisHash,
    );
  }

  /// 🧪 The "Quick Start" way: Random key for testing
  static Future<SvmSigner> createRandom({required SolanaNetwork network}) async {
    final keypair = await Ed25519HDKeyPair.random();
    return SvmSigner(
      signer: keypair,
      client: SolanaClient(
        rpcUrl: Uri.parse(network.rpcUrl),
        websocketUrl: Uri.parse(network.rpcUrl.replaceFirst('https', 'wss')),
      ),
      genesisHash: network.genesisHash,
    );
  }

  /// 🔑 Restore from Mnemonic
  static Future<SvmSigner> fromMnemonic({
    required String mnemonic,
    required SolanaNetwork network,
    String? customRpcUrl,
  }) async {
    final keypair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    final rpcUrl = customRpcUrl ?? network.rpcUrl;

    return SvmSigner(
      signer: keypair,
      client: SolanaClient(rpcUrl: Uri.parse(rpcUrl), websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss'))),
      genesisHash: network.genesisHash,
    );
  }

  @override
  String get network => 'solana:${_genesisHash.substring(0, 32)}';

  @override
  String get scheme => 'v2:solana:exact';

  @override
  bool supports(PaymentRequirement requirement) {
    final supportedSchemes = {scheme, 'exact'};
    return requirement.network == network && supportedSchemes.contains(requirement.scheme);
  }

  @override
  Future<String> sign(
    PaymentRequirement requirement,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  }) async {
    final schemeClient = ExactSvmSchemeClient(signer: _signer, solanaClient: _client);
    final payload = await schemeClient.createPaymentPayload(requirement, resource, extensions: extensions);
    return base64Encode(utf8.encode(jsonEncode(payload.toJson())));
  }

  // Expose signer for those who might need it
  Ed25519HDKeyPair get signer => _signer;
}
