# x402_core

This package contains the core protocol definitions, interfaces, and shared logic for the x402 payment protocol. It is blockchain-agnostic and provides the foundation for specific chain implementations.

**Note:** Most users should use the [x402](https://pub.dev/packages/x402) package directly, which provides the main client-side entry point and multi-chain support.

## Contents

- Base `X402Signer` and `SchemeClient` interfaces.
- Standard protocol models (`PaymentPayload`, `PaymentRequirement`).
- `X402Client` base logic.

## License

Apache-2.0
