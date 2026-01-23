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
