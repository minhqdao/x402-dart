# x402

A client-side library for the x402 payment protocol in Dart. It provides a unified interface to handle "402 Payment Required" flows across multiple blockchain ecosystems, currently supporting EVM (Ethereum) and SVM (Solana).

> This library currently only supports **V2** of the protocol. V1 was marked legacy and is **unsupported**.

This is the primary package intended for general use. You typically do not need to import `x402_core`, `x402_evm`, or `x402_svm` separately, as this package exports all necessary components.

## Features

- **Multi-Chain Support**: Unified handling for EVM and SVM chains.
- **Automated Handshake**: Simplifies the negotiation between client signers and server requirements.
- **Standardized Models**: Consistent data structures for payment requirements and payloads.

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  x402: ^0.2.0
```

## Usage

There are two primary ways to interact with the protocol:

### 1. Using X402Client (Recommended)
The `X402Client` is a high-level wrapper around the standard `http.Client`. It automatically detects 402 responses, finds a compatible signer, and retries the request with the required payment proof.

```dart
final evmSigner = EvmSigner.fromPrivateKeyHex(chainId: 123, privateKeyHex: 'EVM_PRIVATE_KEY');
final svmSigner = await SvmSigner.fromPrivateKeyHex(privateKeyHex: 'SVM_PRIVATE_KEY', cluster: SolanaCluster.devnet);

final client = X402Client(
  signers: [
    evmSigner, // The first signer is checked first
    svmSigner
  ],
  onPaymentRequired: (req, resource, signer) async {
    // Optional: Ask for user confirmation or add condition
    return true;
  },
);

final response = await client.get(Uri.parse('https://api.example.com/premium'));
if (response.statusCode == 200) {
  print('Success: ${response.body}');
  // HTTP 402 is automatically handled inside X402Client (payment + retry),
  // so it will never reach this point and does not need to be checked here.
} else {
  print('Request failed (${response.statusCode}): ${response.body}');
}
```

### 2. Manual Handling
If you need granular control, you can perform the handshake manually by parsing the `payment-required` header and using a specific `X402Signer` to generate the signature.

```dart
final response = await client.get(uri);
if (response.statusCode == 402) {
  // Parse header, negotiate, sign, and retry manually
}
```

Take a look at the [example](https://github.com/minhqdao/x402-dart/tree/main/examples) folder for complete implementations of both approaches.

## Related Packages

- [x402_core](https://pub.dev/packages/x402_core): Internal protocol definitions.
- [x402_evm](https://pub.dev/packages/x402_evm): EVM implementation details.
- [x402_svm](https://pub.dev/packages/x402_svm): SVM implementation details.
- [x402_dio](https://pub.dev/packages/x402_dio): Dio-based client library.
- [x402_shelf](https://pub.dev/packages/x402_shelf): Shelf middleware for protecting HTTP routes with x402 payments.
