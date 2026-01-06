# x402_svm

SVM blockchain implementation of the x402 protocol.

## Features

- ✅ **SPL Token Support**: Works with any SPL token (USDC, EURC, etc.)
- ✅ **Token-2022 Support**: Compatible with Token-2022 program
- ✅ **TransferChecked**: Uses TransferChecked for secure transfers
- ✅ **Compute Budget**: Optimized with compute unit instructions
- ✅ **ATA Creation**: Automatically creates associated token accounts
- ✅ **Client & Server**: Both payment creation and verification
- ✅ **Facilitator Integration**: HTTP client for facilitator servers

## Supported Networks

Works on any SVM cluster:
- **Mainnet** (`svm:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp`)
- **Devnet** (`svm:EtWTRABZaYq6iMfeYKouRu166VU2xqa1`)
- **Testnet** (`svm:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z`)

## Installation

```yaml
dependencies:
  x402_svm: ^0.1.0
```

## Quick Start

### Client: Making a Payment

```dart
import 'package:solana/solana.dart';
import 'package:x402_core/x402_core.dart';
import 'package:x402_svm/x402_svm.dart';

// Initialize SVM client
final solanaClient = SolanaClient(
  rpcUrl: Uri.parse('https://api.devnet.solana.com'),
  websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
);

// Initialize with your keypair
final signer = await Ed25519HDKeyPair.fromPrivateKeyBytes(
  privateKeyBytes: yourPrivateKeyBytes,
);

final client = ExactSVMSchemeClient(
  signer: signer,
  solanaClient: solanaClient,
);

// Get payment requirements from server (via 402 response)
final requirements = PaymentRequirement(
  scheme: 'exact',
  network: 'svm:EtWTRABZaYq6iMfeYKouRu166VU2xqa1', // Devnet
  amount: '10000', // 0.01 USDC (6 decimals)
  resource: 'https://api.example.com/premium-data',
  description: 'Access to premium data',
  mimeType: 'application/json',
  payTo: 'CmGgLQL36Y9ubtTsy2zmE46TAxwCBm66onZmPPhUWNqv',
  maxTimeoutSeconds: 60,
  asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', // USDC on Devnet
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
import 'package:x402_svm/x402_svm.dart';

// Initialize verifier
final server = ExactSVMSchemeServer();

// Or with SVM client for transaction submission
final solanaClient = SolanaClient(
  rpcUrl: Uri.parse('https://api.devnet.solana.com'),
  websocketUrl: Uri.parse('wss://api.devnet.solana.com'),
);
final serverWithClient = ExactSVMSchemeServer(
  solanaClient: solanaClient,
);

// Your payment requirements
final requirements = PaymentRequirement(
  scheme: 'exact',
  network: 'svm:EtWTRABZaYq6iMfeYKouRu166VU2xqa1',
  amount: '10000',
  resource: '/premium-data',
  description: 'Premium data access',
  mimeType: 'application/json',
  payTo: 'YourSVMAddress',
  maxTimeoutSeconds: 60,
  asset: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
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
      return Response(402, body: 'Invalid payment');
    }

    // Submit transaction to network
    final txSignature = await serverWithClient.submitTransaction(payload);
    
    // Wait for confirmation
    final confirmed = await serverWithClient.confirmTransaction(txSignature);
    
    if (!confirmed) {
      return Response(402, body: 'Transaction not confirmed');
    }

    // Payment valid and confirmed! Serve the resource
    return innerHandler(request);
  };
}
```

## Network Format

Networks use CAIP-2 format: `svm:{genesisHash}`

Common networks:
- Mainnet: `svm:5eykt4UsFv8P8NJdTREpY1vzqKqZKvdp`
- Devnet: `svm:EtWTRABZaYq6iMfeYKouRu166VU2xqa1`
- Testnet: `svm:4uhcVJyU9pJkvQyS88uRDiswHXSCkY3z`

## Token Support

Works with:
- **SPL Tokens** ✅ (USDC, EURC, etc.)
- **Token-2022 Program** ✅
- Any token with TransferChecked instruction

Common tokens:
- USDC (Mainnet): `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v`
- USDC (Devnet): `4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU`

## Transaction Structure

The exact scheme uses this instruction layout:
1. **Compute Unit Limit**: Sets compute budget
2. **Compute Unit Price**: Sets priority fee
3. **Create ATA** (optional): Creates destination token account if needed
4. **TransferChecked**: Executes the token transfer

## Key Differences from EVM

- **No off-chain signatures**: Transaction is fully constructed and signed
- **Fee payer**: Client signs transaction, facilitator pays SOL fees
- **ATA creation**: Automatically handled if destination account doesn't exist
- **Instant finality**: ~400ms confirmation time
- **Low fees**: Typically $0.00025 per transaction

## Using a Facilitator

```dart
import 'package:x402_svm/x402_svm.dart';

// Initialize facilitator client
final facilitator = HttpFacilitatorClient(
  baseUrl: 'https://facilitator.example.com',
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
    print('Payment settled! Signature: ${settlementResult.txHash}');
  }
}
```

## Advanced: Custom Token Program

For Token-2022 or custom programs:

```dart
final requirements = PaymentRequirement(
  // ... other fields ...
  asset: 'YourToken2022Address',
  data: {
    'tokenProgramId': 'TokenzQdBNbLqP5VEhdkAS6EPFLC1PHnBqCXEpPxuEb',
  },
);
```

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
cd packages/x402_svm
dart test
```

Note: Integration tests require a SVM devnet connection and funded wallet.

## Resources

- [x402 Protocol](https://x402.org)
- [SVM SPL Token](https://spl.solana.com/token)
- [Token-2022](https://spl.solana.com/token-2022)
- [Coinbase x402](https://github.com/coinbase/x402)

## License

Apache-2.0
