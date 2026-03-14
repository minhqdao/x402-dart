# x402_core

Core protocol definitions and shared logic for the x402 payment protocol.

This package is blockchain-agnostic and defines the common vocabulary and behavior used by x402 clients and resource hosts.

**Note:** Most users should use the [`x402`](https://pub.dev/packages/x402) package, which exports `x402_core` with added multi-chain support.

## Contents

- Protocol models and constants (`PaymentRequirement`, `PaymentPayload`, etc.)
- Core client components (`X402Client`)
- Core server components (`X402ResourceServer`, `HttpFacilitatorClient`, etc.)
- Framework-agnostic primitives for protecting paid resources
- Interfaces for implementing payment schemes
