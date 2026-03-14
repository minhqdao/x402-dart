## 0.3.0

- **Breaking Change**: Changed `network` from `String` to a dedicated `Network` class (CAIP-2 compliant).
- Added `X402ResourceServer` as a framework-agnostic component for protecting resources and verifying payments.
- Added `SettleResponse` and `VerifyResponse` models for payment verification and settlement reporting.
- Added `PaymentRequiredResponse.fromHeader` and `findFirstSupportedBy`.
- Removed `code` from `X402Exception`, include `originalError` in `toString()`.
- Restructured internal directory, moving core logic into sub-directories.
- Completely revamped e2e tests using npm packages for facilitator and server.
- Significantly expanded test coverage with unit tests for models and server logic.

## 0.2.0

- **Breaking Change**: `X402Signer.sign` now returns `Future<SignedPayment>` instead of `Future<String>`.
- Added `SignedPayment` class to wrap the base64-encoded payment payload.
- Added `PaymentRequirement.fromHeader` factory constructor.
- Added `extensions` field to `PaymentPayload`.
- `X402Client` now includes loop protection to prevent infinite retries.
- `X402Client` no longer drains the response stream when returning the original response, fixing issues with non-streaming requests.
- Updated `X402Exception.toString` to include error code if present.

## 0.1.0

- Initial release of the x402 core protocol definitions and shared logic.
- Defined base interfaces for `X402Signer` and `SchemeClient`.
- Implemented core models: `PaymentPayload`, `PaymentRequirement`, `PaymentRequiredResponse`, and `ResourceInfo`.
- Added `X402Client` for automated 402 Payment Required handling.
