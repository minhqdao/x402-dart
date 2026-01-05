# x402_evm

EVM-compatible blockchain implementation of the x402 protocol for Ethereum and EVM-based chains.

## Features

- ✅ **EIP-3009 Support**: Implements `transferWithAuthorization` for gasless payments
- ✅ **EIP-712 Signatures**: Secure typed data signing
- ✅ **Multi-chain**: Works on any EVM chain (Ethereum, Base, Polygon, etc.)
- ✅ **Client & Server**: Both payment creation and verification
- ✅ **Facilitator Integration**: HTTP client for facilitator servers
- ✅ **Type-safe**: Full type safety with comprehensive error handling

## Supported Chains

Works on any EVM-compatible chain:
- **Base** (mainnet: `eip155:8453`, testnet: `eip155:84532`)
- **Ethereum** (`eip155:1`)
- **Polygon** (`eip155:137`)
- **Optimism** (`eip155:10`)
- **Arbitrum** (`eip155:42161`)
- And more...

## Installation

```yaml
dependencies:
  x402_evm: ^0.1.0
```

## Quick Start

### Client: Making a Payment

```dart
import 'package:web3dart/web3dart.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

// Initialize client with your private key
final privateKey = EthPrivateKey.fromHex('0x...');
final client = ExactEvmSchemeClient(privateKey: privateKey);

// Get payment requirements from server (via 402 response)
final requirements = X402Requirement(
  scheme: 'exact',
  network: 'eip155:8453', // Base mainnet
  amount: '10000', // 0.01 USDC (6 decimals)
  resource: 'https://api.example.com/premium-data',
  description: 'Access to premium data',
  mimeType: 'application/json',
  payTo: '0x209693Bc6afc0C5328bA36FaF03C514EF312287C',
  maxTimeoutSeconds: 60,
  asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e', // USDC on Base
  data: {
    'name': 'USD Coin',
    'version': '2',
  },
);

// Create payment payload
final payload = await client.createPaymentPayload(requirements);

// Encode and send in X-PAYMENT header
final paymentHeader = base64Encode(
  utf8.encode(jsonEncode(payload.toJson())),
);

// Make request with payment
final response = await http.get(
  Uri.parse(requirements.resource),
  headers: {
    'X-PAYMENT': paymentHeader,
  },
);
```

### Server: Accepting Payments

```dart
import 'package:shelf/shelf.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_evm/x402_evm.dart';

// Initialize verifier
final server = ExactEvmSchemeServer();

// Your payment requirements
final requirements = X402Requirement(
  scheme: 'exact',
  network: 'eip155:8453',
  amount: '10000',
  resource: '/premium-data',
  description: 'Premium data access',
  mimeType: 'application/json',
  payTo: '0xYourAddress',
  maxTimeoutSeconds: 60,
  asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
  data: {'name': 'USD Coin', 'version': '2'},
);

Handler paymentHandler(Handler innerHandler) {
  return (Request request) async {
    // Check for payment header
    final paymentHeader = request.headers['x-payment'];
    
    if (paymentHeader == null) {
      // No payment, return 402
      return Response(
        402,
        body: jsonEncode(
          PaymentRequiredResponse(
            x402Version: kX402Version,
            accepts: [requirements],
          ).toJson(),
        ),
        headers: {'content-type': 'application/json'},
      );
    }

    // Decode payment payload
    final payloadJson = jsonDecode(
      utf8.decode(base64Decode(paymentHeader)),
    ) as Map<String, dynamic>;
    final payload = PaymentPayload.fromJson(payloadJson);

    // Verify payment
    final isValid = await server.verifyPayload(payload, requirements);
    
    if (!isValid) {
      return Response(
        402,
        body: jsonEncode(
          PaymentRequiredResponse(
            x402Version: kX402Version,
            accepts: [requirements],
            error: 'Invalid payment',
          ).toJson(),
        ),
        headers: {'content-type': 'application/json'},
      );
    }

    // Payment valid! Settle it (via facilitator or directly)
    // Then serve the resource
    return innerHandler(request);
  };
}
```

### Using a Facilitator

```dart
import 'package:x402_evm/x402_evm.dart';

// Initialize facilitator client
final facilitator = HttpFacilitatorClient(
  baseUrl: 'https://facilitator.coinbase.com',
);

// Verify payment via facilitator
final verificationResult = await facilitator.verify(
  x402Version: kX402Version,
  paymentHeader: paymentHeaderBase64,
  requirement: requirements,
);

if (verificationResult.isValid) {
  // Settle payment via facilitator
  final settlementResult = await facilitator.settle(
    x402Version: kX402Version,
    paymentHeader: paymentHeaderBase64,
    requirement: requirements,
  );
  
  if (settlementResult.success) {
    print('Payment settled! TX: ${settlementResult.txHash}');
  }
}

// Check what the facilitator supports
final supported = await facilitator.getSupported();
for (final kind in supported) {
  print('Supports ${kind.scheme} on ${kind.network}');
}
```

## Architecture

### Components

1. **ExactEvmSchemeClient**: Creates payment payloads (client-side)
2. **ExactEvmSchemeServer**: Verifies payment payloads (server-side)
3. **HttpFacilitatorClient**: Communicates with facilitator servers
4. **EIP3009**: EIP-3009 signature utilities
5. **EIP712Utils**: EIP-712 typed data signing

### Payment Flow

```
1. Client requests resource → Server returns 402 with X402Requirement
2. Client creates PaymentPayload with EIP-3009 signature
3. Client sends request with X-PAYMENT header
4. Server verifies signature (locally or via facilitator)
5. Server settles payment (directly or via facilitator)
6. Server returns resource with X-PAYMENT-RESPONSE header
```

## EIP-3009 Scheme

The `exact` scheme uses EIP-3009's `transferWithAuthorization`:

- **Gasless for payer**: Authorization is signed off-chain
- **Facilitator pays gas**: Submits transaction to blockchain
- **Time-bound**: Payments have validity windows
- **Nonce-based**: Prevents replay attacks
- **Typed signatures**: Uses EIP-712 for security

### Signature Structure

```dart
struct TransferWithAuthorization {
  address from;
  address to;
  uint256 value;
  uint256 validAfter;
  uint256 validBefore;
  bytes32 nonce;
}
```

## Network Format

Networks use CAIP-2 format: `eip155:{chainId}`

Common networks:
- Base: `eip155:8453`
- Ethereum: `eip155:1`
- Base Sepolia (testnet): `eip155:84532`
- Polygon: `eip155:137`

## Token Requirements

The asset must support EIP-3009:
- USDC on most chains ✅
- Other EIP-3009 compliant tokens ✅

Check token documentation for EIP-3009 support.

## Error Handling

```dart
try {
  final payload = await client.createPaymentPayload(requirements);
} on UnsupportedSchemeException catch (e) {
  print('Scheme not supported: ${e.message}');
} on InvalidPayloadException catch (e) {
  print('Invalid parameters: ${e.message}');
} on X402Exception catch (e) {
  print('Payment error: ${e.message}');
}
```

## Testing

Run tests with:

```bash
cd packages/x402_evm
dart test
```

Tests cover:
- EIP-3009 signature creation and verification
- EIP-712 typed data signing
- Exact scheme client and server
- Facilitator client HTTP interactions
- Error cases and edge conditions

## Advanced Usage

### Custom Token Metadata

```dart
final requirements = X402Requirement(
  // ... other fields ...
  asset: '0xYourTokenAddress',
  data: {
    'name': 'Your Token Name',  // From EIP-2612/3009
    'version': '1',              // Token version
  },
);
```

### Custom Validity Window

```dart
// Payments valid for 5 minutes
final requirements = X402Requirement(
  // ... other fields ...
  maxTimeoutSeconds: 300,
);
```

### Multiple Payment Options

```dart
// Accept payments on multiple chains
final response = PaymentRequiredResponse(
  x402Version: kX402Version,
  accepts: [
    // Base USDC
    X402Requirement(
      scheme: 'exact',
      network: 'eip155:8453',
      amount: '10000',
      asset: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
      // ... other fields ...
    ),
    // Ethereum USDC
    X402Requirement(
      scheme: 'exact',
      network: 'eip155:1',
      amount: '10000',
      asset: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      // ... other fields ...
    ),
  ],
);
```

## Examples

Check the `examples/` directory for:
- Client making payments
- Server accepting payments
- Facilitator integration
- Multi-chain support
- Error handling

## Resources

- [x402 Protocol](https://x402.org)
- [EIP-3009 Spec](https://eips.ethereum.org/EIPS/eip-3009)
- [EIP-712 Spec](https://eips.ethereum.org/EIPS/eip-712)
- [Coinbase x402](https://github.com/coinbase/x402)

## License

Apache-2.0
