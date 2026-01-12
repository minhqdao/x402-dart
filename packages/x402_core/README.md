# x402_core

Core protocol definitions and shared logic for the x402 protocol, providing blockchain-agnostic interfaces and data structures.

## Overview

`x402_core` is the foundation package for the x402 payments protocol implementation in Dart. It provides:

- **Protocol models**: Data structures for payment requirements, payloads, and responses
- **Interfaces**: Abstract contracts for implementing schemes and facilitator clients
- **Constants**: Standard headers, status codes, and protocol version
- **Exceptions**: Typed errors for payment operations

This package is chain-agnostic and contains no blockchain-specific implementation. Chain-specific logic should be implemented in separate packages (`x402_evm`, `x402_svm`, etc.).

## What is x402?

x402 is an open-source payments protocol built on HTTP that enables:
- **Low-cost micropayments**: Near-zero fees with $0.001 minimum payments
- **Fast settlement**: ~1 second transaction finality
- **HTTP-native**: Uses standard HTTP 402 status code
- **Chain-agnostic**: Works across EVM, SVM, and other blockchains
- **Agent-friendly**: Perfect for AI agents and programmatic payments

## Installation

```yaml
dependencies:
  x402_core: ^0.1.0
```

## Key Concepts

### Payment Flow

1. **Client** requests a resource from a server
2. **Server** responds with `402 Payment Required` and `PaymentRequirement`
3. **Client** creates a `PaymentPayload` using a scheme (e.g., "exact")
4. **Server** verifies the payment (optionally via facilitator)
5. **Server** settles the payment on-chain (optionally via facilitator)
6. **Server** returns the resource with payment confirmation

### Models

#### PaymentRequirement

Describes what payment is needed to access a resource:

```dart
final requirements = PaymentRequirement(
  scheme: 'exact',
  network: 'eip155:8453',  // Base mainnet
  amount: '10000',  // 0.01 USDC (6 decimals)
  payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
  maxTimeoutSeconds: 60,
  asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',  // USDC
  extra: {'name': 'USDC', 'version': '2'},
);
```

#### PaymentPayload

Contains the cryptographic proof of payment:

```dart
final payload = PaymentPayload(
  x402Version: 2,
  resource: resource,
  accepted: requirements,
  payload: {
    'signature': '0x...',
    'authorization': {...},
  },
);
```

### Interfaces

#### SchemeClient

Implement this to create payment payloads for a specific scheme:

```dart
class MySchemeClient implements SchemeClient {
  @override
  String get scheme => 'exact';

  @override
  Future<PaymentPayload> createPaymentPayload(
    PaymentRequirement requirements,
  ) async {
    // Create and sign payment payload
    // ...
  }
}
```

#### FacilitatorClient

Implement this to interact with a facilitator server:

```dart
class MyFacilitatorClient implements FacilitatorClient {
  @override
  String get baseUrl => 'https://facilitator.example.com';

  @override
  Future<VerificationResponse> verify({...}) async {
    // POST to /verify endpoint
    // ...
  }

  @override
  Future<SettlementResponse> settle({...}) async {
    // POST to /settle endpoint
    // ...
  }
}
```

## Network Identifiers

Networks use the CAIP-2 format:

- **EVM chains**: `eip155:{chainId}`
  - Base: `eip155:8453`
  - Ethereum: `eip155:1`
  - Base Sepolia: `eip155:84532`
- **SVM**: `svm:{genesisHash}`

## Schemes

A scheme defines how payments are created and verified. Current schemes:

- **exact**: Transfer a specific amount (e.g., $0.01 to read an article)
- **deferred** (future): Usage-based payments with escrow

Each scheme has different implementations per blockchain.

## Constants

```dart
import 'package:x402_core/x402_core.dart';

// Protocol version
kX402Version;  // 2

// HTTP headers
kPaymentHeader;  // 'X-PAYMENT'
kPaymentResponseHeader;  // 'X-PAYMENT-RESPONSE'

// HTTP status
kPaymentRequiredStatus;  // 402
```

## Exceptions

```dart
try {
  // Payment operation
} on PaymentVerificationException catch (e) {
  print('Verification failed: ${e.message}');
} on PaymentSettlementException catch (e) {
  print('Settlement failed: ${e.message}');
} on InvalidPayloadException catch (e) {
  print('Invalid payload: ${e.message}');
} on UnsupportedSchemeException catch (e) {
  print('Unsupported: ${e.message}');
} on X402Exception catch (e) {
  print('x402 error: ${e.message}');
}
```

## Usage

This package is typically not used directly. Instead, use:

- **`x402_evm`**: For EVM-compatible chains (Ethereum, Base, Polygon, etc.)
- **`x402_svm`**: For SVM blockchain
- **`x402`**: Convenience package that includes all implementations

For implementation examples, see the chain-specific packages.

## Resources

- [x402 Protocol Specification](https://x402.org)
- [GitHub Repository](https://github.com/coinbase/x402)
- [Discord Community](https://discord.gg/x402)

## License

Apache-2.0
