# x402 Dio Client Example

This example demonstrates how to use the `X402Interceptor` with `Dio` to automatically handle the "402 Payment Required" handshake and retries.

## Setup

1. **Environment Variables**:
   - Rename `.env-example` to `.env`.
   - Fill in your `EVM_PRIVATE_KEY` and `SVM_PRIVATE_KEY`.
   - Ensure `RESOURCE_SERVER_URL` and `ENDPOINT_PATH` point to your running x402 server.

2. **Server & Facilitator**:
   - You need a running x402 facilitator and a resource server.
   - You can set these up using the [TypeScript examples in the x402 repository](https://github.com/coinbase/x402).

3. **Running**:
   ```bash
   dart run bin/client_dio.dart
   ```

## Multi-Chain Switching

To change the preferred payment method:
- The `X402Interceptor` uses the first compatible signer in the `signers` list.
- You can reorder `evmSigner` and `svmSigner` in `bin/client_dio.dart` or comment one out to force the client to use a specific chain.