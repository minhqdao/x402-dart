# x402_dio

A Dio-based client library for the x402 payment protocol. It provides a `Dio` interceptor that automatically handles "402 Payment Required" flows across multiple blockchain ecosystems, currently supporting EVM (Ethereum) and SVM (Solana).

This package is an alternative to the main [x402](https://pub.dev/packages/x402) package (which uses `http`). It leverages the power of Dio interceptors for seamless integration into existing Dio-based applications.

## Features

- **Dio Integration**: Adds automatic x402 handling via the `X402Interceptor`.
- **Multi-Chain Support**: Uses `x402` signers for EVM and SVM support.
- **Automated Handshake**: Simplifies the negotiation between client signers and server requirements.
- **Flexible Configuration**: Prioritize signers and add custom approval logic.

## Getting Started

Add the dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.0.0
  x402: ^0.1.0     # For signers (EvmSigner, SvmSigner)
  x402_dio: ^0.1.0 # For X402Interceptor
```

## Usage

The primary way to use this package is by adding the `X402Interceptor` to your Dio instance.

### Using X402Interceptor

The `X402Interceptor` detects 402 responses, finds a compatible signer from your provided list, signs the payment requirement, and automatically retries the request.

```dart
import 'package:dio/dio.dart';
import 'package:x402/x402.dart';
import 'package:x402_dio/x402_dio.dart';

void main() async {
  // 1. Setup your signers
  final evmSigner = EvmSigner.fromHex(
    chainId: 8453, 
    privateKeyHex: 'YOUR_EVM_PRIVATE_KEY',
  );
  
  final svmSigner = await SvmSigner.fromHex(
    privateKeyHex: 'YOUR_SVM_PRIVATE_KEY', 
    network: SolanaNetwork.devnet,
  );

  // 2. Configure Dio
  final dio = Dio();
  dio.interceptors.add(X402Interceptor(
    dio: dio,
    signers: [
      evmSigner, // The first signer is checked first
      svmSigner,
    ],
    // Optional: Ask for user confirmation before paying
    onPaymentRequired: (req, resource, signer) async {
      print('Payment of ${req.amount} required for ${resource.url}');
      return true; // Return true to approve, false to deny
    },
  ));

// 3. Make requests normally (402 is handled automatically by the interceptor)
try {
  final response = await dio.get('https://api.example.com/premium');

  if (response.statusCode == 200) {
    print('Success: ${response.data}');
    // HTTP 402 is fully handled by X402Interceptor (payment + retry),
    // so it will never reach this point and does not need to be checked here.
  } else {
    print('Unexpected status: ${response.statusCode}');
  }
} on DioException catch (e) {
  // You only end up here if:
  // - payment was denied
  // - payment signing failed
  // - no compatible signer was found
  // - the server still rejected the paid request
  if (e.response?.statusCode == 402) {
    print('Payment could not be completed');
  } else {
    print('Request failed: ${e.message}');
  }
}
}
```

## Related Packages

- [x402](https://pub.dev/packages/x402): The main client library (http-based).
- [x402_core](https://pub.dev/packages/x402_core): Internal protocol definitions.
- [x402_evm](https://pub.dev/packages/x402_evm): EVM implementation details.
- [x402_svm](https://pub.dev/packages/x402_svm): SVM implementation details.
