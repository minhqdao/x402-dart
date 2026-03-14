# x402

This library implements the x402 payment protocol in Dart. It provides a unified interface to handle "402 Payment Required" flows across multiple blockchain ecosystems, currently supporting EVM (Ethereum) and SVM (Solana).

> This library currently only supports **V2** of the protocol. V1 was marked legacy and is **unsupported**.

This is the primary package intended for general use. You typically do not need to import `x402_core`, `x402_evm`, or `x402_svm` separately, as this package exports all necessary components.

## Features

- **Multi-Chain Support**: Unified handling for EVM and SVM chains.
- **Client Payments**: Sign and send payments automatically when encountering `402 Payment Required` responses.
- **Server Verification & Settlement**: Build payment requirements, verify incoming payments, and settle them through the facilitator.
- **Standardized Models**: Consistent data structures for payment requirements and payloads.

## Getting Started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  x402: ^0.3.0
```

## Usage

The library can be used both as a client (to pay for resources) and as a server (to protect resources).

### 1. Client Usage
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
    // Optional: Ask for confirmation before paying
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

### 2. Server Usage
Servers define which resources require payment and verify incoming payment proofs.

The core component is `X402ResourceServer`, which builds payment requirements, verifies payments, and performs settlement.

```dart
final resourceServer = await X402ResourceServer.create(
  schemeServers: [
    ExactEvmSchemeServer(chainId: 84532),
    ExactSvmSchemeServer(cluster: SolanaCluster.devnet),
  ],
);
```

The server then:
	1.	Builds payment requirements for protected resources.
	2.	Sends a 402 Payment Required response with the requirements header.
	3.	Verifies the payment payload sent by the client.
	4.	Settles the payment through the facilitator before serving the resource.

For integration with `shelf`, see the [x402_shelf](https://pub.dev/packages/x402_shelf) package.

See the [example](https://github.com/minhqdao/x402-dart/tree/main/examples) folder for complete client and server implementations.

## Related Packages

- [x402_core](https://pub.dev/packages/x402_core): Internal protocol definitions.
- [x402_evm](https://pub.dev/packages/x402_evm): EVM implementation details.
- [x402_svm](https://pub.dev/packages/x402_svm): SVM implementation details.
- [x402_dio](https://pub.dev/packages/x402_dio): Dio-based client library.
- [x402_shelf](https://pub.dev/packages/x402_shelf): Shelf middleware for protecting HTTP routes with x402 payments.
