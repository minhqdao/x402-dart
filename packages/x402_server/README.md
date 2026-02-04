# x402_server

Framework-agnostic server-side primitives for supporting x402 paid routes.

This package provides the core verification orchestration used by x402 server
adapters, without depending on any HTTP framework.

Most users should not use this package directly. Instead, use a framework
adapter such as `x402_shelf` (or future adapters).

## Contents

- `X402Request`: framework-agnostic request abstraction
- `PaymentVerifier`: orchestrates payment verification across schemes
- `PaymentSchemeVerifier`: interface for implementing payment schemes
- `VerificationResult`: verification outcome model

## What this package does NOT do

- Define HTTP routes or middleware
- Depend on Shelf, Dart Frog, or `dart:io`
- Implement concrete payment schemes
- Create HTTP responses

## Related packages

- [`x402_shelf`](https://pub.dev/packages/x402_shelf): Shelf middleware for handling x402 payments
