# x402 Client Manual Example

This example demonstrates how to manually handle the x402 "402 Payment Required" flow without using the `X402Client` wrapper.

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
   dart run bin/client_manual.dart
   ```

## Multi-Chain Switching

To experiment with different chains:
- The example tries EVM first. You can modify `bin/client_manual.dart` to change the order or comment out the EVM logic to force it to use SVM.
