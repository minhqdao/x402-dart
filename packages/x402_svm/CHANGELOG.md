## 0.3.0

- **Breaking Change**: Introduced `SolanaCluster` and `SolanaNetwork` (CAIP-2 compliant) for identifying Solana networks.
- Added `ExactSvmSchemeServer` for server-side verification of SPL Token transfers.
- Updated `ExactSvmSchemeClient` to conform to the new `Network` model.
- Updated to `x402_core: ^0.3.0`.

## 0.2.0

- Updated `SvmSigner` to support the new `SignedPayment` return type.
- Refactored `SvmSigner` to delegate to `ExactSvmSchemeClient`.
- Added more factory methods to `SvmSigner`: `fromPrivateKeyHex`, `fromPrivateKeyBytes`, `fromMnemonic`, and `createRandom`.
- Enhanced `ExactSvmSchemeClient` with network format validation.
- Improved `SvmTransactionBuilder` with better amount validation and custom compute budget instructions (matching reference implementation).
- Made `DecodedTransaction` public for better testability and verification.
- Added extensive validation tests for signers and transaction building.

## 0.1.0

- Initial release of the SVM implementation for x402.
- Implemented `SvmSigner` for Solana and SVM-compatible chains.
- Implemented `ExactSvmSchemeClient` supporting SPL Token transfers.
- Added `SvmTransactionBuilder` for constructing and verifying Solana transactions.
