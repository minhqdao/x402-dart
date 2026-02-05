# x402_core

Core protocol definitions and shared logic for the x402 payment protocol.

This package is blockchain-agnostic and defines the common vocabulary and behavior used by x402 clients and resource hosts.

**Note:** Most users should use the [`x402`](https://pub.dev/packages/x402) package, which provides the main client entry point and multi-chain support.

## Contents

- Protocol models and constants (`PaymentRequirement`, `PaymentPayload`, etc.)
- Core client logic (`X402Client`)
- Framework-agnostic primitives for protecting paid resources
- Interfaces for implementing payment schemes
