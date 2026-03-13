# x402 Shelf Server Example

This example demonstrates how to use `x402_shelf` to protect HTTP routes behind blockchain-based payments with minimal code and no external dependencies.

## Features

- **Multi-Chain Support**: Accepts payments on both Ethereum (Base Sepolia) and Solana (Devnet).
- **Auto Price Resolution**: Uses `Money('0.10')` which is automatically resolved to USDC by the scheme servers.
- **Production-Ready**: Uses the official x402 facilitator (`https://x402.org/facilitator`) for payment negotiation and verification.
- **Minimalistic**: Pure `shelf` integration without routing libraries.

## Running the Example

1. Environment Variables:
   - Rename `.env-example` to `.env`.
   - Fill in `EVM_ADDRESS` and `SVM_ADDRESS`.

2. Ensure you have the dependencies installed:
   ```bash
   dart pub get
   ```

3. Start the server:
   ```bash
   dart bin/shelf_server.dart
   ```

4. Test the routes:

   - **Public route** (No payment needed):
     ```bash
     curl http://localhost:8080/public
     ```

   - **Protected route** (Returns 402 Payment Required):
     ```bash
     curl -v http://localhost:8080/protected
     ```

5. You can also run the [example clients](https://github.com/minhqdao/x402-dart/tree/main/examples) against this server.

## How it Works

1. **Routes**: Defined using `RoutePattern` and `RouteConfig`.
2. **Resource Server**: Initialized with `ExactEvmSchemeServer` and `ExactSvmSchemeServer`. It automatically connects to the default facilitator.
3. **Middleware**: `x402PaymentMiddleware` is added to the Shelf pipeline to intercept and protect specific routes.
