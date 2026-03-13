# x402 Client Wrapper Example

This example demonstrates how to use the high-level `X402Client` to automatically handle the "402 Payment Required" handshake and retries.

## Setup

1. **Environment Variables**:
   - Rename `.env-example` to `.env`.
   - Fill in your `EVM_PRIVATE_KEY` and `SVM_PRIVATE_KEY`.
   - Ensure `RESOURCE_SERVER_URL` and `ENDPOINT_PATH` point to your running x402 server.

2. **Server & Facilitator**:
   - You need a running x402 facilitator and a resource server.
   - You can set these up using the servers from the [examples](https://github.com/minhqdao/x402-dart/tree/main/examples/server_shelf) folder.

3. **Running**:
   ```bash
   dart run bin/wrapper_client.dart
   ```

## Multi-Chain Switching

To change the preferred payment method:
- The `X402Client` uses the first compatible signer in the `signers` list.
- You can reorder `evmSigner` and `svmSigner` in `bin/wrapper_client.dart` or comment one out to force the client to use a specific chain.
