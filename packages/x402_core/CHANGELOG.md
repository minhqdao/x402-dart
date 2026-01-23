## 0.2.0

- **Breaking Change**: `X402Signer.sign` now returns `Future<SignedPayment>` instead of `Future<String>`.
- Added `SignedPayment` class to wrap the base64-encoded payment payload.
- Added `PaymentRequirement.fromHeader` factory constructor.
- Added `extensions` field to `PaymentPayload`.
- `X402Client` now includes loop protection to prevent infinite retries.
- `X402Client` no longer drains the response stream when returning the original response, fixing issues with non-streaming requests.
- Updated `X402Exception.toString` to include error code if present.

# 0.1.0

- Initial release of the x402 core protocol definitions and shared logic.
- Defined base interfaces for `X402Signer` and `SchemeClient`.
- Implemented core models: `PaymentPayload`, `PaymentRequirement`, `PaymentRequiredResponse`, and `ResourceInfo`.
- Added `X402Client` for automated 402 Payment Required handling.
