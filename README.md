# x402

This repository contains the **Dart implementation** of the [x402 protocol](https://x402.org), a machine-native payment standard designed for the modern web. 

x402 enables instant, automatic stablecoin payments directly over HTTP by reviving the HTTP 402 "Payment Required" status code. This implementation provides a suite of client-side libraries to integrate x402 payments into your Dart and Flutter applications.

## Official Resources

- **Protocol Homepage**: [x402.org](https://x402.org)
- **Protocol Specification & Reference**: [github.com/coinbase/x402](https://github.com/coinbase/x402)

## Monorepo Structure

This project is organized as a monorepo managed with [Melos](https://melos.invert.dev). It consists of several packages:

| Package | Description |
| --- | --- |
| [**x402**](./packages/x402) | **Main entry point.** The primary client-side package for most users. |
| [**x402_core**](./packages/x402_core) | Core protocol definitions, models, and blockchain-agnostic interfaces. |
| [**x402_evm**](./packages/x402_evm) | EVM implementation supporting Ethereum and compatible chains (e.g., Base). |
| [**x402_svm**](./packages/x402_svm) | SVM implementation supporting Solana and compatible chains. |

## Why use x402 Dart?

- **Native Dart & Flutter**: Built from the ground up for the Dart ecosystem.
- **Multi-Chain**: Seamlessly handle payments on both EVM and SVM networks.
- **Automated Handshake**: Use the `X402Client` to automatically parse requirements, negotiate signers, and retry requests.
- **Type-Safe Models**: Robust serialization and validation for all protocol data structures.

## Getting Started

For most use cases, you only need to add the main `x402` package to your project:

```yaml
dependencies:
  x402: ^0.1.0
```

### Quick Example

```dart
import 'package:x402/x402.dart';

void main() async {
  final client = X402Client(
    signers: [evmSigner, svmSigner],
    onPaymentRequired: (req, resource, signer) async {
      print('Approving payment for ${resource.description}');
      return true;
    },
  );

  final response = await client.get(Uri.parse('https://api.example.com/premium'));
  print(response.body);
}
```

Detailed examples for both automated and manual flows can be found in the [examples](./examples) folder.

## Development

This repo uses Melos for workspace management.

```bash
# Bootstrap the workspace
melos bootstrap

# Run all tests
melos run test

# Analyze all packages
melos run analyze
```

## License

This project is licensed under the Apache-2.0 License - see the [LICENSE](LICENSE) file for details.
