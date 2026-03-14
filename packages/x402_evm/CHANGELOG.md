## 0.3.0

- **Breaking Change**: Transitioned to the `Network` class (`EvmNetwork`) instead of string-based network identifiers.
- Added `ExactEvmSchemeServer` for server-side verification of EIP-3009 (USDC) payments.
- Updated `ExactEvmSchemeClient` to conform to the new `Network` model.
- Updated to `x402_core: ^0.3.0`.

## 0.2.0

- Updated `EvmSigner` to support the new `SignedPayment` return type.
- Added `address` getter to `ExactEvmSchemeClient`.
- Added `nowProvider` and `nonceProvider` to `ExactEvmSchemeClient` for deterministic signing in tests.
- Improved `EIP712Utils.hexToBytes` with validation for hex string format.
- Significantly expanded test coverage for EIP-712 and EIP-3009 utilities.

## 0.1.0

- Initial release of the EVM implementation for x402.
- Implemented `EvmSigner` for Ethereum and EVM-compatible chains.
- Implemented `ExactEvmSchemeClient` supporting EIP-3009 (USDC) authorizations.
- Added EIP-3009 and EIP-712 utility functions.
