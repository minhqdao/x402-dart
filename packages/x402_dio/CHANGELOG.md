## 0.2.0

- Updated `X402Interceptor` to support the new `SignedPayment` return type from signers.
- Included loop protection in `X402Interceptor` to prevent infinite retry loops on recurring 402 responses.
- Added comprehensive unit tests covering various 402 scenarios and error conditions.

## 0.1.0

- Initial release.
- Added `X402Interceptor` for automatic 402 payment handling with Dio.
