## 0.3.0

- **Breaking Change**: Transitioned from `String`-based network identifiers to a dedicated, CAIP-2 compliant `Network` class hierarchy across all packages.
- **Breaking Change**: Introduced `EvmNetwork` and `SolanaNetwork` for chain-specific identifier handling.
- **Breaking Change**: Introduced `SolanaCluster` for easy configuration of Solana environments (Mainnet, Devnet, Testnet).
- **New Feature**: Added `X402ResourceServer` to `x402_core` as a framework-agnostic component for protecting resources and verifying payments.
- **New Feature**: Added `ExactEvmSchemeServer` and `ExactSvmSchemeServer` for verifying EIP-3009 (USDC) and SPL Token payments.
- **New Feature**: Added `SettleResponse` and `VerifyResponse` models for reporting payment results back to clients via the `x402-payment-response` header.
- **Enhancement**: Added `PaymentRequiredResponse.fromHeader` and `findFirstSupportedBy` to simplify client-side requirement parsing.
- **Enhancement**: Improved `X402Exception` with better error reporting and `originalError` context.
- **Internal**: Major directory restructuring in `x402_core` to better organize protocol logic.
- **Testing**: Completely revamped end-to-end testing suite using npm-based facilitator and server packages.
- **Testing**: Significantly expanded unit test coverage for models, schemes, and server-side logic.

## 0.2.0

- Version bump to synchronize with core and blockchain-specific packages.
- Updated internal dependencies to version 0.2.0.

## 0.1.0

- Initial release of the main `x402` client-side package.
- Provides a unified entry point for both EVM and SVM implementations.
- Features `X402Client` for automated 402 Payment Required handshake and retry logic.
- Exports core protocol logic and multi-chain signers (EVM and SVM).
