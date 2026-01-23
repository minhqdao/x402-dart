import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/src/schemes/exact_svm_scheme_client.dart';

/// Supported Solana networks for the [SvmSigner].
///
/// Each network defines its genesis hash and a default public RPC URL.
enum SolanaNetwork {
  /// The Solana mainnet-beta network.
  mainnet('5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d',
      'https://api.mainnet-beta.solana.com'),

  /// The Solana devnet network (for development and testing).
  devnet('EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG',
      'https://api.devnet.solana.com'),

  /// The Solana testnet network.
  testnet('4uhcVJyU9pJkvQyS88uRDiswHXSCkY3zQawwpjk2NsNY',
      'https://api.testnet.solana.com');

  /// The genesis hash of the network, used for CAIP-2 identification.
  final String genesisHash;

  /// The default public RPC URL for this network.
  final String rpcUrl;

  const SolanaNetwork(this.genesisHash, this.rpcUrl);
}

/// Concrete implementation of [X402Signer] for SVM (Solana) chains.
///
/// This signer handles the creation and signing of Solana-based payment
/// payloads, typically using an [Ed25519HDKeyPair] to sign transactions.
/// It uses an underlying [ExactSvmSchemeClient] to perform scheme-specific
/// operations.
class SvmSigner extends X402Signer {
  final SolanaNetwork _solanaNetwork;
  final ExactSvmSchemeClient _client;

  /// Creates an [SvmSigner] from an [ExactSvmSchemeClient] and the chosen
  /// [SolanaNetwork].
  ///
  /// Use other constructors like [SvmSigner.fromHex] for convenience.
  SvmSigner.fromClient({
    required SolanaNetwork solanaNetwork,
    required ExactSvmSchemeClient client,
  })  : _solanaNetwork = solanaNetwork,
        _client = client;

  /// Creates an [SvmSigner] from a hexadecimal private key string.
  ///
  /// [privateKeyHex] must be a valid hex-encoded Ed25519 seed (32 bytes).
  /// [network] specifies the target Solana network.
  /// [customRpcUrl] can be used to provide a private RPC endpoint.
  static Future<SvmSigner> fromPrivateKeyHex({
    required String privateKeyHex,
    required SolanaNetwork network,
    String? customRpcUrl,
  }) async {
    final keypair = await Ed25519HDKeyPair.fromPrivateKeyBytes(
        privateKey: hex.decode(privateKeyHex));
    final rpcUrl = customRpcUrl ?? network.rpcUrl;

    return SvmSigner.fromClient(
      solanaNetwork: network,
      client: ExactSvmSchemeClient(
        signer: keypair,
        solanaClient: SolanaClient(
            rpcUrl: Uri.parse(rpcUrl),
            websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss'))),
      ),
    );
  }

  /// Creates an [SvmSigner] from raw private key bytes.
  ///
  /// [privateKeyBytes] can be 32 bytes (seed) or 64 bytes (secret key).
  /// [network] specifies the target Solana network.
  /// [customRpcUrl] can be used to provide a private RPC endpoint.
  ///
  /// Throws [ArgumentError] if the byte length is invalid.
  static Future<SvmSigner> fromPrivateKeyBytes({
    required List<int> privateKeyBytes,
    required SolanaNetwork network,
    String? customRpcUrl,
  }) async {
    final List<int> seed;

    if (privateKeyBytes.length == 32) {
      // Ed25519 seed
      seed = privateKeyBytes;
    } else if (privateKeyBytes.length == 64) {
      // Solana secret key = seed + public key
      seed = privateKeyBytes.sublist(0, 32);
    } else {
      throw ArgumentError(
        'Invalid private key length: ${privateKeyBytes.length}. '
        'Expected 32 (seed) or 64 (Solana secret key) bytes.',
      );
    }

    final keypair =
        await Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: seed);
    final rpcUrl = customRpcUrl ?? network.rpcUrl;

    return SvmSigner.fromClient(
      client: ExactSvmSchemeClient(
        signer: keypair,
        solanaClient: SolanaClient(
            rpcUrl: Uri.parse(rpcUrl),
            websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss'))),
      ),
      solanaNetwork: network,
    );
  }

  /// Creates an [SvmSigner] with a randomly generated keypair.
  /// Useful for testing or temporary wallets.
  static Future<SvmSigner> createRandom(
      {required SolanaNetwork network}) async {
    final keypair = await Ed25519HDKeyPair.random();
    return SvmSigner.fromClient(
      client: ExactSvmSchemeClient(
        signer: keypair,
        solanaClient: SolanaClient(
          rpcUrl: Uri.parse(network.rpcUrl),
          websocketUrl: Uri.parse(network.rpcUrl.replaceFirst('https', 'wss')),
        ),
      ),
      solanaNetwork: network,
    );
  }

  /// Restores an [SvmSigner] from a BIP-39 mnemonic phrase.
  static Future<SvmSigner> fromMnemonic({
    required String mnemonic,
    required SolanaNetwork network,
    String? customRpcUrl,
  }) async {
    final keypair = await Ed25519HDKeyPair.fromMnemonic(mnemonic);
    final rpcUrl = customRpcUrl ?? network.rpcUrl;

    return SvmSigner.fromClient(
      client: ExactSvmSchemeClient(
        signer: keypair,
        solanaClient: SolanaClient(
          rpcUrl: Uri.parse(rpcUrl),
          websocketUrl: Uri.parse(rpcUrl.replaceFirst('https', 'wss')),
        ),
      ),
      solanaNetwork: network,
    );
  }

  @override
  String get network => 'solana:${_solanaNetwork.genesisHash.substring(0, 32)}';

  @override
  String get scheme => _client.scheme;

  @override
  String get address => _client.address;

  @override
  bool supports(PaymentRequirement requirement) {
    final supportedSchemes = {scheme, 'exact'};
    return requirement.network == network &&
        supportedSchemes.contains(requirement.scheme);
  }

  /// Signs a payment requirement and returns a [SignedPayment].
  ///
  /// This method:
  /// 1. Validates the [requirement] (positive amount, non-negative timeout, matching network).
  /// 2. Delegates payload creation to the underlying scheme client.
  /// 3. Returns a [SignedPayment] containing the base64-encoded payload.
  ///
  /// Throws an [ArgumentError] if the requirement fails validation.
  /// Throws [UnsupportedSchemeException] or [InvalidPayloadException] if signing fails.
  @override
  Future<SignedPayment> sign(
    PaymentRequirement requirement,
    ResourceInfo resource, {
    Map<String, dynamic>? extensions,
  }) async {
    _validateRequirement(requirement);
    final payload = await _client.createPaymentPayload(requirement, resource,
        extensions: extensions);
    return SignedPayment(
        base64Encode(utf8.encode(jsonEncode(payload.toJson()))));
  }

  void _validateRequirement(PaymentRequirement requirement) {
    final amount = BigInt.tryParse(requirement.amount);
    if (amount == null || amount <= BigInt.zero) {
      throw ArgumentError.value(
        requirement.amount,
        'amount',
        'Amount must be a positive integer string',
      );
    }

    if (requirement.maxTimeoutSeconds < 0) {
      throw ArgumentError.value(
        requirement.maxTimeoutSeconds,
        'maxTimeoutSeconds',
        'Must be non-negative',
      );
    }

    if (requirement.network != network) {
      throw ArgumentError(
        'Requirement network (${requirement.network}) '
        'does not match signer network ($network)',
      );
    }
  }
}
